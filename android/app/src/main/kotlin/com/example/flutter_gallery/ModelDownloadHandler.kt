package com.example.flutter_gallery

import android.content.Context
import androidx.lifecycle.LifecycleOwner
import androidx.work.*
import io.flutter.plugin.common.*
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import com.google.ai.edge.gallery.worker.DownloadWorker
import com.google.ai.edge.gallery.data.*
import java.io.File

class ModelDownloadHandler(
    private val context: Context,
    private val messenger: BinaryMessenger
) : MethodCallHandler {
    
    private val progressEventChannel = EventChannel(messenger, "com.google.ai.edge/download_progress")
    private var progressEventSink: EventChannel.EventSink? = null
    private val workManager = WorkManager.getInstance(context)
    
    init {
        progressEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                progressEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                progressEventSink = null
            }
        })
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "downloadModel" -> startDownload(call, result)
            "cancelDownload" -> cancelDownload(result)
            "isModelDownloaded" -> checkIfModelDownloaded(call, result)
            else -> result.notImplemented()
        }
    }
    
    private fun startDownload(call: MethodCall, result: MethodChannel.Result) {
        try {
            // Extract parameters exactly like Google's code
            val modelUrl = call.argument<String>("modelUrl")!!
            val modelName = call.argument<String>("modelName")!!
            val version = call.argument<String>("version")!!
            val fileName = call.argument<String>("fileName")!!
            val modelDir = call.argument<String>("modelDir")!!
            val totalBytes = call.argument<Long>("totalBytes")!!
            val extraDataUrls = call.argument<String>("extraDataUrls")
            val extraDataFileNames = call.argument<String>("extraDataFileNames")
            val accessToken = call.argument<String>("accessToken")
            val isZip = call.argument<Boolean>("isZip") ?: false
            val unzippedDir = call.argument<String>("unzippedDir")
            
            // Create WorkRequest using Google's exact DownloadWorker
            val workRequest = OneTimeWorkRequestBuilder<DownloadWorker>()
                .setInputData(Data.Builder()
                    .putString(KEY_MODEL_URL, modelUrl)
                    .putString(KEY_MODEL_NAME, modelName)
                    .putString(KEY_MODEL_VERSION, version)
                    .putString(KEY_MODEL_DOWNLOAD_FILE_NAME, fileName)
                    .putString(KEY_MODEL_DOWNLOAD_MODEL_DIR, modelDir)
                    .putLong(KEY_MODEL_TOTAL_BYTES, totalBytes)
                    .putString(KEY_MODEL_EXTRA_DATA_URLS, extraDataUrls)
                    .putString(KEY_MODEL_EXTRA_DATA_DOWNLOAD_FILE_NAMES, extraDataFileNames)
                    .putString(KEY_MODEL_DOWNLOAD_ACCESS_TOKEN, accessToken)
                    .putBoolean(KEY_MODEL_IS_ZIP, isZip)
                    .putString(KEY_MODEL_UNZIPPED_DIR, unzippedDir)
                    .putLong(KEY_MODEL_DOWNLOAD_APP_TS, System.currentTimeMillis())
                    .build())
                .setConstraints(Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build())
                .build()
            
            // Observe progress and send to Flutter
            workManager.getWorkInfoByIdLiveData(workRequest.id)
                .observe(context as LifecycleOwner) { workInfo ->
                    when (workInfo?.state) {
                        WorkInfo.State.RUNNING -> {
                            val progress = workInfo.progress
                            progressEventSink?.success(mapOf(
                                "receivedBytes" to progress.getLong(KEY_MODEL_DOWNLOAD_RECEIVED_BYTES, 0),
                                "totalBytes" to totalBytes,
                                "downloadRate" to progress.getLong(KEY_MODEL_DOWNLOAD_RATE, 0),
                                "remainingMs" to progress.getLong(KEY_MODEL_DOWNLOAD_REMAINING_MS, 0),
                                "isUnzipping" to progress.getBoolean(KEY_MODEL_START_UNZIPPING, false),
                                "state" to "downloading"
                            ))
                        }
                        WorkInfo.State.SUCCEEDED -> {
                            progressEventSink?.success(mapOf(
                                "receivedBytes" to totalBytes,
                                "totalBytes" to totalBytes,
                                "downloadRate" to 0,
                                "remainingMs" to 0,
                                "isUnzipping" to false,
                                "state" to "completed"
                            ))
                        }
                        WorkInfo.State.FAILED -> {
                            val errorMessage = workInfo.outputData.getString(KEY_MODEL_DOWNLOAD_ERROR_MESSAGE)
                            progressEventSink?.success(mapOf(
                                "errorMessage" to errorMessage,
                                "state" to "failed"
                            ))
                        }
                        WorkInfo.State.CANCELLED -> {
                            progressEventSink?.success(mapOf(
                                "state" to "cancelled"
                            ))
                        }
                        else -> {}
                    }
                }
            
            // Start the download
            workManager.enqueue(workRequest)
            result.success(true)
            
        } catch (e: Exception) {
            result.error("DOWNLOAD_ERROR", e.message, null)
        }
    }
    
    private fun cancelDownload(result: MethodChannel.Result) {
        try {
            workManager.cancelAllWorkByTag("model_download")
            result.success(true)
        } catch (e: Exception) {
            result.error("CANCEL_ERROR", e.message, null)
        }
    }
    
    private fun checkIfModelDownloaded(call: MethodCall, result: MethodChannel.Result) {
        try {
            val fileName = call.argument<String>("fileName")!!
            val modelDir = call.argument<String>("modelDir")!!
            val version = call.argument<String>("version")!!
            val expectedSize = call.argument<Long>("totalBytes")!!
            
            // Use the same path structure as DownloadWorker: externalFilesDir/modelDir/version/fileName
            val downloadDir = File(context.getExternalFilesDir(null), listOf(modelDir, version).joinToString(separator = File.separator))
            val modelFile = File(downloadDir, fileName)
            
            println("AGDownloadCheck: Checking file: ${modelFile.absolutePath}")
            println("AGDownloadCheck: File exists: ${modelFile.exists()}")
            if (modelFile.exists()) {
                println("AGDownloadCheck: File size: ${modelFile.length()}, Expected: $expectedSize")
            }
            
            val isDownloaded = modelFile.exists() && modelFile.length() == expectedSize
            println("AGDownloadCheck: Result: $isDownloaded")
            result.success(isDownloaded)
        } catch (e: Exception) {
            result.error("CHECK_ERROR", "Failed to check download status: ${e.message}", null)
        }
    }
}
