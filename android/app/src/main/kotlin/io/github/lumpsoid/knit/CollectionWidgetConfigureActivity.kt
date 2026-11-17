package io.github.lumpsoid.knit

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle

/**
 * The widget's configuration activity, launched when a collection widget is
 * placed (or reconfigured). The picker itself is a Flutter page inside the
 * running app, which has the store open — so this accepts the widget at once
 * (it shows "Choose a collection" until bound) and hands the pick to
 * MainActivity.
 */
class CollectionWidgetConfigureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val widgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        // With a configure activity the launcher skips the first onUpdate.
        CollectionWidgetProvider.redraw(this, intArrayOf(widgetId))
        startActivity(
            CollectionWidgetProvider.configureIntent(this, widgetId)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        finish()
    }
}
