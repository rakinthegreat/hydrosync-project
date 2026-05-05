package com.rakin.hydrosync

import android.content.Context
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.view.FlutterCallbackInformation
import io.flutter.FlutterInjector

class MaintenanceWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    override fun doWork(): Result {
        Log.d("MaintenanceWorker", "Background work starting...")

        // Waking up Flutter in the background
        val engine = FlutterEngine(applicationContext)
        
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)

            val entrypoint = DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(),
                "backgroundEntry" // This matches the @pragma('vm:entry-point') in main.dart
            )

            // Run the Dart code
            engine.dartExecutor.executeDartEntrypoint(entrypoint)
            
            Log.d("MaintenanceWorker", "Dart background isolate launched successfully.")
            
            // We give it some time to finish the async logic (Gemini API call)
            // In a more complex app, we'd use a countdown latch or a MethodChannel callback
            Thread.sleep(30000) // Wait 30 seconds for AI to finish
            
            return Result.success()
        } catch (e: Exception) {
            Log.e("MaintenanceWorker", "Background task failed: ${e.message}")
            return Result.retry()
        } finally {
            // Cleanup to save memory
            // engine.destroy() // Optional: Destroying might interrupt the work if not careful
        }
    }
}
