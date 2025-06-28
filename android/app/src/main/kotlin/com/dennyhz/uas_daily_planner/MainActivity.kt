package com.dennyhz.uas_daily_planner

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        // Handler untuk klik tombol Add Task di widget
        @JvmStatic
        fun onAddTaskClick(context: Context) {
            val intent = Intent(Intent.ACTION_VIEW)
            intent.data = android.net.Uri.parse("uasplanner://addtask")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }
    }
}
