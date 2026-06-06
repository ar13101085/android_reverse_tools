import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'tool_setup.dart';
import 'file_access_manager.dart';
import '../widgets/console_output.dart';

class ConfigManager {
  static bool _isInitialized = false;
  static String? _lastFoundEnvPath;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize dotenv first (required even for manual loading).
      dotenv.testLoad(fileInput: '');

      // Resolve the .env path next to the executable (see _resolveEnvPath).
      final envPath = await _resolveEnvPath();

      if (await File(envPath).exists()) {
        await _loadEnvFromFile(envPath);
        ConsoleLogger.log('ConfigManager: Loaded .env from: $envPath');
        ConsoleLogger.log('ConfigManager: Loaded keys: ${dotenv.env.keys.toList()}');
      } else {
        // No config yet: create a default file at the resolved location.
        await _writeDefaultEnvFile(envPath);
        await _loadEnvFromFile(envPath);
        ConsoleLogger.log('ConfigManager: Created and loaded default .env at: $envPath');
      }
      _isInitialized = true;
    } catch (e) {
      ConsoleLogger.log('ConfigManager: Error loading .env file: $e');
      // Continue with default values if .env file cannot be loaded.
      _isInitialized = true;
    }

    // Initialize file access manager
    await FileAccessManager.initialize();

    // Initialize tools after config
    await ToolSetup.initializeTools();
  }

  /// Directory the running executable lives in, normalized so the `.env`
  /// sits in a stable, user-visible, writable spot on every desktop OS.
  ///
  /// macOS: `Platform.resolvedExecutable` points inside the code-signed
  /// bundle (`.../MyApp.app/Contents/MacOS/MyApp`). Writing there would
  /// break the signature, so we step out to the folder that CONTAINS the
  /// `.app` — i.e. right beside the app icon the user double-clicks.
  /// Windows/Linux: the folder that holds the executable itself.
  static String _executableDir() {
    final exeDir = File(Platform.resolvedExecutable).parent;
    if (Platform.isMacOS) {
      final macSuffix =
          '${path.separator}Contents${path.separator}MacOS';
      if (exeDir.path.endsWith(macSuffix)) {
        // .../MacOS -> .../Contents -> .../MyApp.app -> containing folder
        return exeDir.parent.parent.parent.path;
      }
    }
    return exeDir.path;
  }

  /// Probe whether we can actually create/write files in [dirPath].
  static Future<bool> _isDirWritable(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final probe = File(path.join(dirPath, '.env_write_test'));
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Single source of truth for where the `.env` lives.
  ///
  /// Priority:
  ///   1. Next to the executable (as requested) — if it already exists there
  ///      OR that directory is writable.
  ///   2. Application support directory — guaranteed-writable fallback so
  ///      saving config never fails, even on a read-only install medium.
  static Future<String> _resolveEnvPath() async {
    if (_lastFoundEnvPath != null) return _lastFoundEnvPath!;

    // 1. Beside the executable / .app bundle.
    try {
      final exeEnv = path.join(_executableDir(), '.env');
      if (await File(exeEnv).exists() ||
          await _isDirWritable(path.dirname(exeEnv))) {
        _lastFoundEnvPath = exeEnv;
        ConsoleLogger.log('ConfigManager: Using .env beside executable: $exeEnv');
        return exeEnv;
      }
    } catch (e) {
      ConsoleLogger.log('ConfigManager: Could not resolve executable dir: $e');
    }

    // 2. Writable fallback in the app support directory.
    final appSupportDir = await getApplicationSupportDirectory();
    final appConfigDir =
        Directory(path.join(appSupportDir.path, 'ar_mitm_frida'));
    if (!await appConfigDir.exists()) {
      await appConfigDir.create(recursive: true);
    }
    final fallback = path.join(appConfigDir.path, '.env');
    _lastFoundEnvPath = fallback;
    ConsoleLogger.log('ConfigManager: Using .env fallback location: $fallback');
    return fallback;
  }

  /// Read a `.env` file and merge its KEY=VALUE pairs into [dotenv.env].
  static Future<void> _loadEnvFromFile(String envPath) async {
    final contents = await File(envPath).readAsString();
    for (final line in contents.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      final key = line.substring(0, eq).trim();
      final value = line.substring(eq + 1).trim();
      dotenv.env[key] = value;
    }
  }

  static const String _defaultEnvContent = '''# Tools Directory
TOOLS_DIR=
# Keystore Configuration (optional)
KEYSTORE_PATH=
KEYSTORE_PASSWORD=
KEY_ALIAS=
KEY_PASSWORD=
''';

  static Future<void> _writeDefaultEnvFile(String envPath) async {
    try {
      await File(envPath).writeAsString(_defaultEnvContent);
      ConsoleLogger.log('ConfigManager: Created default .env file at: $envPath');
    } catch (e) {
      ConsoleLogger.log('ConfigManager: Error creating default .env file: $e');
    }
  }

  static void resetInitialization() {
    _isInitialized = false;
    _lastFoundEnvPath = null;
  }

  static Future<void> reloadEnv() async {
    try {
      // Ensure dotenv is initialized before touching env.
      try {
        final _ = dotenv.env;
      } catch (_) {
        dotenv.testLoad(fileInput: '');
      }

      // Clear and reload from the resolved location.
      dotenv.clean();

      final envPath = await _resolveEnvPath();
      if (await File(envPath).exists()) {
        await _loadEnvFromFile(envPath);
        ConsoleLogger.log('ConfigManager: Reloaded .env file from: $envPath');
        ConsoleLogger.log('  TOOLS_DIR: "${dotenv.env['TOOLS_DIR']}"');
        ConsoleLogger.log('  KEYSTORE_PATH: "${dotenv.env['KEYSTORE_PATH']}"');
        ConsoleLogger.log('  All env keys: ${dotenv.env.keys.toList()}');
      } else {
        ConsoleLogger.log('ConfigManager Warning: .env file not found during reload at: $envPath');
      }
    } catch (e) {
      ConsoleLogger.log('ConfigManager: Error reloading .env file: $e');
    }
  }

  /// The path where the `.env` file lives (next to the executable, or the
  /// writable fallback). Used by the settings dialog when saving config.
  static Future<String> get envFilePath async => _resolveEnvPath();
  
  // Raw getters without defaults (for settings dialog)
  static String get toolsDirRaw {
    try {
      return dotenv.env['TOOLS_DIR'] ?? '';
    } catch (e) {
      return '';
    }
  }
  
  static String get keystorePathRaw {
    try {
      return dotenv.env['KEYSTORE_PATH'] ?? '';
    } catch (e) {
      return '';
    }
  }
  
  static String get keystorePasswordRaw {
    try {
      return dotenv.env['KEYSTORE_PASSWORD'] ?? '';
    } catch (e) {
      return '';
    }
  }
  
  static String get keyAliasRaw {
    try {
      return dotenv.env['KEY_ALIAS'] ?? '';
    } catch (e) {
      return '';
    }
  }
  
  static String get keyPasswordRaw {
    try {
      return dotenv.env['KEY_PASSWORD'] ?? '';
    } catch (e) {
      return '';
    }
  }
  
  // Tools Directory Configuration (with defaults for operations)
  static String get toolsDir {
    try {
      return dotenv.env['TOOLS_DIR'] ?? '';
    } catch (e) {
      return '';
    }
  }
  
  // APK Tool Configuration
  static String get apkToolPath {
    // With sandbox disabled, use tools directly from configured directory
    return '$toolsDir/apktool.jar';
  }
  
  // APK Signing Tools
  static String get uberApkSignerPath {
    // With sandbox disabled, use tools directly from configured directory
    return '$toolsDir/uber-apk-signer.jar';
  }
  
  // Decompiler Tools
  static String get jadxGuiPath => '$toolsDir/jadx-gui.jar';
  static String get jdGuiPath => '$toolsDir/jd-gui.jar';
  
  // Android SDK Tools
  static String get adbPath => 'adb';
  static String get aaptPath => 'aapt';
  
  // IDE Integration
  static String get vscodePath => 'code';
  
  // Keystore Configuration
  static String get keystorePath {
    try {
      return dotenv.env['KEYSTORE_PATH'] ?? '';
    } catch (e) {
      return '';
    }
  }
  
  static String get keystorePassword {
    try {
      return dotenv.env['KEYSTORE_PASSWORD'] ?? '';
    } catch (e) {
      return '';
    }
  }
  
  static String get keyAlias {
    try {
      return dotenv.env['KEY_ALIAS'] ?? '';
    } catch (e) {
      return '';
    }
  }
  
  static String get keyPassword {
    try {
      return dotenv.env['KEY_PASSWORD'] ?? '';
    } catch (e) {
      return '';
    }
  }
  
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
        ConsoleLogger.log('ConfigManager Warning: Tool not found at $tool');
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
    
    ConsoleLogger.log('=== AR-MITM-FRIDA Configuration ===');
    ConsoleLogger.log('Tools Directory: $toolsDir');
    ConsoleLogger.log('APKTool Path: $apkToolPath');
    ConsoleLogger.log('APK Signer Path: $uberApkSignerPath');
    ConsoleLogger.log('JADX GUI Path: $jadxGuiPath');
    ConsoleLogger.log('JD-GUI Path: $jdGuiPath');
    ConsoleLogger.log('ADB Path: $adbPath');
    ConsoleLogger.log('VSCode Path: $vscodePath');
    ConsoleLogger.log('Debug Mode: $isDebugMode');
    ConsoleLogger.log('Log Level: $logLevel');
    ConsoleLogger.log('====================================');
  }
}