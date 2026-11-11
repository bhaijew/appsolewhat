package com.solepizza.pizza_admin

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.solepizza.pizza_admin/notifications"
        private const val NOTIF_CHANNEL_ID = "online_orders_alerts_v2"
        private const val NOTIF_CHANNEL_NAME = "New Online Orders"

        fun showSystemAlert(context: Context, id: Int, title: String, body: String) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val existing = manager.getNotificationChannel(NOTIF_CHANNEL_ID)
                if (existing == null) {
                    val channel = NotificationChannel(
                        NOTIF_CHANNEL_ID,
                        NOTIF_CHANNEL_NAME,
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "Alerts when a new online order needs verification"
                        enableVibration(true)
                        vibrationPattern = longArrayOf(0, 400, 200, 400)
                        val attrs = AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                        setSound(soundUri, attrs)
                    }
                    manager.createNotificationChannel(channel)
                }
            }

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(context, id, launchIntent, pendingFlags)

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, NOTIF_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
                    .setPriority(Notification.PRIORITY_HIGH)
                    .setSound(soundUri)
            }

            builder.setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(Notification.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                builder.setVisibility(Notification.VISIBILITY_PUBLIC)
                builder.setCategory(Notification.CATEGORY_MESSAGE)
            }

            manager.notify(id, builder.build())
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "showAlert") {
                val id = call.argument<Int>("id") ?: 1001
                val title = call.argument<String>("title") ?: "New Online Order"
                val body = call.argument<String>("body") ?: "Open app to verify order"
                showSystemAlert(applicationContext, id, title, body)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
