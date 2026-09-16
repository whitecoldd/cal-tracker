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

    // Hand-rolled for the same reason as the one above: `url_launcher` is a
    // plugin, and §3 of CLAUDE.md is a record of what a plugin that resolves
    // in pub but does not build on Android costs. Opening a web page is one
    // intent, so it is one intent here.
    //
    // Used by the Open Food Facts hand-off: a product the ledger has never
    // held is written down locally and the user is sent to the ledger's own
    // add-product form to file it. The app deliberately does not submit on
    // their behalf — Open Food Facts authenticates writes with an account
    // password rather than a scoped token, and that is not a thing to keep.
    private val linksChannel = "com.whitecoldd.cal_tracker/links"

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, linksChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> result.success(openUrl(call.argument<String>("url")))
                    else -> result.notImplemented()
                }
            }
    }

    // Returns false rather than throwing when nothing will take the intent.
    // A phone with no browser is a thing to mention beside the transcript the
    // user can still copy, not a reason to unwind the sheet they are in.
    private fun openUrl(url: String?): Boolean {
        if (url.isNullOrBlank()) return false

        val uri = try {
            Uri.parse(url)
        } catch (e: Exception) {
            return false
        }

        // The Dart side checks this too. Kept here as well because this
        // handler is reachable by anything that can talk to the engine, and
        // an ACTION_VIEW that will take any scheme is a wider door than it
        // looks: `file://` and `content://` intents read as the app.
        if (uri.scheme != "http" && uri.scheme != "https") return false

        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            // Started from a method-channel callback rather than from an
            // activity's own click handler, so it needs its own task.
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        return try {
            startActivity(intent)
            true
        } catch (e: android.content.ActivityNotFoundException) {
            false
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
