package com.example.controller_phone

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Bitmap
import android.graphics.Path
import android.os.Build
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import android.media.projection.MediaProjection
import android.media.ImageReader
import android.media.Image
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper

/// Single responsibility: interact with the Android Accessibility framework.
/// Provides: global actions, gesture taps, screen content reading, click-by-label.
class PhoneControlAccessibilityService : AccessibilityService() {

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Service Connected")
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) { /* not used */ }
    override fun onInterrupt() { /* required */ }

    // ── Global actions ────────────────────────────────────────────────────────

    fun performBack()    = performGlobalAction(GLOBAL_ACTION_BACK)
    fun performHome()    = performGlobalAction(GLOBAL_ACTION_HOME)
    fun performRecents() = performGlobalAction(GLOBAL_ACTION_RECENTS)

    @androidx.annotation.RequiresApi(android.os.Build.VERSION_CODES.R)
    @android.annotation.SuppressLint("NewApi")
    fun takeScreenshot(callback: (ByteArray?) -> Unit) {
        val executor = Executors.newSingleThreadExecutor()
        takeScreenshot(
            Display.DEFAULT_DISPLAY,
            executor,
            object : AccessibilityService.TakeScreenshotCallback {
                override fun onSuccess(result: AccessibilityService.ScreenshotResult) {
                    try {
                        // Use reflection to avoid API-level compile errors on ScreenshotResult
                        val hardwareBitmap = result.javaClass
                            .getMethod("getHardwareBitmap")
                            .invoke(result) as Bitmap
                        val softBitmap = hardwareBitmap.copy(Bitmap.Config.ARGB_8888, false)
                        hardwareBitmap.recycle()
                        val stream = ByteArrayOutputStream()
                        softBitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
                        softBitmap.recycle()
                        callback(stream.toByteArray())
                    } catch (e: Exception) {
                        Log.e(TAG, "Screenshot compress failed: ${e.message}")
                        callback(null)
                    }
                }
                override fun onFailure(errorCode: Int) {
                    Log.e(TAG, "Screenshot failed with error: $errorCode")
                    callback(null)
                }
            }
        )
    }

    fun takeScreenshotCompat(callback: (ByteArray?) -> Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            takeScreenshot(callback)
        } else {
            val projection = mediaProjection
            if (projection != null) {
                takeScreenshotMediaProjection(projection, callback)
            } else {
                Log.e(TAG, "takeScreenshot requires API 30+ or MediaProjection")
                callback(null)
            }
        }
    }

    private fun takeScreenshotMediaProjection(
        projection: MediaProjection,
        callback: (ByteArray?) -> Unit
    ) {
        try {
            val metrics = resources.displayMetrics
            val width = metrics.widthPixels
            val height = metrics.heightPixels
            val dpi = metrics.densityDpi

            val imageReader = ImageReader.newInstance(
                width, height,
                PixelFormat.RGBA_8888, 2
            )

            val flags = DisplayManager.VIRTUAL_DISPLAY_FLAG_OWN_CONTENT_ONLY or
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_PUBLIC

            val virtualDisplay = projection.createVirtualDisplay(
                "ScreenCapture",
                width, height, dpi,
                flags,
                imageReader.surface, null, null
            )

            imageReader.setOnImageAvailableListener(object : ImageReader.OnImageAvailableListener {
                private var captured = false

                override fun onImageAvailable(reader: ImageReader) {
                    if (captured) return
                    captured = true

                    var image: Image? = null
                    var bitmap: Bitmap? = null
                    val bos = ByteArrayOutputStream()

                    try {
                        image = reader.acquireLatestImage()
                        if (image != null) {
                            val planes = image.planes
                            val buffer = planes[0].buffer
                            val pixelStride = planes[0].pixelStride
                            val rowStride = planes[0].rowStride
                            val rowPadding = rowStride - pixelStride * width

                            bitmap = Bitmap.createBitmap(
                                width + rowPadding / pixelStride,
                                height,
                                Bitmap.Config.ARGB_8888
                            )
                            bitmap.copyPixelsFromBuffer(buffer)

                            val croppedBitmap = Bitmap.createBitmap(bitmap, 0, 0, width, height)
                            croppedBitmap.compress(Bitmap.CompressFormat.PNG, 90, bos)
                            croppedBitmap.recycle()

                            callback(bos.toByteArray())
                        } else {
                            callback(null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "MediaProjection screenshot error: ${e.message}")
                        callback(null)
                    } finally {
                        image?.close()
                        bitmap?.recycle()
                        virtualDisplay?.release()
                        imageReader.close()
                    }
                }
            }, Handler(Looper.getMainLooper()))

        } catch (e: Exception) {
            Log.e(TAG, "MediaProjection setup failed: ${e.message}")
            callback(null)
        }
    }

    fun performTap(x: Float, y: Float) {
        Log.d(TAG, "performTap: dispatching gesture at ($x, $y)")
        val path = Path().also { it.moveTo(x, y) }
        val stroke = GestureDescription.StrokeDescription(path, 0, 100)
        val success = dispatchGesture(
            GestureDescription.Builder().addStroke(stroke).build(),
            object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    Log.d(TAG, "performTap: gesture completed at ($x, $y)")
                }
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    Log.e(TAG, "performTap: gesture cancelled at ($x, $y)")
                }
            },
            Handler(Looper.getMainLooper())
        )
        Log.d(TAG, "performTap: dispatchGesture returned $success")
    }

    /// Closes the app that is currently visible to the user.
    fun closeCurrentApp() {
        // Snapshot the foreground app package while we still have focus
        val targetPkg  = rootInActiveWindow?.packageName?.toString()
        val ownPkg     = packageName  // "com.example.controller_phone"

        performGlobalAction(GLOBAL_ACTION_RECENTS)

        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            val root = rootInActiveWindow
            if (root != null) {
                // In recents, the node packages usually belong to the launcher!
                // So dismissTaskByPackage might fail unless the launcher exposes it perfectly.
                val dismissed = dismissTaskByPackage(root, targetPkg, ownPkg)
                root.recycle()
                if (!dismissed) swipeCardAway()
            } else {
                swipeCardAway()
            }
        }, 800)
    }

    private fun dismissTaskByPackage(
        node: AccessibilityNodeInfo,
        targetPkg: String?,
        ownPkg: String,
    ): Boolean {
        val nodePkg = node.packageName?.toString() ?: ""

        // Never touch our own process
        if (nodePkg == ownPkg) {
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                val found = dismissTaskByPackage(child, targetPkg, ownPkg)
                child.recycle()
                if (found) return true
            }
            return false
        }

        val supportsDismiss = node.isVisibleToUser &&
                node.actionList.any { it.id == AccessibilityNodeInfo.ACTION_DISMISS }

        if (supportsDismiss) {
            // Note: nodePkg is likely the launcher, so checking targetPkg here often fails.
            // But we keep it as a safe guard if the launcher happens to use realistic packages.
            val isTarget = targetPkg == null || nodePkg == targetPkg
            if (isTarget) {
                Log.d(TAG, "Dismissing task card: pkg=$nodePkg")
                return node.performAction(AccessibilityNodeInfo.ACTION_DISMISS)
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = dismissTaskByPackage(child, targetPkg, ownPkg)
            child.recycle()
            if (found) return true
        }
        return false
    }

    /// Gesture fallback: 
    /// 1. Swipe LEFT (to drag the latest app card from the right side into the center)
    /// 2. Wait for settling animation.
    /// 3. Swipe UP to dismiss it.
    private fun swipeCardAway() {
        val m = resources.displayMetrics
        
        // 1. Swipe Left (Right-to-Left drag)
        val swipeLeftPath = Path().also {
            it.moveTo(m.widthPixels * 0.9f, m.heightPixels * 0.5f)    // Start right
            it.lineTo(m.widthPixels * 0.1f, m.heightPixels * 0.5f)    // Drag left
        }
        val swipeLeft = GestureDescription.StrokeDescription(swipeLeftPath, 0, 350)
        
        dispatchGesture(
            GestureDescription.Builder().addStroke(swipeLeft).build(),
            object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    // Wait for the scrolling carousel to stop sliding
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        // 2. Swipe Up
                        val swipeUpPath = Path().also {
                            it.moveTo(m.widthPixels * 0.5f, m.heightPixels * 0.6f)
                            it.lineTo(m.widthPixels * 0.5f, m.heightPixels * 0.05f)
                        }
                        val swipeUp = GestureDescription.StrokeDescription(swipeUpPath, 0, 300)
                        
                        dispatchGesture(
                            GestureDescription.Builder().addStroke(swipeUp).build(),
                            null, null
                        )
                    }, 400)
                }
            },
            null
        )
    }

    // ── Screen reading ────────────────────────────────────────────────────────

    /// Returns a compact, token-efficient snapshot of what's visible on screen.
    fun getScreenContent(): String {
        val root = rootInActiveWindow ?: return "[screen not accessible]"
        return try {
            buildString {
                // Window title
                windows?.firstOrNull()?.title?.toString()
                    ?.takeIf { it.isNotBlank() }
                    ?.let { append("Window: $it\n") }
                // Node tree (max 60 entries to stay within model token budget)
                val nodes = mutableListOf<String>()
                collectNodes(root, nodes, limit = 60)
                nodes.forEach { append(it).append('\n') }
            }.trim()
        } finally {
            root.recycle()
        }
    }

    private fun collectNodes(
        node: AccessibilityNodeInfo,
        out: MutableList<String>,
        limit: Int,
    ) {
        if (out.size >= limit) return
        // NOTE: do NOT recycle `node` here — the caller owns its lifecycle.
        // Only children obtained via getChild() are ours to recycle.
        if (!node.isVisibleToUser) return

        val text  = node.text?.toString()?.trim()
        val desc  = node.contentDescription?.toString()?.trim()
        val label = text?.takeIf { it.isNotBlank() } ?: desc?.takeIf { it.isNotBlank() }

        if (!label.isNullOrBlank() && label.length > 1) {
            val type = when {
                node.isEditable  -> "input"
                node.isClickable -> "button"
                node.isFocusable -> "link"
                else             -> "text"
            }
            out.add("[$type] $label")
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectNodes(child, out, limit)  // child ownership passes in
            child.recycle()                 // we recycle after we're done
        }
    }

    // ── Click by label ────────────────────────────────────────────────────────

    /// Fuzzy-finds the first visible, clickable node whose text/desc contains
    /// [label] (case-insensitive) and clicks it. Returns true on success.
    fun clickByLabel(label: String): Boolean {
        val root = rootInActiveWindow ?: return false
        return try {
            findAndClick(root, label.lowercase().trim())
        } finally {
            root.recycle()
        }
    }

    private fun findAndClick(node: AccessibilityNodeInfo, label: String): Boolean {
        if (node.isVisibleToUser) {
            val text = node.text?.toString()?.lowercase() ?: ""
            val desc = node.contentDescription?.toString()?.lowercase() ?: ""
            if ((text.contains(label) || desc.contains(label)) && node.isEnabled) {
                // Walk up to find a clickable ancestor if this node isn't clickable
                if (node.isClickable) {
                    return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                }
            }
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findAndClick(child, label)
            child.recycle()
            if (found) return true
        }
        return false
    }

    companion object {
        private const val TAG = "VoiceControlService"
        var instance: PhoneControlAccessibilityService? = null
        
        @JvmStatic
        var mediaProjection: MediaProjection? = null
    }
}
