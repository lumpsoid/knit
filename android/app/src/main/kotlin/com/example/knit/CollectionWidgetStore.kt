package com.example.knit

import android.content.Context

/**
 * What each home-screen collection widget is bound to and shows, kept in
 * SharedPreferences so the provider can redraw without the Flutter engine.
 * The app writes it over [CollectionWidgetChannel]; the provider only reads.
 */
class CollectionWidgetStore(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun collectionId(widgetId: Int): String? = prefs.getString(key(COLLECTION, widgetId), null)

    fun title(widgetId: Int): String? = prefs.getString(key(TITLE, widgetId), null)

    fun isRemoved(widgetId: Int): Boolean = prefs.getBoolean(key(REMOVED, widgetId), false)

    /** False for an imported, read-only collection: no ✎ quick input. */
    fun hasQuickInput(widgetId: Int): Boolean = prefs.getBoolean(key(QUICK_INPUT, widgetId), true)

    fun bind(widgetId: Int, collectionId: String, title: String) {
        prefs.edit()
            .putString(key(COLLECTION, widgetId), collectionId)
            .putString(key(TITLE, widgetId), title)
            .putBoolean(key(REMOVED, widgetId), false)
            .remove(key(QUICK_INPUT, widgetId))
            .apply()
    }

    fun showLive(widgetId: Int, title: String, quickInput: Boolean) {
        prefs.edit()
            .putString(key(TITLE, widgetId), title)
            .putBoolean(key(REMOVED, widgetId), false)
            .putBoolean(key(QUICK_INPUT, widgetId), quickInput)
            .apply()
    }

    fun showRemoved(widgetId: Int) {
        prefs.edit().putBoolean(key(REMOVED, widgetId), true).apply()
    }

    fun forget(widgetId: Int) {
        prefs.edit()
            .remove(key(COLLECTION, widgetId))
            .remove(key(TITLE, widgetId))
            .remove(key(REMOVED, widgetId))
            .remove(key(QUICK_INPUT, widgetId))
            .apply()
    }

    private companion object {
        const val PREFS = "knit_collection_widgets"
        const val COLLECTION = "collection"
        const val TITLE = "title"
        const val REMOVED = "removed"
        const val QUICK_INPUT = "quick_input"

        fun key(field: String, widgetId: Int) = "${field}_$widgetId"
    }
}
