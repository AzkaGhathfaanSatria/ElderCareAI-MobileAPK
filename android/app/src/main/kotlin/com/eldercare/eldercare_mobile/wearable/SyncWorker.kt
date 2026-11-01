package com.eldercare.eldercare_mobile.wearable

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Sync berkala yang berjalan murni native (tanpa mesin Flutter), jadi tetap jalan walau aplikasi
 * tidak sedang dibuka. Membaca Health Connect di latar belakang butuh izin READ_HEALTH_DATA_IN_BACKGROUND.
 */
class SyncWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {
    override suspend fun doWork(): Result =
        try {
            if (Prefs.isPaired(applicationContext)) Syncer.run(applicationContext)
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }

    companion object {
        private const val NAME = "eldercare-wearable-sync"

        /** WorkManager membatasi interval minimum 15 menit. */
        fun schedule(ctx: Context) {
            val req = PeriodicWorkRequestBuilder<SyncWorker>(15, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(ctx).enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, req)
        }

        fun cancel(ctx: Context) {
            WorkManager.getInstance(ctx).cancelUniqueWork(NAME)
        }
    }
}
