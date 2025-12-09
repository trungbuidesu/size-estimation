package com.example.size_estimation

import com.google.ar.core.ArCoreApk
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val channelName = "com.example.size_estimation/arcore"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkArSupport" -> {
                        val availability = ArCoreApk.getInstance().checkAvailability(this)
                        // isSupported covers INSTALLED and APK_TOO_OLD/INSTALLED if upgradable.
                        val supported = availability.isSupported && !availability.isTransient
                        result.success(supported)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
