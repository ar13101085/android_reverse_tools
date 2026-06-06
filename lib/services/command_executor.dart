import 'dart:io';
import 'dart:convert';

class CommandExecutor {
  static Future<ProcessResult> executeCommand(String command, List<String> arguments) async {
    try {
      // Use the system environment and explicitly set PATH
      final environment = Map<String, String>.from(Platform.environment);
      
      // Ensure Java and Android SDK are in PATH
      final paths = <String>[];
      
      // Add common system paths
      paths.addAll([
        '/usr/bin',
        '/usr/local/bin',
        '/opt/homebrew/bin',
      ]);
      
      // Add Java paths for macOS
      if (Platform.isMacOS) {
        paths.add('/System/Library/Frameworks/JavaVM.framework/Versions/Current/Commands');
      }
      
      // Add Android SDK paths if ANDROID_HOME is set
      String? androidHome = environment['ANDROID_HOME'] ?? 
                           environment['ANDROID_SDK_ROOT'];
      
      // If no Android SDK environment variable is set, try common locations
      if (androidHome == null || androidHome.isEmpty) {
        if (Platform.isMacOS) {
          // Try common macOS locations
          final possiblePaths = [
            '${environment['HOME']}/Library/Android/sdk',
            '/usr/local/share/android-sdk',
            '/opt/android-sdk',
          ];
          for (final path in possiblePaths) {
            if (Directory(path).existsSync()) {
              androidHome = path;
              break;
            }
          }
        } else if (Platform.isLinux) {
          // Try common Linux locations
          final possiblePaths = [
            '${environment['HOME']}/Android/Sdk',
            '/usr/local/android-sdk',
            '/opt/android-sdk',
          ];
          for (final path in possiblePaths) {
            if (Directory(path).existsSync()) {
              androidHome = path;
              break;
            }
          }
        } else if (Platform.isWindows) {
          // Try common Windows locations
          final possiblePaths = [
            '${environment['LOCALAPPDATA']}\\Android\\Sdk',
            '${environment['PROGRAMFILES']}\\Android\\android-sdk',
            'C:\\android-sdk',
          ];
          for (final path in possiblePaths) {
            if (Directory(path).existsSync()) {
              androidHome = path;
              break;
            }
          }
        }
      }
      
      // Only add Android SDK paths if we found it
      if (androidHome != null && androidHome.isNotEmpty) {
        paths.add('$androidHome/platform-tools');
        paths.add('$androidHome/tools');
        paths.add('$androidHome/tools/bin');
        
        // Check for build-tools and add the latest version
        final buildToolsDir = Directory('$androidHome/build-tools');
        if (buildToolsDir.existsSync()) {
          final versions = buildToolsDir.listSync()
              .whereType<Directory>()
              .map((dir) => dir.path.split('/').last)
              .toList()
            ..sort();
          if (versions.isNotEmpty) {
            paths.add('$androidHome/build-tools/${versions.last}');
          }
        }
      }
      
      // Add existing PATH
      paths.add(environment['PATH'] ?? '');
      
      environment['PATH'] = paths.join(':');
      
      final result = await Process.run(
        command, 
        arguments,
        environment: environment,
        workingDirectory: null,
        runInShell: true,
      );
      return result;
    } catch (e) {
      return ProcessResult(0, 1, '', 'Error executing command: $e');
    }
  }

  static Future<ProcessResult> executeJarCommand(String jarPath, List<String> arguments) async {
    final allArgs = ['-jar', jarPath] + arguments;
    return await executeCommand('java', allArgs);
  }

  static Future<ProcessResult> executeApkTool(String apkToolPath, List<String> arguments) async {
    return await executeJarCommand(apkToolPath, arguments);
  }

  static Future<ProcessResult> executeAdbCommand(List<String> arguments) async {
    return await executeCommand('adb', arguments);
  }

  static Future<Stream<String>> executeCommandStream(String command, List<String> arguments) async {
    final process = await Process.start(command, arguments);
    return process.stdout.transform(utf8.decoder);
  }

  static Future<void> openFileExplorer(String path) async {
    if (Platform.isMacOS) {
      await executeCommand('open', [path]);
    } else if (Platform.isWindows) {
      await executeCommand('explorer', [path]);
    } else if (Platform.isLinux) {
      await executeCommand('xdg-open', [path]);
    }
  }

  static Future<void> openWithVSCode(String path) async {
    await executeCommand('code', ['-r', path]);
  }

  static Future<void> openWithJDGUI(String jdGuiPath, String apkPath) async {
    await executeJarCommand(jdGuiPath, [apkPath]);
  }
}