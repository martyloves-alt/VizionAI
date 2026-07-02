package com.example

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException

object ReplicateApi {
    private val client = OkHttpClient()
    private val JSON = "application/json; charset=utf-8".toMediaType()

    suspend fun generateVideo(prompt: String, apiKey: String, onProgress: suspend (String, Float) -> Unit): String {
        return withContext(Dispatchers.IO) {
            val jsonBody = JSONObject().apply {
                put("version", "1e205ea73084bd17a0a3b43396e49ba0d6bc2e754e9283b2df49fad2dcf95755")
                put("input", JSONObject().apply {
                    put("prompt", prompt)
                })
            }

            val request = Request.Builder()
                .url("https://api.replicate.com/v1/predictions")
                .post(jsonBody.toString().toRequestBody(JSON))
                .addHeader("Authorization", "Bearer $apiKey")
                .build()

            val response = client.newCall(request).execute()
            if (!response.isSuccessful) {
                val errorBody = response.body?.string() ?: ""
                throw IOException("Unexpected code ${response.code}: $errorBody")
            }

            val responseBody = response.body?.string() ?: throw IOException("Empty response")
            val predictionId = JSONObject(responseBody).getString("id")
            var status = JSONObject(responseBody).getString("status")

            onProgress("Starting generation on Replicate cluster...", 0.1f)

            while (status == "starting" || status == "processing") {
                kotlinx.coroutines.delay(2000)
                
                val pollRequest = Request.Builder()
                    .url("https://api.replicate.com/v1/predictions/$predictionId")
                    .get()
                    .addHeader("Authorization", "Bearer $apiKey")
                    .build()
                
                val pollResponse = client.newCall(pollRequest).execute()
                if (!pollResponse.isSuccessful) continue
                
                val pollBody = pollResponse.body?.string() ?: continue
                val pollJson = JSONObject(pollBody)
                status = pollJson.getString("status")
                
                if (status == "processing") {
                    onProgress("Rendering high-fidelity frames...", 0.6f)
                }
                
                if (status == "succeeded") {
                    onProgress("Finalizing output...", 1.0f)
                    val outputArray = pollJson.optJSONArray("output")
                    return@withContext if (outputArray != null && outputArray.length() > 0) {
                        outputArray.getString(0)
                    } else {
                        pollJson.getString("output")
                    }
                } else if (status == "failed") {
                    throw IOException("Generation failed: ${pollJson.optString("error")}")
                }
            }
            throw IOException("Unexpected status: $status")
        }
    }
}
