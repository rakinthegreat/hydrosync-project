package com.rakin.hydrosync;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.widget.RemoteViews;
import android.util.Log;

public class HydroSyncWidgetProvider extends AppWidgetProvider {
    private static final String PREFS_NAME = "HydroSyncWidgetPrefs";
    private static final String REFRESH_ACTION = "com.rakin.hydrosync.WIDGET_REFRESH";
    private static final long REFRESH_INTERVAL_MS = 5 * 60 * 1000L; // 5 minutes
    
    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int widgetId : appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId);
        }
    }

    @Override
    public void onEnabled(Context context) {
        // Called when the FIRST widget instance is placed — start the 5-min alarm
        scheduleRefresh(context);
    }

    @Override
    public void onDisabled(Context context) {
        // Called when the LAST widget instance is removed — cancel to save battery
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        Intent intent = new Intent(context, HydroSyncWidgetProvider.class);
        intent.setAction(REFRESH_ACTION);
        int flags = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
            ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
            : PendingIntent.FLAG_UPDATE_CURRENT;
        PendingIntent pi = PendingIntent.getBroadcast(context, 0, intent, flags);
        if (am != null) am.cancel(pi);
    }

    private static void scheduleRefresh(Context context) {
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        Intent intent = new Intent(context, HydroSyncWidgetProvider.class);
        intent.setAction(REFRESH_ACTION);
        int flags = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
            ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
            : PendingIntent.FLAG_UPDATE_CURRENT;
        PendingIntent pi = PendingIntent.getBroadcast(context, 0, intent, flags);
        if (am != null) {
            am.setInexactRepeating(
                AlarmManager.ELAPSED_REALTIME,
                android.os.SystemClock.elapsedRealtime() + REFRESH_INTERVAL_MS,
                REFRESH_INTERVAL_MS,
                pi
            );
            android.util.Log.d("HydroSyncWidget", "Auto-refresh alarm scheduled (5 min)");
        }
    }

    @Override
    public void onAppWidgetOptionsChanged(Context context, AppWidgetManager appWidgetManager, int appWidgetId, Bundle newOptions) {
        updateWidget(context, appWidgetManager, appWidgetId);
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions);
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        // Force update all widgets whenever ANY intent is received (including from Flutter)
        AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
        android.content.ComponentName thisWidget = new android.content.ComponentName(context, HydroSyncWidgetProvider.class);
        int[] allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget);
        for (int widgetId : allWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId);
        }
    }

    public static void updateWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        try {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.hydro_sync_widget);
            views.setTextViewText(R.id.widget_timestamp, String.valueOf(System.currentTimeMillis()));

            // 1. Detect Width for Adaptive Layout
            Bundle options = appWidgetManager.getAppWidgetOptions(appWidgetId);
            int minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0);
            boolean isWide = minWidth >= 180 || minWidth == 0; // Default to wide if unknown

            if (isWide) {
                views.setViewVisibility(R.id.widget_narrow_container, android.view.View.GONE);
                views.setViewVisibility(R.id.widget_wide_container, android.view.View.VISIBLE);
            } else {
                views.setViewVisibility(R.id.widget_narrow_container, android.view.View.VISIBLE);
                views.setViewVisibility(R.id.widget_wide_container, android.view.View.GONE);
            }

            // ... (Background logic)
            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            String theme = prefs.getString("theme_" + appWidgetId, "auto");
            int transparency = prefs.getInt("transparency_" + appWidgetId, 0);

            boolean isDarkMode = true;
            if ("light".equals(theme)) {
                isDarkMode = false;
            } else if ("auto".equals(theme)) {
                int nightModeFlags = context.getResources().getConfiguration().uiMode & android.content.res.Configuration.UI_MODE_NIGHT_MASK;
                isDarkMode = nightModeFlags == android.content.res.Configuration.UI_MODE_NIGHT_YES;
            }

            int bgColor = isDarkMode ? Color.BLACK : Color.WHITE;
            int textColor = isDarkMode ? Color.WHITE : Color.BLACK;
            int alpha = (int) ((1.0 - (transparency / 100.0)) * 255);

            views.setInt(R.id.widget_bg, "setImageAlpha", alpha);
            views.setInt(R.id.widget_bg, "setColorFilter", bgColor);

            // 3. Get Hydration Data from HomeWidget
            SharedPreferences mainPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE);
            String progressStr = mainPrefs.getString("progress", "0 / 2500");
            android.util.Log.d("HydroSyncWidget", "Syncing Data: " + progressStr);
            
            int consumed = 0;
            int total = 2500;
            int progressPercent = 0;

            try {
                // Robust parsing for "500 / 2500 mL"
                String cleaned = progressStr.replaceAll("[^0-9/]", "");
                String[] parts = cleaned.split("/");
                if (parts.length == 2) {
                    consumed = Integer.parseInt(parts[0]);
                    total = Integer.parseInt(parts[1]);
                    
                    if (total > 0) {
                        progressPercent = (int) ((consumed / (float) total) * 100);
                        if (progressPercent > 100) progressPercent = 100;
                    }
                }
            } catch (Exception e) {
                android.util.Log.e("HydroSyncWidget", "Parse Error: " + e.getMessage());
            }

            int remaining = total - consumed;
            if (remaining < 0) remaining = 0;

            // 4. Build Styled Text
            String numberStr = String.valueOf(remaining);
            String suffixStr = " mL left";
            android.text.SpannableString ss = new android.text.SpannableString(numberStr + suffixStr);
            ss.setSpan(new android.text.style.StyleSpan(android.graphics.Typeface.BOLD), 0, numberStr.length(), 0);
            ss.setSpan(new android.text.style.RelativeSizeSpan(0.65f), numberStr.length(), ss.length(), 0);
            
            // Update both layout versions
            views.setTextViewText(R.id.widget_progress_narrow, ss);
            views.setTextColor(R.id.widget_progress_narrow, textColor);
            views.setProgressBar(R.id.widget_progress_bar_narrow, 100, progressPercent, false);

            views.setTextViewText(R.id.widget_progress_wide, ss);
            views.setTextColor(R.id.widget_progress_wide, textColor);
            views.setProgressBar(R.id.widget_progress_bar_wide, 100, progressPercent, false);

            // 5. Intent
            Intent launchIntent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
            if (launchIntent != null) {
                int flags = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M 
                    ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT 
                    : PendingIntent.FLAG_UPDATE_CURRENT;
                PendingIntent pendingIntent = PendingIntent.getActivity(context, appWidgetId, launchIntent, flags);
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent);
            }

            // 6. Refresh Button Intent
            Intent refreshIntent = new Intent(context, HydroSyncWidgetProvider.class);
            refreshIntent.setAction(REFRESH_ACTION);
            int refreshFlags = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
                : PendingIntent.FLAG_UPDATE_CURRENT;
            PendingIntent refreshPendingIntent = PendingIntent.getBroadcast(context, appWidgetId, refreshIntent, refreshFlags);
            views.setOnClickPendingIntent(R.id.widget_refresh_button, refreshPendingIntent);

            // 7. Final Update
            appWidgetManager.updateAppWidget(appWidgetId, views);
        } catch (Exception e) {
            android.util.Log.e("HydroSyncWidget", "Update Error: " + e.getMessage());
        }
    }
}
