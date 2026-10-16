package com.example.knit

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var widgetChannel: CollectionWidgetChannel? = null

    /** Recreated from saved state: the launch intent was already handled. */
    private var restored = false

    override fun onCreate(savedInstanceState: Bundle?) {
        restored = savedInstanceState != null
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = CollectionWidgetChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        // A relaunch from Recents replays the original intent — don't reopen it.
        val fromHistory = intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0
        if (!restored && !fromHistory) channel.offerInitial(intent)
        widgetChannel = channel
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        widgetChannel?.dispose()
        widgetChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        widgetChannel?.deliver(intent)
    }
}
