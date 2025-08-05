
package com.example.flutter_gallery

import android.os.Handler
import android.os.Looper

import android.content.Context
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import io.flutter.plugin.common.*
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import org.json.JSONObject
import org.json.JSONArray


import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession
import com.google.mediapipe.tasks.genai.llminference.GraphOptions

/**
 * LlmInferenceHandler expects [context] to be an Activity or Fragment (i.e., a LifecycleOwner).
 * If not, coroutine operations will fail. Pass your Activity as context when constructing this handler.
 */
class LlmInferenceHandler(
    private val context: Context,
    private val messenger: BinaryMessenger
) : MethodCallHandler {
    init {
        if (context !is LifecycleOwner) {
            throw IllegalArgumentException("LlmInferenceHandler: context must be a LifecycleOwner (Activity or Fragment). Got: ${context::class.java.name}")
        }
    }
    
    private val inferenceEventChannel = EventChannel(messenger, "com.google.ai.edge/inference_stream")
    private var inferenceEventSink: EventChannel.EventSink? = null
    
    private var llmInference: LlmInference? = null
    private var llmSession: LlmInferenceSession? = null
    private var currentModelId: String? = null
    
    init {
        println("[LlmInferenceHandler] Initializing inference event channel handler...")
        inferenceEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                println("[LlmInferenceHandler] EventChannel onListen called")
                inferenceEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                println("[LlmInferenceHandler] EventChannel onCancel called")
                inferenceEventSink = null
            }
        })
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        println("[LlmInferenceHandler.onMethodCall] Received method: ${call.method}")
        when (call.method) {
            "initializeModel" -> {
                println("[LlmInferenceHandler.onMethodCall] -> initializeModel")
                initializeModel(call, result)
            }
            "isModelDownloaded" -> {
                println("[LlmInferenceHandler.onMethodCall] -> isModelDownloaded")
                isModelDownloaded(call, result)
            }
            "generateResponse" -> {
                println("[LlmInferenceHandler.onMethodCall] -> generateResponse")
                generateResponse(call, result)
            }
            "disposeModel" -> {
                println("[LlmInferenceHandler.onMethodCall] -> disposeModel")
                disposeModel(result)
            }
            else -> {
                println("[LlmInferenceHandler.onMethodCall] Not implemented: ${call.method}")
                result.notImplemented()
            }
        }
    }
    
    private fun initializeModel(call: MethodCall, result: MethodChannel.Result) {
        println("[LlmInferenceHandler.initializeModel] Entered initializeModel")
        val modelId = call.argument<String>("modelId")
        val incomingModelPath = call.argument<String>("modelPath")
        val maxTokens = call.argument<Int>("maxTokens") ?: 8192  // Increased from 1024
        val temperature = call.argument<Double>("temperature")?.toFloat() ?: 1.0f
        val topK = call.argument<Int>("topK") ?: 40
        val topP = call.argument<Double>("topP")?.toFloat() ?: 0.9f
        val accelerator = call.argument<String>("accelerator") ?: "gpu"
        println("[LlmInferenceHandler.initializeModel] Params: modelId=$modelId, modelPath=$incomingModelPath, maxTokens=$maxTokens, temperature=$temperature, topK=$topK, topP=$topP, accelerator=$accelerator")
        if (modelId == null || incomingModelPath == null) {
            println("[LlmInferenceHandler.initializeModel] ERROR: modelId or modelPath is null!")
            result.error("INIT_ERROR", "modelId or modelPath is null", null)
            return
        }

        // Always resolve the model path to the external files directory, regardless of incoming path
        var modelPath: String? = null
        val modelConfig = getModelConfig(modelId)
        if (modelConfig != null) {
            val fileName = modelConfig.getString("modelFile")
            val version = modelConfig.optString("version", "main")
            val modelDir = modelId.replace("/", "-").replace("google-", "")
            val downloadDir = File(context.getExternalFilesDir(null), listOf(modelDir, version).joinToString(separator = File.separator))
            val resolvedFile = File(downloadDir, fileName)
            println("[LlmInferenceHandler.initializeModel] [FIX] Forcing model file path to external files dir: ${resolvedFile.absolutePath}")
            modelPath = resolvedFile.absolutePath
        } else {
            println("[LlmInferenceHandler.initializeModel] [FIX] WARNING: Could not resolve model config for $modelId, using provided modelPath: $incomingModelPath")
            modelPath = incomingModelPath
        }
        // Print final modelPath for debugging
        println("[LlmInferenceHandler.initializeModel] [FIX] Final modelPath used: $modelPath")

        val owner = context as? LifecycleOwner
        if (owner == null) {
            println("[LlmInferenceHandler.initializeModel] ERROR: context is not a LifecycleOwner!")
            result.error("CONTEXT_ERROR", "Context is not a LifecycleOwner", null)
            return
        }
        owner.lifecycleScope.launch {
            try {
                println("[LlmInferenceHandler.initializeModel] Launching model init coroutine...")
                withContext(Dispatchers.Default) {
                    println("[LlmInferenceHandler.initializeModel] Cleaning up previous model/session...")
                    llmSession?.close()
                    llmInference?.close()
                    llmSession = null
                    llmInference = null

                    // Select backend
                    val backend = when (accelerator.lowercase()) {
                        "cpu" -> LlmInference.Backend.CPU
                        "gpu" -> LlmInference.Backend.GPU
                        else -> LlmInference.Backend.GPU
                    }
                    println("[LlmInferenceHandler.initializeModel] Backend selected: $backend")

                    // Build options
                    val options = LlmInference.LlmInferenceOptions.builder()
                        .setModelPath(modelPath)
                        .setMaxTokens(maxTokens)
                        .setPreferredBackend(backend)
                        .build()
                    println("[LlmInferenceHandler.initializeModel] LlmInferenceOptions built")

                    val inference = LlmInference.createFromOptions(context, options)
                    println("[LlmInferenceHandler.initializeModel] LlmInference created")

                    val sessionOptions = LlmInferenceSession.LlmInferenceSessionOptions.builder()
                        .setTopK(topK)
                        .setTopP(topP)
                        .setTemperature(temperature)
                        .setGraphOptions(
                            GraphOptions.builder()
                                .setEnableVisionModality(false) // Set true if your model supports images
                                .build()
                        )
                        .build()
                    println("[LlmInferenceHandler.initializeModel] LlmInferenceSessionOptions built")

                    val session = LlmInferenceSession.createFromOptions(inference, sessionOptions)
                    println("[LlmInferenceHandler.initializeModel] LlmInferenceSession created")

                    llmInference = inference
                    llmSession = session
                    currentModelId = modelId
                }
                println("[LlmInferenceHandler.initializeModel] Model initialization succeeded for $modelId")
                result.success(true)
            } catch (e: Exception) {
                println("[LlmInferenceHandler.initializeModel] ERROR: ${e.message}")
                e.printStackTrace()
                result.error("INIT_ERROR", "Failed to initialize model: ${e.message}", null)
            }
        }
    }
    
    private fun isModelDownloaded(call: MethodCall, result: MethodChannel.Result) {
        println("[LlmInferenceHandler.isModelDownloaded] Entered isModelDownloaded")
        val modelId = call.argument<String>("modelId")
        println("[LlmInferenceHandler.isModelDownloaded] Checking modelId: $modelId")
        if (modelId == null) {
            println("[LlmInferenceHandler.isModelDownloaded] ERROR: modelId is null!")
            result.success(false)
            return
        }
        try {
            // Load model config to get file details
            val modelConfig = getModelConfig(modelId)
            if (modelConfig != null) {
                val fileName = modelConfig.getString("modelFile")
                val totalBytes = modelConfig.getLong("sizeInBytes")
                val version = modelConfig.optString("version", "main")
                val modelDir = modelId.replace("/", "-").replace("google-", "")
                println("[LlmInferenceHandler.isModelDownloaded] fileName=$fileName, totalBytes=$totalBytes, modelDir=$modelDir, version=$version")
                // Check if file exists with correct size
                val downloadDir = File(context.getExternalFilesDir(null), listOf(modelDir, version).joinToString(separator = File.separator))
                val modelFile = File(downloadDir, fileName)
                println("[LlmInferenceHandler.isModelDownloaded] Checking file: ${modelFile.absolutePath}")
                println("[LlmInferenceHandler.isModelDownloaded] File exists: ${modelFile.exists()}")
                if (modelFile.exists()) {
                    println("[LlmInferenceHandler.isModelDownloaded] File size: ${modelFile.length()}, Expected: $totalBytes")
                }
                val isDownloaded = modelFile.exists() && modelFile.length() == totalBytes
                println("[LlmInferenceHandler.isModelDownloaded] Result: $isDownloaded")
                result.success(isDownloaded)
            } else {
                println("[LlmInferenceHandler.isModelDownloaded] Model config not found for $modelId")
                result.success(false)
            }
        } catch (e: Exception) {
            println("[LlmInferenceHandler.isModelDownloaded] ERROR: ${e.message}")
            e.printStackTrace()
            result.success(false)
        }
    }
    
    private fun generateResponse(call: MethodCall, result: MethodChannel.Result) {
        println("[LlmInferenceHandler.generateResponse] Entered generateResponse")
        val prompt = call.argument<String>("prompt")
        println("[LlmInferenceHandler.generateResponse] Called with prompt: $prompt")
        if (prompt == null) {
            println("[LlmInferenceHandler.generateResponse] ERROR: Prompt is null!")
            result.error("NO_PROMPT", "Prompt is null", null)
            return
        }
        val owner = context as? LifecycleOwner
        if (owner == null) {
            println("[LlmInferenceHandler.generateResponse] ERROR: context is not a LifecycleOwner!")
            result.error("CONTEXT_ERROR", "Context is not a LifecycleOwner", null)
            return
        }
        owner.lifecycleScope.launch {
            try {
                println("[LlmInferenceHandler.generateResponse] Launching inference coroutine...")
                val session = llmSession
                if (session == null) {
                    println("[LlmInferenceHandler.generateResponse] ERROR: Model not initialized")
                    result.error("NO_MODEL", "Model not initialized", null)
                    return@launch
                }
                println("[LlmInferenceHandler.generateResponse] Adding prompt chunk and starting inference...")
                // Add prompt as query chunk
                session.addQueryChunk(prompt)
                // Start async inference
                session.generateResponseAsync { partialResult, done ->
                    println("[LlmInferenceHandler.generateResponse] Partial result: $partialResult, done: $done")
                    try {
                        Handler(Looper.getMainLooper()).post {
                            try {
                                inferenceEventSink?.success(mapOf(
                                    "partialResult" to partialResult,
                                    "isDone" to done,
                                    "tokensPerSecond" to calculateTokensPerSecond(),
                                    "totalTokens" to getTotalTokens(partialResult)
                                ))
                                println("[LlmInferenceHandler.generateResponse] Sent event to sink: isDone=$done")
                            } catch (sinkEx: Exception) {
                                println("[LlmInferenceHandler.generateResponse] ERROR sending to event sink (main thread): ${sinkEx.message}")
                                sinkEx.printStackTrace()
                            }
                        }
                    } catch (sinkEx: Exception) {
                        println("[LlmInferenceHandler.generateResponse] ERROR posting to main thread: ${sinkEx.message}")
                        sinkEx.printStackTrace()
                    }
                }
                println("[LlmInferenceHandler.generateResponse] Inference started.")
                result.success(null)
            } catch (e: Exception) {
                println("[LlmInferenceHandler.generateResponse] ERROR: ${e.message}")
                e.printStackTrace()
                result.error("INFERENCE_ERROR", "Failed to generate response: ${e.message}", null)
            }
        }
    }
    
    private fun disposeModel(result: MethodChannel.Result) {
        println("[LlmInferenceHandler.disposeModel] Entered disposeModel")
        try {
            println("[LlmInferenceHandler.disposeModel] Disposing model and session...")
            llmSession?.close()
            llmInference?.close()
            llmSession = null
            llmInference = null
            currentModelId = null
            println("[LlmInferenceHandler.disposeModel] Dispose complete.")
            result.success(null)
        } catch (e: Exception) {
            println("[LlmInferenceHandler.disposeModel] ERROR: ${e.message}")
            e.printStackTrace()
            result.error("DISPOSE_ERROR", "Failed to dispose model: ${e.message}", null)
        }
    }
    
    private fun calculateTokensPerSecond(): Double {
        // TODO: Implement token rate calculation
        return 15.0 // Placeholder
    }
    
    private fun getTotalTokens(text: String): Int {
        // Simple token counting - replace with proper tokenizer
        return text.split(" ").size
    }
    
    private fun getModelConfig(modelId: String): JSONObject? {
        println("[LlmInferenceHandler.getModelConfig] Looking up model config for $modelId")
        return try {
            val inputStream = context.assets.open("flutter_assets/assets/model_allowlist.json")
            val jsonString = inputStream.bufferedReader().use { it.readText() }
            val jsonObject = JSONObject(jsonString)
            val modelsArray = jsonObject.getJSONArray("models")
            
            for (i in 0 until modelsArray.length()) {
                val model = modelsArray.getJSONObject(i)
                if (model.getString("modelId") == modelId) {
                    return model
                }
            }
            null
        } catch (e: Exception) {
            println("Error loading model config: ${e.message}")
            null
        }
    }
}
