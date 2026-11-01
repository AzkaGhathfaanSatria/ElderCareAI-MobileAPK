package com.eldercare.eldercare_mobile.wearable

import android.content.Context
import java.time.Instant

/** Penyimpanan pairing wearable: alamat server, device key (ecw_...), dan waktu sync terakhir. */
object Prefs {
    private fun sp(ctx: Context) = ctx.getSharedPreferences("wearable_bridge", Context.MODE_PRIVATE)

    fun url(ctx: Context): String = sp(ctx).getString("url", "") ?: ""
    fun key(ctx: Context): String = sp(ctx).getString("key", "") ?: ""
    fun isPaired(ctx: Context): Boolean = url(ctx).isNotBlank() && key(ctx).isNotBlank()

    /** Simpan hasil pairing. Waktu sync direset supaya sync pertama membaca data 24 jam terakhir. */
    fun pair(ctx: Context, url: String, key: String) {
        sp(ctx).edit()
            .putString("url", url.trim().trimEnd('/'))
            .putString("key", key.trim())
            .remove("lastSync")
            .apply()
    }

    fun unpair(ctx: Context) {
        sp(ctx).edit().clear().apply()
    }

    fun lastSync(ctx: Context): Instant? =
        sp(ctx).getLong("lastSync", 0L).takeIf { it > 0 }?.let { Instant.ofEpochSecond(it) }

    fun setLastSync(ctx: Context, t: Instant) {
        sp(ctx).edit().putLong("lastSync", t.epochSecond).apply()
    }
}
