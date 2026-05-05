package com.rakin.hydrosync

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.app.AlertDialog
import android.view.ContextThemeWrapper
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val NOTIFICATION_REQUEST_CODE = 123
    private val LOCATION_REQUEST_CODE = 124
    private val BACKGROUND_LOCATION_REQUEST_CODE = 125
    private val OVERLAY_REQUEST_CODE = 126

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 1. Check for updates
        Updater.checkForUpdates(this)

        // 2. Start Permission Chain
        checkPermissionsAndStability()

        // 3. Schedule Background Maintenance (Native)
        scheduleMaintenanceTask()
    }

    private fun scheduleMaintenanceTask() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val maintenanceRequest = PeriodicWorkRequestBuilder<MaintenanceWorker>(24, TimeUnit.HOURS)
            .setConstraints(constraints)
            .build()

        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
            "com.rakin.hydrosync.daily_maintenance",
            ExistingPeriodicWorkPolicy.KEEP, // Keep existing if already scheduled
            maintenanceRequest
        )
    }

    private fun checkPermissionsAndStability() {
        // Step A: Notifications (Android 13+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_REQUEST_CODE)
                return
            }
        }
        
        // Step B: Foreground Location
        checkForegroundLocation()
    }

    private fun checkForegroundLocation() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), LOCATION_REQUEST_CODE)
        } else {
            checkBackgroundLocation()
        }
    }

    private fun checkBackgroundLocation() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                showBackgroundLocationDialog()
            } else {
                checkBatteryOptimization()
            }
        } else {
            checkBatteryOptimization()
        }
    }

    private fun materialDialog(): MaterialAlertDialogBuilder {
        val themed = ContextThemeWrapper(this, R.style.HydroSyncDialog)
        return MaterialAlertDialogBuilder(themed)
    }

    private fun showBackgroundLocationDialog() {
        materialDialog()
            .setTitle("Weather Accuracy")
            .setMessage("To calculate hydration goals based on your local temperature and humidity, HydroSync needs access to location in the background.")
            .setPositiveButton("Configure") { _, _ ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), BACKGROUND_LOCATION_REQUEST_CODE)
                }
            }
            .setNegativeButton("Later") { _, _ -> checkBatteryOptimization() }
            .setCancelable(false)
            .show()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            NOTIFICATION_REQUEST_CODE -> checkForegroundLocation()
            LOCATION_REQUEST_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    checkBackgroundLocation()
                } else {
                    checkBatteryOptimization()
                }
            }
            BACKGROUND_LOCATION_REQUEST_CODE -> checkBatteryOptimization()
        }
    }

    private fun checkBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                showBatteryOptimizationDialog()
            } else {
                checkOverlayPermission()
            }
        } else {
            checkOverlayPermission()
        }
    }

    private fun checkOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                showOverlayPermissionDialog()
            }
        }
    }

    private fun showOverlayPermissionDialog() {
        materialDialog()
            .setTitle("Immersive Reminders")
            .setMessage("To allow hydration reminders to automatically take over your screen like a real alarm, please allow HydroSync to 'Display over other apps'.")
            .setPositiveButton("Allow") { _, _ ->
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                startActivityForResult(intent, OVERLAY_REQUEST_CODE)
            }
            .setNegativeButton("Later", null)
            .setCancelable(false)
            .show()
    }

    private fun showBatteryOptimizationDialog() {
        materialDialog()
            .setTitle("Reminder Stability")
            .setMessage("To ensure your hydration reminders and home screen widgets update instantly, HydroSync needs to stay active in the background. Please select 'Allow' in the next prompt.")
            .setPositiveButton("Proceed") { _, _ ->
                val intent = Intent().apply {
                    action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                    data = Uri.parse("package:$packageName")
                }
                startActivityForResult(intent, 0) // Just to trigger something, but ideally it should follow through
                checkOverlayPermission() // Try to move to next anyway
            }
            .setNegativeButton("Later") { _, _ -> checkOverlayPermission() }
            .setCancelable(false)
            .show()
    }
}
