package com.refi64.zdata.app


import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent


class BootReceiver(): BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    var mountall = Runtime.getRuntime().exec(
                      "su -c sh /data/data/com.refi64.zdata.app/app_flutter/mountall.sh")
    mountall.waitFor()
  }
}
