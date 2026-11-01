package com.eldercare.eldercare_mobile.wearable

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import java.time.Instant
import java.time.temporal.ChronoUnit

/** headline = satu kalimat untuk pengguna; details = rincian teknis (kecil, untuk pengecekan). */
class SyncOutcome(val headline: String, val details: String, val ok: Boolean)

object Syncer {
    // Jam sering menyinkronkan data ke Health Connect terlambat. Baca mundur beberapa jam dari sync
    // terakhir; data yang sama tidak akan dobel karena backend idempoten per timestamp.
    private const val OVERLAP_HOURS = 6L
    private const val FIRST_RUN_HOURS = 24L

    suspend fun run(ctx: Context): SyncOutcome {
        val url = Prefs.url(ctx)
        val key = Prefs.key(ctx)
        if (url.isBlank() || key.isBlank()) return SyncOutcome("Perangkat belum terhubung.", "", false)

        if (HealthConnectClient.getSdkStatus(ctx) != HealthConnectClient.SDK_AVAILABLE) {
            return SyncOutcome(
                "Health Connect belum siap di HP ini.",
                "Android 9-13: pasang/perbarui aplikasi Health Connect dari Play Store.",
                false,
            )
        }
        val client = HealthConnectClient.getOrCreate(ctx)

        val now = Instant.now()
        val from = Prefs.lastSync(ctx)?.minus(OVERLAP_HOURS, ChronoUnit.HOURS) ?: now.minus(FIRST_RUN_HOURS, ChronoUnit.HOURS)

        val collected = HealthReader.collect(client, from, now)
        val lines = mutableListOf("Rentang baca: $from s/d $now")
        lines += collected.notes

        if (collected.readings.isEmpty()) {
            return SyncOutcome(
                "Belum ada data baru dari jam. Pastikan jam sudah tersinkron di aplikasi jam.",
                lines.joinToString("\n"),
                false,
            )
        }

        val result = try {
            Uploader.send(url, key, collected.readings)
        } catch (e: Exception) {
            lines += "Error: ${e.message}"
            return SyncOutcome("Gagal mengirim ke server. Cek koneksi internet / alamat server.", lines.joinToString("\n"), false)
        }

        Prefs.setLastSync(ctx, now) // hanya maju bila kirim berhasil
        lines += "Terkirim: ${result.accepted} baru, ${result.duplicates} duplikat, ${result.rejected} ditolak"
        return SyncOutcome("Berhasil: ${result.accepted} data baru terkirim.", lines.joinToString("\n"), true)
    }
}
