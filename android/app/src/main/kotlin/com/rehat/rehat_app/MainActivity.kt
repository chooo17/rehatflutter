package com.rehat.rehat_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Channel ber-importance HIGH agar notifikasi FCM tampil sebagai
        // heads-up (popup), bukan hanya masuk ke tray secara senyap.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "high_importance_channel",
                "Notifikasi Penting",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Notifikasi pesanan & promo Rehat Coffeehouse"
                enableVibration(true)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }
}
