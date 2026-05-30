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
import android.view.KeyEvent
import android.app.Instrumentation
import android.util.Base64
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import android.app.Activity
import android.os.Build

class VoiceControlPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel : MethodChannel
  private var context: Context? = null
  private var activity: Activity? = null
  private var pendingPermissionResult: Result? = null
  private val SCREEN_CAPTURE_REQUEST_CODE = 4321
  private val toneGen by lazy { ToneGenerator(AudioManager.STREAM_NOTIFICATION, 80) }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.controller_phone/voice_control")
    channel.setMethodCallHandler(this)
  }

  private fun getServiceInstance(): Any? {
      return try {
          // Kotlin companion objects are stored as a static field named "Companion" on the outer class
          val outerClass = Class.forName("com.example.controller_phone.PhoneControlAccessibilityService")
          val companionField = outerClass.getDeclaredField("Companion")
          companionField.isAccessible = true
          val companion = companionField.get(null)
          val getter = companion.javaClass.getDeclaredMethod("getInstance")
          getter.isAccessible = true
          getter.invoke(companion)
      } catch (e: Exception) {
          android.util.Log.e("VoiceControlPlugin", "getServiceInstance failed: ${e.message}")
          null
      }
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

    if (call.method == "getScreenSize") {
      val ctx = context ?: return result.error("NO_CONTEXT", "Context is null", null)
      val metrics = ctx.resources.displayMetrics
      val sizeMap = mapOf(
          "width" to metrics.widthPixels,
          "height" to metrics.heightPixels
      )
      result.success(sizeMap)
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

    if (call.method == "requestScreenCapturePermission") {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            result.success(true)
            return
        }
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity is null", null)
            return
        }
        val manager = act.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as android.media.projection.MediaProjectionManager
        act.startActivityForResult(manager.createScreenCaptureIntent(), SCREEN_CAPTURE_REQUEST_CODE)
        pendingPermissionResult = result
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

    val service = getServiceInstance()

    try {
        when (call.method) {
            "performBack" -> {
                if (service == null) {
                    result.success(false)
                    return
                }
                service.javaClass.getMethod("performBack").invoke(service)
                result.success(true)
            }
            "performHome" -> {
                if (service != null) {
                    android.widget.Toast.makeText(context, "Accessibility Home Triggered", android.widget.Toast.LENGTH_SHORT).show()
                    service.javaClass.getMethod("performHome").invoke(service)
                    result.success("Accessibility Home Triggered")
                } else {
                    android.widget.Toast.makeText(context, "Intent Home Triggered", android.widget.Toast.LENGTH_SHORT).show()
                    try {
                        val intent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        context?.startActivity(intent)
                        result.success("Intent Home Triggered")
                    } catch (e: Exception) {
                        result.success("Intent Error: ${e.message}")
                    }
                }
            }
            "performRecents" -> {
                if (service != null) {
                    service.javaClass.getMethod("performRecents").invoke(service)
                    result.success(true)
                } else {
                    // Fallback: simulate the App Switch key press on a background thread
                    try {
                        Thread {
                            val inst = Instrumentation()
                            inst.sendKeyDownUpSync(KeyEvent.KEYCODE_APP_SWITCH)
                        }.start()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
            }
            "performTap" -> {
                if (service == null) return result.success(false)
                val x = (call.argument<Any>("x") as? Number)?.toFloat() ?: 0f
                val y = (call.argument<Any>("y") as? Number)?.toFloat() ?: 0f
                service.javaClass.getMethod("performTap", Float::class.java, Float::class.java).invoke(service, x, y)
                result.success(true)
            }
            "getScreenContent" -> {
                if (service == null) return result.success("[accessibility service not connected]")
                val content = service.javaClass.getMethod("getScreenContent").invoke(service) as? String ?: "[accessibility service not connected]"
                result.success(content)
            }
            "takeScreenshot" -> {
                if (service == null) return result.success(null)
                // Invoke takeScreenshotCompat(callback) via reflection
                val method = service.javaClass.getMethod("takeScreenshotCompat", Function1::class.java)
                method.invoke(service, { bytes: ByteArray? ->
                    if (bytes != null) {
                        val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                        result.success(b64)
                    } else {
                        result.success(null)
                    }
                })
            }
            "closeCurrentApp" -> {
                if (service == null) return result.success(false)
                service.javaClass.getMethod("closeCurrentApp").invoke(service)
                result.success(true)
            }
            "clickByLabel" -> {
                if (service == null) return result.success(false)
                val label = call.argument<String>("label") ?: ""
                val clicked = service.javaClass.getMethod("clickByLabel", String::class.java).invoke(service, label) as? Boolean ?: false
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

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
      activity = binding.activity
      binding.addActivityResultListener { requestCode, resultCode, data ->
          if (requestCode == SCREEN_CAPTURE_REQUEST_CODE) {
              val pending = pendingPermissionResult
              pendingPermissionResult = null
              if (resultCode == Activity.RESULT_OK && data != null) {
                  val act = activity
                  if (act != null) {
                      try {
                          val manager = act.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as android.media.projection.MediaProjectionManager
                          val projection = manager.getMediaProjection(resultCode, data)
                          
                          val serviceClass = Class.forName("com.example.controller_phone.PhoneControlAccessibilityService")
                          val companionField = serviceClass.getDeclaredField("Companion")
                          companionField.isAccessible = true
                          val companion = companionField.get(null)
                          val setter = companion.javaClass.getDeclaredMethod("setMediaProjection", android.media.projection.MediaProjection::class.java)
                          setter.isAccessible = true
                          setter.invoke(companion, projection)
                          
                          android.util.Log.d("VoiceControlPlugin", "MediaProjection stored in service.")
                          pending?.success(true)
                      } catch (e: Exception) {
                          android.util.Log.e("VoiceControlPlugin", "Failed to store MediaProjection: ${e.message}")
                          pending?.success(false)
                      }
                  } else {
                      pending?.success(false)
                  }
              } else {
                  pending?.success(false)
              }
              true
          } else {
              false
          }
      }
  }

  override fun onDetachedFromActivityForConfigChanges() {
      activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
      activity = binding.activity
  }

  override fun onDetachedFromActivity() {
      activity = null
  }
}
