package com.hautpocket.data.importer

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class CampusCardNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val pkg = sbn?.packageName ?: return
        if (pkg != "com.newcapec.mobile.ncp" && pkg != "com.tencent.mm" && pkg != "com.eg.android.AlipayGphone") return
    }
}
