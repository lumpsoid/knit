package io.github.lumpsoid.knit

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
 * that opens Knit on that collection, and a ✎ button that opens it for one
 * quick card. An unbound widget, or one whose collection was deleted, opens
 * the collection picker instead (and hides the ✎).
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
        const val ACTION_OPEN = "io.github.lumpsoid.knit.action.OPEN_COLLECTION"
        const val ACTION_CONFIGURE = "io.github.lumpsoid.knit.action.CONFIGURE_WIDGET"
        const val ACTION_QUICK_INPUT = "io.github.lumpsoid.knit.action.QUICK_INPUT"
        const val EXTRA_COLLECTION_ID = "io.github.lumpsoid.knit.extra.COLLECTION_ID"

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
            collectionIntent(context, ACTION_OPEN, collectionId)

        private fun quickInputIntent(context: Context, collectionId: String): Intent =
            collectionIntent(context, ACTION_QUICK_INPUT, collectionId)

        private fun collectionIntent(context: Context, action: String, collectionId: String) =
            Intent(context, MainActivity::class.java)
                .setAction(action)
                .putExtra(EXTRA_COLLECTION_ID, collectionId)

        /** A PendingIntent per widget (the request code) and [intent]'s action,
         *  updated in place as the widget's state changes. */
        private fun pending(context: Context, widgetId: Int, intent: Intent) =
            PendingIntent.getActivity(
                context,
                widgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        private fun draw(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val store = CollectionWidgetStore(context)
            val collectionId = store.collectionId(widgetId)
            val views = RemoteViews(context.packageName, R.layout.collection_widget)
            val tap: Intent
            var quickInput: Intent? = null
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
                    if (store.hasQuickInput(widgetId)) {
                        quickInput = quickInputIntent(context, collectionId)
                    }
                }
            }
            views.setOnClickPendingIntent(R.id.collection_widget_root, pending(context, widgetId, tap))
            if (quickInput != null) {
                views.setViewVisibility(R.id.collection_widget_quick_input, View.VISIBLE)
                views.setOnClickPendingIntent(
                    R.id.collection_widget_quick_input,
                    pending(context, widgetId, quickInput),
                )
            } else {
                views.setViewVisibility(R.id.collection_widget_quick_input, View.GONE)
            }
            manager.updateAppWidget(widgetId, views)
        }
    }
}
