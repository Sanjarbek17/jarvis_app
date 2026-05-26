package com.example.controller_phone

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.provider.Settings
import android.text.TextUtils
import android.content.Context
import android.media.ToneGenerator
import android.media.AudioManager
import android.content.Intent

class VoiceControlPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private val toneGen by lazy { ToneGenerator(AudioManager.STREAM_NOTIFICATION, 80) }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.controller_phone/voice_control")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isAccessibilityServiceEnabled" -> {
                context?.let {
                    result.success(isAccessibilityServiceEnabled(it))
                } ?: result.error("NO_CONTEXT", "Context is null", null)
            }
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
            "performTap" -> {
                val x = (call.argument<Any>("x") as? Number)?.toFloat() ?: 0f
                val y = (call.argument<Any>("y") as? Number)?.toFloat() ?: 0f
                PhoneControlAccessibilityService.instance?.performTap(x, y)
                result.success(true)
            }
            "getScreenContent" -> {
                val content = PhoneControlAccessibilityService.instance?.getScreenContent() ?: "[accessibility service not connected]"
                result.success(content)
            }
            "closeCurrentApp" -> {
                PhoneControlAccessibilityService.instance?.closeCurrentApp()
                result.success(true)
            }
            "clickByLabel" -> {
                val label = call.argument<String>("label") ?: ""
                val clicked = PhoneControlAccessibilityService.instance?.clickByLabel(label) ?: false
                result.success(clicked)
            }
            "launchApp" -> {
                val appName = call.argument<String>("name") ?: ""
                context?.let {
                    result.success(launchAppByName(it, appName))
                } ?: result.success(false)
            }
            "openAccessibilitySettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context?.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INTENT_ERROR", e.message, null)
                }
            }
            "playActivationSound" -> {
                toneGen.startTone(ToneGenerator.TONE_PROP_BEEP, 80)
                android.os.Handler(android.os.Looper.getMainLooper())
                    .postDelayed({ toneGen.startTone(ToneGenerator.TONE_PROP_BEEP, 80) }, 120)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    private fun launchAppByName(ctx: Context, name: String): Boolean {
        val pm = ctx.packageManager
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
                ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                ?: return false
            ctx.startActivity(intent)
            true
        } catch (e: Exception) { false }
    }

    private fun isAccessibilityServiceEnabled(ctx: Context): Boolean {
        val expected = "${ctx.packageName}/${PhoneControlAccessibilityService::class.java.canonicalName}"
        val enabled  = Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':').also { it.setString(enabled) }
        return splitter.any { it.equals(expected, ignoreCase = true) }
    }
}
