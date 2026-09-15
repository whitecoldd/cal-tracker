package com.whitecoldd.cal_tracker

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// The health plugin (Health Connect) requires a FragmentActivity host so it can
// launch the permission-request contract. Do not change this back to FlutterActivity.
class MainActivity : FlutterFragmentActivity() {

    // Why this is hand-rolled rather than a package: `permission_handler` 14.1.0
    // does not compile against this project's Gradle/KGP combination, and the
    // only permission it was wanted for is this one. See CLAUDE.md §3.
    //
    // MANAGE_EXTERNAL_STORAGE is a deliberate choice for a sideloaded personal
    // build: the backup mirror writes to a real, browsable path the user can
    // copy off the device with a file manager or a USB cable. A SAF directory
    // picker with a persisted URI would be the Play Store answer, and is the
    // swap to make if this app ever ships.
    private val channel = "com.whitecoldd.cal_tracker/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAccess" -> result.success(hasAllFilesAccess())
                    "requestAccess" -> {
                        requestAllFilesAccess()
                        // Android gives no callback here: the user leaves for
                        // Settings and may never come back. Dart re-checks
                        // `hasAccess` when the app resumes rather than waiting
                        // on a result that might never arrive.
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasAllFilesAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            // Below API 30 the legacy WRITE_EXTERNAL_STORAGE grant covers this,
            // and minSdk is 26.
            true
        }
    }

    private fun requestAllFilesAccess() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return

        // Ask for this app specifically. The bare action opens a list of every
        // installed app, which is a worse place to land the user.
        val intent = Intent(
            Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
            Uri.parse("package:$packageName"),
        )

        try {
            startActivity(intent)
        } catch (e: android.content.ActivityNotFoundException) {
            // Some OEM builds ship without the per-app screen.
            startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
        }
    }
}
