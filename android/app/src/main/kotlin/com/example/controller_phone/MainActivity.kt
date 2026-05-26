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
}
