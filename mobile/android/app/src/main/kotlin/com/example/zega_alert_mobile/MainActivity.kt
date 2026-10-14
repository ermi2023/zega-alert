package com.example.zega_alert_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth requires a FragmentActivity (not plain FlutterActivity).
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createAlertChannel()
    }

    // Ensures the FCM default channel exists so alert notifications are shown
    // on Android 8+ (a notification targeting a missing channel is dropped).
    private fun createAlertChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "zega_alert_channel",
                "ZEGA-ALERT Alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Emergency, SOS and police callback notifications"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
