package com.eldercare.eldercare_mobile.wearable

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class UploadResult(val accepted: Int, val duplicates: Int, val rejected: Int)

object Uploader {
    private const val BATCH = 200 // backend menerima maks 500 per request

    private fun toJson(r: Reading): JSONObject = JSONObject().apply {
        put("timestamp", r.ts.toString())
        r.heartRate?.let { put("heartRate", it) }
        r.oxygen?.let { put("oxygenLevel", Math.round(it * 100) / 100.0) }
        r.temperature?.let { put("temperature", Math.round(it * 100) / 100.0) }
        r.hrv?.let { put("heartRateVariability", Math.round(it * 100) / 100.0) }
        r.sleepHours?.let { put("sleepHours", it) }
    }

    /** Kirim ke POST {baseUrl}/ingest/wearable. Melempar Exception bila server menolak/tidak terjangkau. */
    suspend fun send(baseUrl: String, deviceKey: String, readings: List<Reading>): UploadResult =
        withContext(Dispatchers.IO) {
            var accepted = 0; var duplicates = 0; var rejected = 0
            for (chunk in readings.chunked(BATCH)) {
                val body = JSONObject().put("readings", JSONArray(chunk.map(::toJson))).toString()
                val conn = (URL("$baseUrl/ingest/wearable").openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 15_000
                    readTimeout = 30_000
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("X-Device-Key", deviceKey)
                }
                try {
                    conn.outputStream.use { it.write(body.toByteArray()) }
                    val code = conn.responseCode
                    val text = (if (code in 200..299) conn.inputStream else conn.errorStream)
                        ?.bufferedReader()?.use { it.readText() } ?: ""
                    if (code !in 200..299) throw RuntimeException("Server $code: ${text.take(300)}")
                    val j = JSONObject(text)
                    accepted += j.optInt("accepted"); duplicates += j.optInt("duplicates"); rejected += j.optInt("rejected")
                } finally {
                    conn.disconnect()
                }
            }
            UploadResult(accepted, duplicates, rejected)
        }
}
