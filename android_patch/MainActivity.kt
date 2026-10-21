package com.mysaathi.mysaathi

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "mysaathi/launch"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "openUrl") {
                    val url = call.argument<String>("url")
                    if (url == null) {
                        result.error("no_url", "url is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("open_failed", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
