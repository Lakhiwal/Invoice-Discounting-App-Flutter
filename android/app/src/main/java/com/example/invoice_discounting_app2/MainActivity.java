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
import androidx.core.view.WindowCompat;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;

public class MainActivity extends FlutterFragmentActivity {

    private static final String WIDGET_CHANNEL = "widget_navigation";
    private static final String SECURITY_CHANNEL = "app/security";
    private static final String HAPTICS_CHANNEL = "app/haptics";
    private static final String SETTINGS_CHANNEL = "app/settings";

    private String pendingTab;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // Essential for Edge-to-Edge immersion
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        
        super.onCreate(savedInstanceState);
        handleWidgetNavigation(getIntent());
        
        // Automatically enable maximum supported refresh rate for a premium 120Hz feel
        enableMaxRefreshRate();
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        handleWidgetNavigation(intent);
        if (getFlutterEngine() != null) {
            setupWidgetChannel(getFlutterEngine());
        }
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
        setupSecurityChannel(flutterEngine);
        setupHapticsChannel(flutterEngine);
        setupSettingsChannel(flutterEngine);
    }

    private void setupWidgetChannel(FlutterEngine flutterEngine) {
        if (pendingTab == null) return;

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                WIDGET_CHANNEL
        ).invokeMethod("openTab", pendingTab);

        pendingTab = null;
    }

    private void enableMaxRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return;

        try {
            Display display;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display = getDisplay();
            } else {
                display = getWindowManager().getDefaultDisplay();
            }

            if (display != null) {
                Display.Mode[] modes = display.getSupportedModes();
                Display.Mode bestMode = modes[0];

                for (Display.Mode mode : modes) {
                    if (mode.getRefreshRate() > bestMode.getRefreshRate()) {
                        bestMode = mode;
                    }
                }

                WindowManager.LayoutParams params = getWindow().getAttributes();
                params.preferredDisplayModeId = bestMode.getModeId();
                getWindow().setAttributes(params);
            }
        } catch (Exception ignored) {
            // Default behavior
        }
    }

    private void setupSecurityChannel(FlutterEngine flutterEngine) {
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SECURITY_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("setSecure")) {
                        boolean isSecure = call.argument("isSecure") != null && (boolean) call.argument("isSecure");
                        if (isSecure) {
                            getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
                        } else {
                            getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
                        }
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                });
    }

    private void setupHapticsChannel(FlutterEngine flutterEngine) {
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), HAPTICS_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    String type = call.argument("type");
                    Vibrator vibrator;
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        VibratorManager vm = (VibratorManager) getSystemService(VIBRATOR_MANAGER_SERVICE);
                        vibrator = vm.getDefaultVibrator();
                    } else {
                        vibrator = (Vibrator) getSystemService(VIBRATOR_SERVICE);
                    }

                    if (vibrator == null || !vibrator.hasVibrator()) {
                        result.success(null);
                        return;
                    }

                    switch (type) {
                        case "success":
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                vibrator.vibrate(VibrationEffect.createWaveform(new long[]{0, 50, 50, 50}, -1));
                            } else {
                                vibrator.vibrate(100);
                            }
                            break;
                        case "error":
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                vibrator.vibrate(VibrationEffect.createWaveform(new long[]{0, 100, 50, 100}, -1));
                            } else {
                                vibrator.vibrate(250);
                            }
                            break;
                        case "warning":
                            vibrator.vibrate(150);
                            break;
                        default:
                            result.notImplemented();
                    }
                });
    }

    private void setupSettingsChannel(FlutterEngine flutterEngine) {
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SETTINGS_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("openAppSettings")) {
                        try {
                            Intent intent = new Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                            intent.setData(android.net.Uri.fromParts("package", getPackageName(), null));
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            startActivity(intent);
                            result.success(true);
                        } catch (Exception e) {
                            result.error("UNAVAILABLE", "Could not open settings", e.getMessage());
                        }
                    } else if (call.method.equals("openBatteryOptimization")) {
                        try {
                            Intent intent = new Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                            intent.setData(android.net.Uri.parse("package:" + getPackageName()));
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            startActivity(intent);
                            result.success(true);
                        } catch (Exception e) {
                            result.error("UNAVAILABLE", "Could not open battery settings", e.getMessage());
                        }
                    } else {
                        result.notImplemented();
                    }
                });
    }
}