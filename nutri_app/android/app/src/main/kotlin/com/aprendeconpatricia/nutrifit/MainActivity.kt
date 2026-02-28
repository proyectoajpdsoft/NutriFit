package com.aprendeconpatricia.nutrifit

import android.content.Intent
import android.net.Uri
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "nutri_app/external_url"
	private val screenAwakeChannelName = "nutri_app/screen_awake"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				if (call.method == "openUrl") {
					val url = call.argument<String>("url")
					if (url == null) {
						result.error("INVALID_URL", "URL is null", null)
						return@setMethodCallHandler
					}

					val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
					startActivity(intent)
					result.success(true)
				} else {
					result.notImplemented()
				}
			}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenAwakeChannelName)
			.setMethodCallHandler { call, result ->
				if (call.method == "setScreenAwake") {
					val enabled = call.argument<Boolean>("enabled") ?: false
					runOnUiThread {
						if (enabled) {
							window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
						} else {
							window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
						}
					}
					result.success(true)
				} else {
					result.notImplemented()
				}
			}
	}
}
