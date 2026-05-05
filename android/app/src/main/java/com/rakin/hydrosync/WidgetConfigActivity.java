package com.rakin.hydrosync;

import android.app.Activity;
import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.RadioGroup;
import android.widget.SeekBar;
import android.widget.LinearLayout;

public class WidgetConfigActivity extends Activity {
    private int appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID;
    private SharedPreferences prefs;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // 1. Set Result to Canceled (in case user backs out)
        setResult(RESULT_CANCELED);

        setContentView(R.layout.widget_config);

        // 2. Get AppWidgetId
        Intent intent = getIntent();
        Bundle extras = intent.getExtras();
        if (extras != null) {
            appWidgetId = extras.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID);
        }

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish();
            return;
        }

        prefs = getSharedPreferences("HydroSyncWidgetPrefs", Context.MODE_PRIVATE);

        // 3. UI Hooks
        final LinearLayout previewPill = findViewById(R.id.config_preview_pill);
        final android.widget.TextView previewText = findViewById(R.id.config_preview_text);
        final RadioGroup themeGroup = findViewById(R.id.config_theme_group);
        final SeekBar transparencySeek = findViewById(R.id.config_transparency_seek);
        final View saveBtn = findViewById(R.id.config_btn_save);
        final View cancelBtn = findViewById(R.id.config_btn_cancel);

        // 4. LOAD EXISTING SETTINGS
        String savedTheme = prefs.getString("theme_" + appWidgetId, "auto");
        int savedTransparency = prefs.getInt("transparency_" + appWidgetId, 0);
        
        if ("light".equals(savedTheme)) themeGroup.check(R.id.config_radio_light);
        else if ("dark".equals(savedTheme)) themeGroup.check(R.id.config_radio_dark);
        else themeGroup.check(R.id.config_radio_auto);
        
        int savedStep = 0;
        if (savedTransparency == 50) savedStep = 1;
        else if (savedTransparency == 100) savedStep = 2;
        transparencySeek.setProgress(savedStep);

        updatePreview(previewPill, previewText, themeGroup, transparencySeek);

        // 5. LISTENERS
        themeGroup.setOnCheckedChangeListener((group, checkedId) -> updatePreview(previewPill, previewText, themeGroup, transparencySeek));
        transparencySeek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                updatePreview(previewPill, previewText, themeGroup, transparencySeek);
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        // 5. Cancel Logic
        cancelBtn.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { finish(); }
        });

        // 6. Save Logic
        saveBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                String theme = "auto";
                int checkedId = themeGroup.getCheckedRadioButtonId();
                if (checkedId == R.id.config_radio_light) theme = "light";
                else if (checkedId == R.id.config_radio_dark) theme = "dark";

                int step = transparencySeek.getProgress();
                int transparency = 0;
                if (step == 1) transparency = 50;
                else if (step == 2) transparency = 100;

                SharedPreferences.Editor editor = prefs.edit();
                editor.putString("theme_" + appWidgetId, theme);
                editor.putInt("transparency_" + appWidgetId, transparency);
                editor.apply();

                // Notify Widget to update immediately
                AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(WidgetConfigActivity.this);
                HydroSyncWidgetProvider.updateWidget(WidgetConfigActivity.this, appWidgetManager, appWidgetId);

                Intent resultValue = new Intent();
                resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
                setResult(RESULT_OK, resultValue);
                finish();
            }
        });
    }

    private void updatePreview(LinearLayout pill, android.widget.TextView text, RadioGroup themeGroup, SeekBar seek) {
        int checkedId = themeGroup.getCheckedRadioButtonId();
        int baseColor = Color.BLACK;
        int textColor = Color.WHITE;

        if (checkedId == R.id.config_radio_light) {
            baseColor = Color.WHITE;
            textColor = Color.BLACK;
        } else if (checkedId == R.id.config_radio_auto) {
            // Check system theme for preview
            int nightModeFlags = getResources().getConfiguration().uiMode & android.content.res.Configuration.UI_MODE_NIGHT_MASK;
            if (nightModeFlags != android.content.res.Configuration.UI_MODE_NIGHT_YES) {
                baseColor = Color.WHITE;
                textColor = Color.BLACK;
            }
        }
        
        int step = seek.getProgress();
        float transparencyPercent = 0f;
        if (step == 1) transparencyPercent = 0.5f;
        else if (step == 2) transparencyPercent = 1.0f;

        int alpha = (int) ((1.0 - transparencyPercent) * 255);
        
        pill.setBackgroundTintList(android.content.res.ColorStateList.valueOf(baseColor));
        pill.getBackground().setAlpha(alpha);
        text.setTextColor(textColor);
    }
}
