package com.example.knit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/**
 * The home-screen collection widget: a tile with the bound collection's title
 * that opens Knit on that collection. An unbound widget, or one whose
 * collection was deleted, opens the collection picker instead.
 */
class CollectionWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        widgetIds.forEach { draw(context, manager, it) }
    }

    override fun onDeleted(context: Context, widgetIds: IntArray) {
        val store = CollectionWidgetStore(context)
        widgetIds.forEach(store::forget)
    }

    companion object {
        const val ACTION_OPEN = "com.example.knit.action.OPEN_COLLECTION"
        const val ACTION_CONFIGURE = "com.example.knit.action.CONFIGURE_WIDGET"
        const val EXTRA_COLLECTION_ID = "com.example.knit.extra.COLLECTION_ID"

        /** Every placed collection widget. */
        fun placedIds(context: Context): IntArray =
            AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, CollectionWidgetProvider::class.java))

        fun redraw(context: Context, widgetIds: IntArray) {
            val manager = AppWidgetManager.getInstance(context)
            widgetIds.forEach { draw(context, manager, it) }
        }

        /** Opens MainActivity on the picker for [widgetId]. */
        fun configureIntent(context: Context, widgetId: Int): Intent =
            Intent(context, MainActivity::class.java)
                .setAction(ACTION_CONFIGURE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)

        private fun openIntent(context: Context, collectionId: String): Intent =
            Intent(context, MainActivity::class.java)
                .setAction(ACTION_OPEN)
                .putExtra(EXTRA_COLLECTION_ID, collectionId)

        private fun draw(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val store = CollectionWidgetStore(context)
            val collectionId = store.collectionId(widgetId)
            val views = RemoteViews(context.packageName, R.layout.collection_widget)
            val tap: Intent
            when {
                collectionId == null -> {
                    views.setTextViewText(
                        R.id.collection_widget_title,
                        context.getString(R.string.collection_widget_unbound),
                    )
                    views.setViewVisibility(R.id.collection_widget_subtitle, View.GONE)
                    tap = configureIntent(context, widgetId)
                }
                store.isRemoved(widgetId) -> {
                    views.setTextViewText(
                        R.id.collection_widget_title,
                        context.getString(R.string.collection_widget_removed),
                    )
                    views.setTextViewText(
                        R.id.collection_widget_subtitle,
                        context.getString(R.string.collection_widget_reconfigure),
                    )
                    views.setViewVisibility(R.id.collection_widget_subtitle, View.VISIBLE)
                    tap = configureIntent(context, widgetId)
                }
                else -> {
                    views.setTextViewText(R.id.collection_widget_title, store.title(widgetId) ?: "")
                    views.setViewVisibility(R.id.collection_widget_subtitle, View.GONE)
                    tap = openIntent(context, collectionId)
                }
            }
            // One PendingIntent per widget (the request code), updated in place
            // when the widget switches between opening and configuring.
            views.setOnClickPendingIntent(
                R.id.collection_widget_root,
                PendingIntent.getActivity(
                    context,
                    widgetId,
                    tap,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            manager.updateAppWidget(widgetId, views)
        }
    }
}
