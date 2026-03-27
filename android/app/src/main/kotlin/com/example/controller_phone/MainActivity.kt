package com.example.controller_phone

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.Settings
import android.text.TextUtils
import android.content.Context
import android.media.ToneGenerator
import android.media.AudioManager

/// Single responsibility: bridge Flutter ↔ Android platform features.
/// Routes MethodChannel calls to the appropriate service/system API.
class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.controller_phone/voice_control"
    private val toneGen by lazy { ToneGenerator(AudioManager.STREAM_NOTIFICATION, 80) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── System queries ──────────────────────────────────────
                    "isAccessibilityServiceEnabled" ->
                        result.success(isAccessibilityServiceEnabled(this))

                    // ── Global navigation ───────────────────────────────────
                    "performBack" -> {
                        PhoneControlAccessibilityService.instance?.performBack()
                        result.success(true)
                    }
                    "performHome" -> {
                        PhoneControlAccessibilityService.instance?.performHome()
                        result.success(true)
                    }
                    "performRecents" -> {
                        PhoneControlAccessibilityService.instance?.performRecents()
                        result.success(true)
                    }

                    // ── Gesture tap ─────────────────────────────────────────
                    "performTap" -> {
                        val x = (call.argument<Any>("x") as? Number)?.toFloat() ?: 0f
                        val y = (call.argument<Any>("y") as? Number)?.toFloat() ?: 0f
                        PhoneControlAccessibilityService.instance?.performTap(x, y)
                        result.success(true)
                    }

                    // ── Screen reading ──────────────────────────────────────
                    "getScreenContent" -> {
                        val content = PhoneControlAccessibilityService.instance
                            ?.getScreenContent()
                            ?: "[accessibility service not connected]"
                        result.success(content)
                    }

                    // ── Close current app ───────────────────────────────────
                    "closeCurrentApp" -> {
                        PhoneControlAccessibilityService.instance?.closeCurrentApp()
                        result.success(true)
                    }

                    // ── Click by label ──────────────────────────────────────
                    "clickByLabel" -> {
                        val label = call.argument<String>("label") ?: ""
                        val clicked = PhoneControlAccessibilityService.instance
                            ?.clickByLabel(label) ?: false
                        result.success(clicked)
                    }

                    // ── App launcher ────────────────────────────────────────
                    "launchApp" -> {
                        val appName = call.argument<String>("name") ?: ""
                        result.success(launchAppByName(appName))
                    }

                    // ── Settings shortcut ───────────────────────────────────
                    "openAccessibilitySettings" -> {
                        try {
                            val intent = android.content.Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INTENT_ERROR", e.message, null)
                        }
                    }

                    // ── Audio feedback ──────────────────────────────────────
                    "playActivationSound" -> {
                        toneGen.startTone(ToneGenerator.TONE_PROP_BEEP, 80)
                        android.os.Handler(android.os.Looper.getMainLooper())
                            .postDelayed({ toneGen.startTone(ToneGenerator.TONE_PROP_BEEP, 80) }, 120)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun launchAppByName(name: String): Boolean {
        val pm    = packageManager
        val query = name.lowercase().trim()
        val match = pm.getInstalledApplications(android.content.pm.PackageManager.GET_META_DATA)
            .filter { pm.getApplicationLabel(it).toString().lowercase().contains(query) }
            .minByOrNull {
                val label = pm.getApplicationLabel(it).toString().lowercase()
                when {
                    label == query          -> 0
                    label.startsWith(query) -> 1
                    else                    -> 2
                }
            } ?: return false

        return try {
            val intent = pm.getLaunchIntentForPackage(match.packageName)
                ?.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                ?: return false
            startActivity(intent)
            true
        } catch (e: Exception) { false }
    }

    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val expected = "${context.packageName}/${PhoneControlAccessibilityService::class.java.canonicalName}"
        val enabled  = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':').also { it.setString(enabled) }
        return splitter.any { it.equals(expected, ignoreCase = true) }
    }
}
