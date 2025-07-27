package com.example.flutter_gallery

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private lateinit var downloadHandler: ModelDownloadHandler
    private lateinit var llmHandler: LlmInferenceHandler
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        
        // Initialize handlers
        downloadHandler = ModelDownloadHandler(this, messenger)
        llmHandler = LlmInferenceHandler(this, messenger)
        
        // Set up method channels
        MethodChannel(messenger, "com.google.ai.edge/model_download")
            .setMethodCallHandler(downloadHandler)

        MethodChannel(messenger, "com.google.ai.edge/llm")
            .setMethodCallHandler(llmHandler)
        println("[MainActivity] Registered LlmInferenceHandler on com.google.ai.edge/llm")
    }
}
