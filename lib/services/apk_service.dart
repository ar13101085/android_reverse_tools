import 'dart:io';
import '../utils/config_manager.dart';
import 'command_executor.dart';

class ApkService {
  static ApkService create() {
    return ApkService._();
  }
  
  ApkService._();

  Future<ProcessResult> decompileApk(String apkPath, String outputDir) async {
    final arguments = ['d', apkPath, '-o', outputDir];
    return await CommandExecutor.executeJarCommand(ConfigManager.apkToolPath, arguments);
  }

  Future<ProcessResult> buildApk(String inputDir, String outputApkPath) async {
    final arguments = ['b', inputDir, '-o', outputApkPath];
    return await CommandExecutor.executeJarCommand(ConfigManager.apkToolPath, arguments);
  }

  Future<ProcessResult> signApk(String apkPath) async {
    final arguments = ['-a', apkPath];
    return await CommandExecutor.executeJarCommand(ConfigManager.uberApkSignerPath, arguments);
  }

  Future<ProcessResult> signApkWithKeystore(
    String apkPath,
    String keystorePath,
    String keystorePassword,
    String keyAlias,
    String keyPassword,
  ) async {
    // Use uber-apk-signer with custom keystore
    final arguments = [
      '-a', apkPath,
      '--ks', keystorePath,
      '--ksPass', keystorePassword,
      '--ksAlias', keyAlias,
      '--ksKeyPass', keyPassword,
      '--overwrite',
    ];
    return await CommandExecutor.executeJarCommand(ConfigManager.uberApkSignerPath, arguments);
  }

  Future<ProcessResult> installApk(String apkPath) async {
    final arguments = ['install', '-r', '-d', apkPath];
    return await CommandExecutor.executeCommand(ConfigManager.adbPath, arguments);
  }

  Future<ProcessResult> installApkOnDevice(String apkPath, String deviceId) async {
    final arguments = ['-s', deviceId, 'install', '-r', '-d', apkPath];
    return await CommandExecutor.executeCommand(ConfigManager.adbPath, arguments);
  }

  Future<ProcessResult> getConnectedDevices() async {
    final arguments = ['devices'];
    return await CommandExecutor.executeCommand(ConfigManager.adbPath, arguments);
  }

  Future<void> openWithJadx(String apkPath) async {
    await CommandExecutor.executeJarCommand(ConfigManager.jadxGuiPath, [apkPath]);
  }

  Future<void> openWithJDGui(String apkPath) async {
    await CommandExecutor.executeJarCommand(ConfigManager.jdGuiPath, [apkPath]);
  }

  Future<void> openWithVSCode(String path) async {
    await CommandExecutor.executeCommand(ConfigManager.vscodePath, ['-r', path]);
  }

  Future<ProcessResult> enableDebugMode(String manifestPath) async {
    try {
      final file = File(manifestPath);
      if (!await file.exists()) {
        return ProcessResult(0, 1, '', 'AndroidManifest.xml not found');
      }

      String content = await file.readAsString();
      
      if (!content.contains('android:debuggable')) {
        content = content.replaceFirst(
          '<application',
          '<application\n        android:debuggable="true"'
        );
        await file.writeAsString(content);
      }

      return ProcessResult(0, 0, 'Debug mode enabled', '');
    } catch (e) {
      return ProcessResult(0, 1, '', 'Error enabling debug mode: $e');
    }
  }

  Future<ProcessResult> injectFridaGadget(String apkDir) async {
    try {
      // This is a simplified version - actual implementation would be more complex
      final libDir = Directory('$apkDir/lib');
      if (!await libDir.exists()) {
        await libDir.create(recursive: true);
      }

      // Create architecture-specific directories
      final architectures = ['arm64-v8a', 'armeabi-v7a'];
      for (final arch in architectures) {
        final archDir = Directory('$apkDir/lib/$arch');
        if (!await archDir.exists()) {
          await archDir.create(recursive: true);
        }
      }

      return ProcessResult(0, 0, 'Frida gadget injection prepared', '');
    } catch (e) {
      return ProcessResult(0, 1, '', 'Error injecting Frida gadget: $e');
    }
  }

  Future<ProcessResult> configureMitm(String manifestPath) async {
    try {
      final file = File(manifestPath);
      if (!await file.exists()) {
        return ProcessResult(0, 1, '', 'AndroidManifest.xml not found');
      }

      String content = await file.readAsString();
      
      // Add network security config
      if (!content.contains('android:networkSecurityConfig')) {
        content = content.replaceFirst(
          '<application',
          '<application\n        android:networkSecurityConfig="@xml/network_security_config"'
        );
        await file.writeAsString(content);
      }

      return ProcessResult(0, 0, 'MITM configuration added', '');
    } catch (e) {
      return ProcessResult(0, 1, '', 'Error configuring MITM: $e');
    }
  }
}