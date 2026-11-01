package com.eldercare.eldercare_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import com.eldercare.eldercare_mobile.wearable.HealthReader
import com.eldercare.eldercare_mobile.wearable.Prefs
import com.eldercare.eldercare_mobile.wearable.SyncWorker
import com.eldercare.eldercare_mobile.wearable.Syncer
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Jembatan Flutter <-> Health Connect untuk pairing wearable.
 * FlutterFragmentActivity (bukan FlutterActivity) dibutuhkan agar bisa memakai ActivityResult
 * untuk dialog izin Health Connect.
 */
class MainActivity : FlutterFragmentActivity() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var channel: MethodChannel? = null

    // Tautan eldercare://pair yang masuk sebelum Dart siap menerimanya.
    private var pendingLink: String? = null
    private var dartListening = false

    private var permissionResult: MethodChannel.Result? = null
    private val permissionLauncher =
        registerForActivityResult(PermissionController.createRequestPermissionResultContract()) { granted ->
            val r = permissionResult
            permissionResult = null
            r?.success(granted.count { it in HealthReader.PERMISSIONS })
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createAlertChannel()
        if (savedInstanceState == null) captureLink(intent)
    }

    /** Channel "alerts" (penting) untuk push peringatan; id harus sama dengan yang dikirim backend. */
    private fun createAlertChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "alerts",
            "Peringatan lansia",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = "Peringatan jatuh, detak jantung abnormal, dan kondisi darurat lainnya." }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        captureLink(intent)
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result -> handle(call, result) }
        channel = ch
    }

    private fun captureLink(intent: Intent?) {
        val data = intent?.data ?: return
        if (data.scheme != "eldercare") return
        val link = data.toString()
        intent.data = null // jangan diproses ulang
        if (dartListening) channel?.invokeMethod("onPairLink", link) else pendingLink = link
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "takePendingLink" -> {
                dartListening = true
                result.success(pendingLink)
                pendingLink = null
            }
            "status" -> scope.launch {
                try {
                    result.success(statusMap())
                } catch (e: Exception) {
                    result.error("STATUS", e.message, null)
                }
            }
            "pair" -> {
                val url = call.argument<String>("url").orEmpty()
                val key = call.argument<String>("key").orEmpty()
                if (url.isBlank() || key.isBlank()) {
                    result.error("ARGS", "url dan key wajib diisi", null)
                } else {
                    Prefs.pair(this, url, key)
                    result.success(true)
                }
            }
            "unpair" -> {
                SyncWorker.cancel(this)
                Prefs.unpair(this)
                result.success(true)
            }
            "requestPermissions" -> requestPermissions(result)
            "scheduleSync" -> {
                SyncWorker.schedule(this)
                result.success(true)
            }
            "syncNow" -> scope.launch {
                val outcome = try {
                    Syncer.run(this@MainActivity)
                } catch (e: Exception) {
                    null
                }
                result.success(
                    mapOf(
                        "headline" to (outcome?.headline ?: "Terjadi kesalahan saat sync."),
                        "details" to (outcome?.details ?: ""),
                        "ok" to (outcome?.ok ?: false),
                    ),
                )
            }
            "installHealthConnect" -> {
                val pkg = "com.google.android.apps.healthdata"
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg")))
                } catch (e: Exception) {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$pkg")))
                }
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private suspend fun statusMap(): Map<String, Any?> {
        val sdk = HealthConnectClient.getSdkStatus(this)
        val health = when (sdk) {
            HealthConnectClient.SDK_AVAILABLE -> "available"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "update_required"
            else -> "unavailable"
        }
        var granted = 0
        if (sdk == HealthConnectClient.SDK_AVAILABLE) {
            val g = HealthConnectClient.getOrCreate(this).permissionController.getGrantedPermissions()
            granted = g.count { it in HealthReader.PERMISSIONS }
        }
        return mapOf(
            "paired" to Prefs.isPaired(this),
            "url" to Prefs.url(this),
            "lastSyncMillis" to Prefs.lastSync(this)?.toEpochMilli(),
            "health" to health,
            "granted" to granted,
            "total" to HealthReader.PERMISSIONS.size,
        )
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (permissionResult != null) {
            result.error("BUSY", "Permintaan izin sedang berjalan", null)
            return
        }
        if (HealthConnectClient.getSdkStatus(this) != HealthConnectClient.SDK_AVAILABLE) {
            result.error("UNAVAILABLE", "Health Connect belum tersedia", null)
            return
        }
        scope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(this@MainActivity)
                // Izin baca di background ikut diminta; bila Health Connect tidak mendukung, sinkron
                // tetap jalan saat aplikasi dibuka atau lewat tombol "Sinkron sekarang".
                val wanted = HealthReader.PERMISSIONS.toMutableSet()
                wanted += HealthPermission.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND

                val granted = client.permissionController.getGrantedPermissions()
                if (granted.containsAll(HealthReader.PERMISSIONS)) {
                    result.success(granted.count { it in HealthReader.PERMISSIONS })
                } else {
                    permissionResult = result
                    permissionLauncher.launch(wanted)
                }
            } catch (e: Exception) {
                permissionResult = null
                result.error("PERMISSION", e.message, null)
            }
        }
    }

    companion object {
        private const val CHANNEL = "id.eldercare/wearable"
    }
}
