package com.example.voice_control_plugin

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import android.media.ToneGenerator
import android.media.AudioManager
import java.lang.reflect.Method

class VoiceControlPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel
  private var context: Context? = null
  private val toneGen by lazy { ToneGenerator(AudioManager.STREAM_NOTIFICATION, 80) }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.controller_phone/voice_control")
    channel.setMethodCallHandler(this)
  }

  private fun getServiceInstance(): Any? {
      return try {
          val companionClass = Class.forName("com.example.controller_phone.PhoneControlAccessibilityService\$Companion")
          val companionObj = companionClass.getField("INSTANCE").get(null)
          companionClass.getMethod("getInstance").invoke(companionObj)
      } catch (e: Exception) { null }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "isAccessibilityServiceEnabled") {
      val ctx = context ?: return result.error("NO_CONTEXT", null, null)
      val expected = "${ctx.packageName}/com.example.controller_phone.PhoneControlAccessibilityService"
      val enabled = Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
      val splitter = TextUtils.SimpleStringSplitter(':').also { it.setString(enabled) }
      result.success(splitter.any { it.equals(expected, ignoreCase = true) })
      return
    }

    if (call.method == "launchApp") {
      val appName = call.argument<String>("name") ?: ""
      val ctx = context ?: return result.success(false)
      val pm = ctx.packageManager
      val query = appName.lowercase().trim()
      val match = pm.getInstalledApplications(android.content.pm.PackageManager.GET_META_DATA)
          .filter { pm.getApplicationLabel(it).toString().lowercase().contains(query) }
          .minByOrNull {
              val label = pm.getApplicationLabel(it).toString().lowercase()
              when {
                  label == query          -> 0
                  label.startsWith(query) -> 1
                  else                    -> 2
              }
          }
      if (match != null) {
          try {
              val intent = pm.getLaunchIntentForPackage(match.packageName)
                  ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
              if (intent != null) {
                  ctx.startActivity(intent)
                  result.success(true)
                  return
              }
          } catch (e: Exception) {}
      }
      result.success(false)
      return
    }

    if (call.method == "openAccessibilitySettings") {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context?.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("INTENT_ERROR", e.message, null)
        }
        return
    }

    if (call.method == "playActivationSound") {
        toneGen.startTone(ToneGenerator.TONE_PROP_BEEP, 80)
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({ 
            toneGen.startTone(ToneGenerator.TONE_PROP_BEEP, 80) 
        }, 120)
        result.success(true)
        return
    }

    val service = getServiceInstance() ?: return result.success(false)
    val clazz = service.javaClass

    try {
        when (call.method) {
            "performBack" -> {
                clazz.getMethod("performBack").invoke(service)
                result.success(true)
            }
            "performHome" -> {
                clazz.getMethod("performHome").invoke(service)
                result.success(true)
            }
            "performRecents" -> {
                clazz.getMethod("performRecents").invoke(service)
                result.success(true)
            }
            "performTap" -> {
                val x = (call.argument<Any>("x") as? Number)?.toFloat() ?: 0f
                val y = (call.argument<Any>("y") as? Number)?.toFloat() ?: 0f
                clazz.getMethod("performTap", Float::class.java, Float::class.java).invoke(service, x, y)
                result.success(true)
            }
            "getScreenContent" -> {
                val content = clazz.getMethod("getScreenContent").invoke(service) as? String ?: "[accessibility service not connected]"
                result.success(content)
            }
            "closeCurrentApp" -> {
                clazz.getMethod("closeCurrentApp").invoke(service)
                result.success(true)
            }
            "clickByLabel" -> {
                val label = call.argument<String>("label") ?: ""
                val clicked = clazz.getMethod("clickByLabel", String::class.java).invoke(service, label) as? Boolean ?: false
                result.success(clicked)
            }
            else -> result.notImplemented()
        }
    } catch (e: Exception) {
        result.error("REFLECTION_ERROR", e.message, null)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    context = null
  }
}
