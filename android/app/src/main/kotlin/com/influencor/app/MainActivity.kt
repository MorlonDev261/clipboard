package com.influencor.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.influencor.app/storage_permissions"
    private val manageStorageRequest = 4610
    private val legacyStorageRequest = 4611
    private val pushChannelId = "poma-notifications"
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureNotificationChannel()
    }

    /**
     * Same channel id as the server (`channelId` in push-provider.ts of the
     * poma-original project) and as the manifest default: a push received while
     * the app is closed lands in a high-importance channel (heads-up, sound)
     * instead of Android's fallback "Miscellaneous" one.
     */
    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(pushChannelId) != null) return
        val channel = NotificationChannel(
            pushChannelId,
            "Notifications Influencor",
            NotificationManager.IMPORTANCE_HIGH
        )
        channel.description = "Commandes, gains et actualités du programme revendeur"
        channel.enableVibration(true)
        manager.createNotificationChannel(channel)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasStorageAccess" -> result.success(hasStorageAccess())
                "requestStorageAccess" -> requestStorageAccess(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun hasStorageAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
            val read = checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
            val write = checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
            read && write
        }
    }

    private fun requestStorageAccess(result: MethodChannel.Result) {
        if (hasStorageAccess()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.success(false)
            return
        }
        pendingPermissionResult = result
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val uri = Uri.parse("package:$packageName")
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, uri)
                startActivityForResult(intent, manageStorageRequest)
            } catch (_: Exception) {
                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                startActivityForResult(intent, manageStorageRequest)
            }
        } else {
            requestPermissions(
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                ),
                legacyStorageRequest
            )
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == manageStorageRequest) {
            pendingPermissionResult?.success(hasStorageAccess())
            pendingPermissionResult = null
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == legacyStorageRequest) {
            pendingPermissionResult?.success(hasStorageAccess())
            pendingPermissionResult = null
        }
    }
}
