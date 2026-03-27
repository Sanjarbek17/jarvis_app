import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'log_service.dart';
import 'package:flutter/foundation.dart';

class ModelService {
  static final ModelService _instance = ModelService._internal();
  factory ModelService() => _instance;
  ModelService._internal();

  // Qwen 2.5 0.5B Instruct LiteRT model URL
  static const String modelUrl = "https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_seq128_q8_ekv1280.tflite";
  static const String modelFileName = "qwen2.5-0.5b-instruct.tflite";

  final ValueNotifier<double> downloadProgress = ValueNotifier<double>(0);
  final ValueNotifier<bool> isBusy = ValueNotifier<bool>(false);
  final ValueNotifier<String> status = ValueNotifier<String>("Idle");
  
  String? _customModelPath;
  static const String _customPathKey = "custom_model_path";

  Future<String?> getModelPath() async {
    // 1. Check if custom path is set and valid
    if (_customModelPath == null) {
      final prefs = await SharedPreferences.getInstance();
      _customModelPath = prefs.getString(_customPathKey);
    }

    if (_customModelPath != null) {
      final file = File(_customModelPath!);
      if (await file.exists()) {
        return _customModelPath;
      } else {
        // Clear if file no longer exists
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_customPathKey);
        _customModelPath = null;
      }
    }

    // 2. Check for default downloaded model
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/$modelFileName";
    final file = File(path);
    if (await file.exists()) {
      return path;
    }
    return null;
  }

  Future<void> pickModelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['tflite', 'bin'],
      );

      if (result != null && result.files.single.path != null) {
        _customModelPath = result.files.single.path;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_customPathKey, _customModelPath!);
        status.value = "Custom Model Selected";
        logger.log("Selected local model: ${result.files.single.name}");
      }
    } catch (e) {
      logger.log("Picker error: $e");
    }
  }

  Future<void> clearCustomModel() async {
    _customModelPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customPathKey);
    status.value = "Custom Model Cleared";
    logger.log("Custom model cleared.");
  }

  Future<String?> downloadModel() async {
    try {
      isBusy.value = true;
      status.value = "Downloading Model...";
      logger.log("Starting model download (~300MB)...");

      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/$modelFileName";
      
      final dio = Dio();
      await dio.download(
        modelUrl,
        path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadProgress.value = received / total;
            final percent = (downloadProgress.value * 100).toStringAsFixed(1);
            if (received % (10 * 1024 * 1024) < 1024 * 1024) { // Log every ~10MB
               logger.log("Download progress: $percent%");
            }
          }
        },
      );

      logger.log("Model download complete!");
      status.value = "Downloaded";
      isBusy.value = false;
      return path;
    } catch (e) {
      logger.log("Download error: $e");
      status.value = "Download Failed";
      isBusy.value = false;
      return null;
    }
  }

  Future<bool> isModelReady() async {
    final path = await getModelPath();
    return path != null;
  }
}

final modelService = ModelService();
