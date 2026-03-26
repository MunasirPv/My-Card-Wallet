package com.securewallet.my_card_wallet

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.securewallet.my_card_wallet/hce"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prevent screenshots and screen recording on all screens
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "activateCard" -> {
                    val number = call.argument<String>("number")
                    val expiry = call.argument<String>("expiry")
                    val name = call.argument<String>("name")
                    
                    CardHceService.activeCardNumber = number
                    CardHceService.activeCardExpiry = expiry
                    CardHceService.activeCardName = name
                    
                    result.success(true)
                }
                "deactivateCard" -> {
                    CardHceService.activeCardNumber = null
                    CardHceService.activeCardExpiry = null
                    CardHceService.activeCardName = null
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
