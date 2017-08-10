package com.refi64.zdata.app


import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

import android.app.NotificationManager
import android.app.Notification



class BootReceiver(): BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    var builder = Notification.Builder(context)
    builder.setSmallIcon(R.mipmap.ic_launcher)
    builder.setContentTitle("zdata")
    builder.setContentText("Mounting apps...")
    builder.setOngoing(true)

    var mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    mgr.notify(0, builder.build())

    var mountall = Runtime.getRuntime().exec(
                      "su -c sh /data/data/com.refi64.zdata.app/app_flutter/mountall.sh")
    mountall.waitFor()

    builder.setContentText("App mount completed!")
    builder.setOngoing(false)
    mgr.notify(0, builder.build())
  }
}
