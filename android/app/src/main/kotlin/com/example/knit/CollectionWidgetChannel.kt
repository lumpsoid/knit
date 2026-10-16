package com.example.knit

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The `knit/collection_widget` channel (Dart: MethodChannelCollectionWidgetHost).
 * Native → Dart: `request` when a widget intent reaches the running activity.
 * Dart → native: `initialRequest`, `bindings`, `bind`, `publish`,
 * `returnToHomeScreen`.
 */
class CollectionWidgetChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, NAME)
    private val store = CollectionWidgetStore(activity)
    private var initial: Map<String, Any>? = null

    init {
        channel.setMethodCallHandler(this)
    }

    /** Hold the launch intent's request until Dart asks for it. */
    fun offerInitial(intent: Intent?) {
        initial = requestOf(intent)
    }

    /** Forward a warm intent's request to Dart. */
    fun deliver(intent: Intent?) {
        requestOf(intent)?.let { channel.invokeMethod("request", it) }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialRequest" -> {
                result.success(initial)
                initial = null
            }
            "bindings" -> result.success(
                CollectionWidgetProvider.placedIds(activity).map {
                    mapOf("widgetId" to it, "collectionId" to store.collectionId(it))
                },
            )
            "bind" -> {
                val widgetId = call.argument<Int>("widgetId")
                val collectionId = call.argument<String>("collectionId")
                val title = call.argument<String>("title")
                if (widgetId == null || collectionId == null || title == null) {
                    result.error("bad_args", "bind needs widgetId, collectionId, title", null)
                    return
                }
                store.bind(widgetId, collectionId, title)
                CollectionWidgetProvider.redraw(activity, intArrayOf(widgetId))
                result.success(null)
            }
            "publish" -> {
                val placed = CollectionWidgetProvider.placedIds(activity).toSet()
                val redrawn = mutableListOf<Int>()
                for (tile in call.arguments as? List<*> ?: emptyList<Any>()) {
                    val map = tile as? Map<*, *> ?: continue
                    val widgetId = (map["widgetId"] as? Number)?.toInt() ?: continue
                    if (widgetId !in placed) continue
                    if (map["removed"] == true) {
                        store.showRemoved(widgetId)
                    } else {
                        store.showLive(widgetId, map["title"] as? String ?: "")
                    }
                    redrawn += widgetId
                }
                CollectionWidgetProvider.redraw(activity, redrawn.toIntArray())
                result.success(null)
            }
            "returnToHomeScreen" -> {
                activity.moveTaskToBack(true)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val NAME = "knit/collection_widget"

        /** The widget request [intent] carries, or null for any other intent. */
        fun requestOf(intent: Intent?): Map<String, Any>? {
            if (intent == null) return null
            return when (intent.action) {
                CollectionWidgetProvider.ACTION_OPEN ->
                    intent.getStringExtra(CollectionWidgetProvider.EXTRA_COLLECTION_ID)
                        ?.let { mapOf("type" to "open", "collectionId" to it) }
                CollectionWidgetProvider.ACTION_CONFIGURE ->
                    intent.getIntExtra(
                        AppWidgetManager.EXTRA_APPWIDGET_ID,
                        AppWidgetManager.INVALID_APPWIDGET_ID,
                    ).takeIf { it != AppWidgetManager.INVALID_APPWIDGET_ID }
                        ?.let { mapOf("type" to "configure", "widgetId" to it) }
                else -> null
            }
        }
    }
}
