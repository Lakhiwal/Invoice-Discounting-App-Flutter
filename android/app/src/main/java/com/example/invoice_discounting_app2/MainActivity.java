package com.example.invoice_discounting_app2;

import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.view.Display;
import android.view.WindowManager;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterFragmentActivity {

    private static final String DISPLAY_CHANNEL = "app/display";
    private static final String WIDGET_CHANNEL = "widget_navigation";

    private String pendingTab;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        handleWidgetNavigation(getIntent());
    }

    private void handleWidgetNavigation(Intent intent) {
        if (intent != null && intent.hasExtra("open_tab")) {
            pendingTab = intent.getStringExtra("open_tab");
        }
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        setupWidgetChannel(flutterEngine);
        setupDisplayChannel(flutterEngine);
    }

    private void setupWidgetChannel(FlutterEngine flutterEngine) {

        if (pendingTab == null) return;

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                WIDGET_CHANNEL
        ).invokeMethod("openTab", pendingTab);

        pendingTab = null;
    }

    private void setupDisplayChannel(FlutterEngine flutterEngine) {

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                DISPLAY_CHANNEL
        ).setMethodCallHandler((call, result) -> {

            if (!call.method.equals("setRefreshMode")) {
                result.notImplemented();
                return;
            }

            String mode = call.argument("mode");

            try {

                Display display;

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display = getDisplay();
                } else {
                    display = getWindowManager().getDefaultDisplay();
                }

                if (display == null) {
                    result.success(null);
                    return;
                }

                if ("max".equals(mode)) {
                    setMaxRefreshRate(display);
                } else {
                    set60Hz(display);
                }

                result.success(null);

            } catch (Exception e) {
                result.success(null);
            }
        });
    }

    private void setMaxRefreshRate(Display display) {

        Display.Mode[] modes = display.getSupportedModes();
        Display.Mode bestMode = modes[0];

        for (Display.Mode mode : modes) {
            if (mode.getRefreshRate() > bestMode.getRefreshRate()) {
                bestMode = mode;
            }
        }

        applyDisplayMode(bestMode.getModeId());
    }

    private void set60Hz(Display display) {

        Display.Mode[] modes = display.getSupportedModes();

        for (Display.Mode mode : modes) {
            if (Math.round(mode.getRefreshRate()) == 60) {
                applyDisplayMode(mode.getModeId());
                return;
            }
        }
    }

    private void applyDisplayMode(int modeId) {

        WindowManager.LayoutParams params = getWindow().getAttributes();
        params.preferredDisplayModeId = modeId;
        getWindow().setAttributes(params);
    }
}