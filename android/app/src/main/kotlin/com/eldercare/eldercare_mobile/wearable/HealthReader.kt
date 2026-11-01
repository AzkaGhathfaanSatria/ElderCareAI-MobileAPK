package com.eldercare.eldercare_mobile.wearable

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.BodyTemperatureRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Duration
import java.time.Instant
import java.time.temporal.ChronoUnit

/** Satu pembacaan = satu timestamp dengan metrik yang tersedia (bentuknya sama dengan payload /ingest/wearable). */
class Reading(val ts: Instant) {
    var heartRate: Int? = null
    var oxygen: Double? = null
    var temperature: Double? = null
    var hrv: Double? = null
    var sleepHours: Double? = null
}

class CollectResult(val readings: List<Reading>, val notes: List<String>)

object HealthReader {

    val PERMISSIONS: Set<String> = setOf(
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(OxygenSaturationRecord::class),
        HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
        HealthPermission.getReadPermission(BodyTemperatureRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class),
    )

    private suspend inline fun <reified T : Record> readAll(client: HealthConnectClient, range: TimeRangeFilter): List<T> {
        val out = mutableListOf<T>()
        var token: String? = null
        do {
            val resp = client.readRecords(ReadRecordsRequest(T::class, range, pageSize = 1000, pageToken = token))
            out += resp.records
            token = resp.pageToken.takeUnless { it.isNullOrEmpty() }
        } while (token != null)
        return out
    }

    /**
     * Baca semua metrik yang izinnya sudah diberikan, lalu gabungkan per timestamp (dibulatkan ke detik).
     * Nilai di luar rentang yang diterima backend dibuang di sini, karena satu nilai salah membuat
     * seluruh request ditolak (400) oleh validasi zod di backend.
     */
    suspend fun collect(client: HealthConnectClient, from: Instant, to: Instant): CollectResult {
        val granted = client.permissionController.getGrantedPermissions()
        val notes = mutableListOf<String>()
        val range = TimeRangeFilter.between(from, to)
        val limit = to.plusSeconds(60) // backend menolak timestamp > 5 menit di depan
        val byTs = sortedMapOf<Instant, Reading>()
        fun at(t: Instant): Reading? {
            val s = t.truncatedTo(ChronoUnit.SECONDS)
            return if (s.isAfter(limit)) null else byTs.getOrPut(s) { Reading(s) }
        }

        fun need(p: String, label: String): Boolean {
            val ok = p in granted
            if (!ok) notes += "$label: izin belum diberikan, dilewati"
            return ok
        }

        if (need(HealthPermission.getReadPermission(HeartRateRecord::class), "Detak jantung")) {
            runCatching {
                // Sampel HR bisa tiap detik -> ambil satu per menit (yang terakhir) supaya payload ringan.
                val perMinute = sortedMapOf<Long, HeartRateRecord.Sample>()
                readAll<HeartRateRecord>(client, range).forEach { rec ->
                    rec.samples.forEach { s -> perMinute[s.time.epochSecond / 60] = s }
                }
                var n = 0
                perMinute.values.forEach { s ->
                    val bpm = s.beatsPerMinute.toInt()
                    if (bpm in 20..250) { at(s.time)?.heartRate = bpm; n++ }
                }
                notes += "Detak jantung: $n titik"
            }.onFailure { notes += "Detak jantung gagal dibaca: ${it.message}" }
        }

        if (need(HealthPermission.getReadPermission(OxygenSaturationRecord::class), "SpO2")) {
            runCatching {
                var n = 0
                readAll<OxygenSaturationRecord>(client, range).forEach { r ->
                    val v = r.percentage.value
                    if (v in 50.0..100.0) { at(r.time)?.oxygen = v; n++ }
                }
                notes += "SpO2: $n titik"
            }.onFailure { notes += "SpO2 gagal dibaca: ${it.message}" }
        }

        if (need(HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class), "HRV")) {
            runCatching {
                var n = 0
                readAll<HeartRateVariabilityRmssdRecord>(client, range).forEach { r ->
                    val v = r.heartRateVariabilityMillis
                    if (v in 0.0..300.0) { at(r.time)?.hrv = v; n++ }
                }
                notes += "HRV (RMSSD): $n titik"
            }.onFailure { notes += "HRV gagal dibaca: ${it.message}" }
        }

        if (need(HealthPermission.getReadPermission(BodyTemperatureRecord::class), "Suhu")) {
            runCatching {
                var n = 0
                readAll<BodyTemperatureRecord>(client, range).forEach { r ->
                    val v = r.temperature.inCelsius
                    if (v in 30.0..45.0) { at(r.time)?.temperature = v; n++ }
                }
                notes += "Suhu: $n titik"
            }.onFailure { notes += "Suhu gagal dibaca: ${it.message}" }
        }

        if (need(HealthPermission.getReadPermission(SleepSessionRecord::class), "Tidur")) {
            runCatching {
                var n = 0
                readAll<SleepSessionRecord>(client, range).forEach { r ->
                    val hours = Duration.between(r.startTime, r.endTime).seconds / 3600.0
                    if (hours in 0.0..24.0) { at(r.endTime)?.sleepHours = Math.round(hours * 10) / 10.0; n++ }
                }
                notes += "Tidur: $n sesi"
            }.onFailure { notes += "Tidur gagal dibaca: ${it.message}" }
        }

        return CollectResult(byTs.values.toList(), notes)
    }
}
