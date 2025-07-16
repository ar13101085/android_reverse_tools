import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'tool_setup.dart';

class ConfigManager {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await dotenv.load(fileName: '.env');
      _isInitialized = true;
    } catch (e) {
      print('Error loading .env file: $e');
      // Continue with default values if .env file is not found
      _isInitialized = true;
    }
    
    // Initialize tools after config
    await ToolSetup.initializeTools();
  }

  // Tools Directory Configuration
  static String get toolsDir => dotenv.env['TOOLS_DIR'] ?? '/usr/local/bin/android-tools';
  
  // APK Tool Configuration
  static String get apkToolPath {
    // Use app-local tool if available
    try {
      return ToolSetup.getToolPath('apktool.jar');
    } catch (e) {
      // Always construct from tools directory
      return '${toolsDir}/apktool.jar';
    }
  }
  
  // APK Signing Tools
  static String get uberApkSignerPath {
    // Use app-local tool if available
    try {
      return ToolSetup.getToolPath('uber-apk-signer.jar');
    } catch (e) {
      // Always construct from tools directory
      return '${toolsDir}/uber-apk-signer.jar';
    }
  }
  
  // Decompiler Tools
  static String get jadxGuiPath => '${toolsDir}/jadx-gui.jar';
  static String get jdGuiPath => '${toolsDir}/jd-gui.jar';
  
  // Android SDK Tools
  static String get adbPath => 'adb';
  static String get aaptPath => 'aapt';
  
  // IDE Integration
  static String get vscodePath => 'code';
  
  // Keystore Configuration
  static String get keystorePath => dotenv.env['KEYSTORE_PATH'] ?? '';
  static String get keystorePassword => dotenv.env['KEYSTORE_PASSWORD'] ?? '';
  static String get keyAlias => dotenv.env['KEY_ALIAS'] ?? '';
  static String get keyPassword => dotenv.env['KEY_PASSWORD'] ?? '';
  
  // Working Directory
  static Future<String> get workDir async {
    // Always use app documents directory
    final documentsDir = await getApplicationDocumentsDirectory();
    return '${documentsDir.path}/ar_mitm_frida';
  }
  
  // Debug Configuration
  static bool get isDebugMode => true;
  static String get logLevel => 'info';

  // Utility Methods
  static Future<bool> validateToolsExist() async {
    final tools = [
      apkToolPath,
      uberApkSignerPath,
      jadxGuiPath,
      jdGuiPath,
    ];

    for (final tool in tools) {
      if (tool.isNotEmpty && !await File(tool).exists()) {
        print('Warning: Tool not found at $tool');
      }
    }

    return true;
  }

  static Future<void> createWorkingDirectory() async {
    final workingDir = await workDir;
    final directory = Directory(workingDir);
    
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  static Map<String, String> getAllConfig() {
    return {
      'toolsDir': toolsDir,
      'apkToolPath': apkToolPath,
      'uberApkSignerPath': uberApkSignerPath,
      'jadxGuiPath': jadxGuiPath,
      'jdGuiPath': jdGuiPath,
      'adbPath': adbPath,
      'aaptPath': aaptPath,
      'vscodePath': vscodePath,
      'keystorePath': keystorePath,
      'keyAlias': keyAlias,
      'isDebugMode': isDebugMode.toString(),
      'logLevel': logLevel,
    };
  }

  static void printConfig() {
    if (!isDebugMode) return;
    
    print('=== AR-MITM-FRIDA Configuration ===');
    print('Tools Directory: $toolsDir');
    print('APKTool Path: $apkToolPath');
    print('APK Signer Path: $uberApkSignerPath');
    print('JADX GUI Path: $jadxGuiPath');
    print('JD-GUI Path: $jdGuiPath');
    print('ADB Path: $adbPath');
    print('VSCode Path: $vscodePath');
    print('Debug Mode: $isDebugMode');
    print('Log Level: $logLevel');
    print('====================================');
  }
}