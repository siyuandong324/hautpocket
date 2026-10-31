package com.hautpocket.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.hautpocket.R

class TodayScheduleWidgetReceiver : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_simple)
            views.setTextViewText(R.id.widget_title, "📅 河工大今日课表")
            views.setTextViewText(R.id.widget_body, "数据结构与算法 @惟实楼302 (08:00)")
            manager.updateAppWidget(id, views)
        }
    }
}

class DormElectricityWidgetReceiver : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_simple)
            views.setTextViewText(R.id.widget_title, "⚡ 寝室电费余量")
            views.setTextViewText(R.id.widget_body, "照明: 154.0° | 空调: 51.2° (余量充足)")
            manager.updateAppWidget(id, views)
        }
    }
}

class CampusCardWidgetReceiver : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_simple)
            views.setTextViewText(R.id.widget_title, "💳 河工大一卡通")
            views.setTextViewText(R.id.widget_body, "余额: ¥68.50 | 今日消费: ¥19.50")
            manager.updateAppWidget(id, views)
        }
    }
}
