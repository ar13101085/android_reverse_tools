import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart' as xml;
import '../utils/config_manager.dart';
import 'command_executor.dart';

class ApkModifier {
  final String decompiledPath;
  final Function(String) onProgress;
  
  ApkModifier({
    required this.decompiledPath,
    required this.onProgress,
  });

  // Check if tweaks are already applied
  Future<Map<String, bool>> checkAppliedTweaks() async {
    return {
      'debugMode': await isDebugModeEnabled(),
      'fridaGadget': await isFridaGadgetInjected(),
      'mitm': await isMitmConfigured(),
      'signatureBypass': false, // Cannot easily detect
      'sslBypass': false, // Not implemented yet
    };
  }

  // Enable Debug Mode
  Future<bool> enableDebugMode() async {
    try {
      onProgress('Enabling debug mode...');
      
      final manifestPath = path.join(decompiledPath, 'AndroidManifest.xml');
      final manifestFile = File(manifestPath);
      
      if (!await manifestFile.exists()) {
        throw Exception('AndroidManifest.xml not found');
      }
      
      String manifestContent = await manifestFile.readAsString();
      final document = xml.XmlDocument.parse(manifestContent);
      
      // Find application element
      final applicationElements = document.findAllElements('application');
      if (applicationElements.isEmpty) {
        throw Exception('No application element found in manifest');
      }
      
      final applicationElement = applicationElements.first;
      
      // Add android:debuggable="true"
      applicationElement.setAttribute('android:debuggable', 'true');
      
      // Write back to file
      await manifestFile.writeAsString(document.toXmlString(pretty: true));
      
      onProgress('Debug mode enabled successfully');
      return true;
    } catch (e) {
      onProgress('Error enabling debug mode: $e');
      return false;
    }
  }

  // Inject Frida Gadget
  Future<bool> injectFridaGadget() async {
    try {
      onProgress('Injecting Frida gadget...');
      
      // Find entry class
      final entryClass = await _findEntryClass();
      if (entryClass == null) {
        throw Exception('Could not find entry class');
      }
      
      onProgress('Found entry class: $entryClass');
      
      // Inject smali code
      final injected = await _injectFridaSmaliCode(entryClass);
      if (!injected) {
        throw Exception('Failed to inject smali code');
      }
      
      // Copy Frida libraries
      final libsCopied = await _copyFridaLibraries();
      if (!libsCopied) {
        throw Exception('Failed to copy Frida libraries');
      }
      
      onProgress('Frida gadget injected successfully');
      return true;
    } catch (e) {
      onProgress('Error injecting Frida gadget: $e');
      return false;
    }
  }

  // Enable MITM
  Future<bool> enableMitm() async {
    try {
      onProgress('Configuring MITM...');
      
      // Add network security config to manifest
      final manifestPath = path.join(decompiledPath, 'AndroidManifest.xml');
      final manifestFile = File(manifestPath);
      
      if (!await manifestFile.exists()) {
        throw Exception('AndroidManifest.xml not found');
      }
      
      String manifestContent = await manifestFile.readAsString();
      final document = xml.XmlDocument.parse(manifestContent);
      
      // Find application element
      final applicationElements = document.findAllElements('application');
      if (applicationElements.isEmpty) {
        throw Exception('No application element found in manifest');
      }
      
      final applicationElement = applicationElements.first;
      
      // Add networkSecurityConfig attribute
      applicationElement.setAttribute('android:networkSecurityConfig', '@xml/ar_net_config');
      
      // Write back manifest
      await manifestFile.writeAsString(document.toXmlString(pretty: true));
      
      // Create network security config file
      await _createNetworkSecurityConfig();
      
      onProgress('MITM configured successfully');
      return true;
    } catch (e) {
      onProgress('Error configuring MITM: $e');
      return false;
    }
  }

  // Signature Bypass
  Future<bool> applySignatureBypass() async {
    try {
      onProgress('Applying signature bypass...');
      
      // Check if nkstool exists
      final nkstoolPath = path.join(ConfigManager.toolsDir, 'SignatureBypass', 'nkstool.jar');
      final nkstoolFile = File(nkstoolPath);
      
      if (!await nkstoolFile.exists()) {
        onProgress('Warning: nkstool.jar not found, skipping signature bypass');
        return false;
      }
      
      // Get source APK path from decompiled directory
      final sourceApkPath = decompiledPath.replaceAll('_decompiled', '.apk');
      final outputApkPath = decompiledPath.replaceAll('_decompiled', '_bypass.apk');
      
      // Create config.txt in the SignatureBypass directory (where nkstool expects it)
      final signatureBypassDir = path.join(ConfigManager.toolsDir, 'SignatureBypass');
      final configPath = path.join(signatureBypassDir, 'config.txt');
      final configFile = File(configPath);
      
      final config = '''# APK Signature Bypass Configuration
# Source APK to get signature from
apk.signed=$sourceApkPath

# APK to process
apk.src=$sourceApkPath

# Output APK path
apk.out=$outputApkPath

# Signing configuration
sign.enable=true
sign.file=test.keystore
sign.password=123456
sign.alias=user
sign.aliasPassword=654321
''';
      
      await configFile.writeAsString(config);
      
      onProgress('Warning: nkstool.jar is incompatible with Java 24+');
      onProgress('Signature bypass tool requires Java 8 or older to work properly');
      onProgress('Consider using an alternative signature bypass method or installing Java 8');
      onProgress('You can use Frida-based signature bypass at runtime instead');
      
      // Try to run anyway, but expect it to fail
      final result = await Process.run(
        'java',
        [
          '--add-opens', 'java.base/sun.security.pkcs=ALL-UNNAMED',
          '--add-opens', 'java.base/sun.security.util=ALL-UNNAMED',
          '--add-opens', 'java.base/sun.security.x509=ALL-UNNAMED',
          '-jar', 'nkstool.jar'
        ],
        workingDirectory: signatureBypassDir,
      );
      
      if (result.exitCode == 0) {
        onProgress('Signature bypass applied successfully');
        onProgress('Output APK: $outputApkPath');
        return true;
      } else {
        onProgress('Signature bypass failed due to Java version incompatibility');
        onProgress('Tool output: ${result.stdout}');
        onProgress('Error: ${result.stderr}');
        onProgress('');
        onProgress('Alternative solutions:');
        onProgress('1. Install Java 8 and use it specifically for signature bypass');
        onProgress('2. Use Frida-based runtime signature bypass instead');
        onProgress('3. Use a different signature bypass tool compatible with newer Java');
        return false;
      }
    } catch (e) {
      onProgress('Error applying signature bypass: $e');
      return false;
    }
  }

  // SSL Bypass (placeholder - not implemented in original)
  Future<bool> applySslBypass() async {
    onProgress('SSL bypass not implemented yet');
    return false;
  }

  // Check if debug mode is enabled
  Future<bool> isDebugModeEnabled() async {
    try {
      final manifestPath = path.join(decompiledPath, 'AndroidManifest.xml');
      final manifestFile = File(manifestPath);
      
      if (!await manifestFile.exists()) {
        return false;
      }
      
      final manifestContent = await manifestFile.readAsString();
      return manifestContent.contains('android:debuggable="true"');
    } catch (e) {
      return false;
    }
  }

  // Check if Frida gadget is injected
  Future<bool> isFridaGadgetInjected() async {
    try {
      // Check if Frida libraries exist
      final libPaths = [
        path.join(decompiledPath, 'lib', 'armeabi-v7a', 'libfrida-gadget.so'),
        path.join(decompiledPath, 'lib', 'arm64-v8a', 'libfrida-gadget.so'),
      ];
      
      for (final libPath in libPaths) {
        if (await File(libPath).exists()) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  // Check if MITM is configured
  Future<bool> isMitmConfigured() async {
    try {
      final manifestPath = path.join(decompiledPath, 'AndroidManifest.xml');
      final manifestFile = File(manifestPath);
      
      if (!await manifestFile.exists()) {
        return false;
      }
      
      final manifestContent = await manifestFile.readAsString();
      return manifestContent.contains('android:networkSecurityConfig="@xml/ar_net_config"');
    } catch (e) {
      return false;
    }
  }

  // Private helper methods
  Future<String?> _findEntryClass() async {
    try {
      final manifestPath = path.join(decompiledPath, 'AndroidManifest.xml');
      final manifestFile = File(manifestPath);
      
      if (!await manifestFile.exists()) {
        return null;
      }
      
      final manifestContent = await manifestFile.readAsString();
      final document = xml.XmlDocument.parse(manifestContent);
      
      // First try to find application class
      final applicationElements = document.findAllElements('application');
      if (applicationElements.isNotEmpty) {
        final appElement = applicationElements.first;
        final appName = appElement.getAttribute('android:name');
        if (appName != null && appName.isNotEmpty) {
          return appName.replaceAll('.', '/');
        }
      }
      
      // If no application class, find main launcher activity
      final activities = document.findAllElements('activity');
      for (final activity in activities) {
        final intentFilters = activity.findAllElements('intent-filter');
        for (final filter in intentFilters) {
          final hasMainAction = filter.findAllElements('action').any(
            (action) => action.getAttribute('android:name') == 'android.intent.action.MAIN'
          );
          final hasLauncherCategory = filter.findAllElements('category').any(
            (category) => category.getAttribute('android:name') == 'android.intent.category.LAUNCHER'
          );
          
          if (hasMainAction && hasLauncherCategory) {
            final activityName = activity.getAttribute('android:name');
            if (activityName != null) {
              return activityName.replaceAll('.', '/');
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> _injectFridaSmaliCode(String className) async {
    try {
      // Convert class name to smali file path
      final smaliPath = path.join(decompiledPath, 'smali', '$className.smali');
      final smaliFile = File(smaliPath);
      
      if (!await smaliFile.exists()) {
        // Try other smali directories
        for (int i = 1; i <= 5; i++) {
          final altPath = path.join(decompiledPath, 'smali_classes$i', '$className.smali');
          final altFile = File(altPath);
          if (await altFile.exists()) {
            smaliFile.path;
            break;
          }
        }
      }
      
      if (!await smaliFile.exists()) {
        onProgress('Smali file not found: $smaliPath');
        return false;
      }
      
      String smaliContent = await smaliFile.readAsString();
      
      // Check if already injected
      if (smaliContent.contains('frida-gadget')) {
        onProgress('Frida gadget already injected');
        return true;
      }
      
      // Find where to inject (after .super line)
      final lines = smaliContent.split('\n');
      int insertIndex = -1;
      
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('.super ')) {
          insertIndex = i + 1;
          break;
        }
      }
      
      if (insertIndex == -1) {
        return false;
      }
      
      // Inject static constructor
      final fridaCode = '''

# Frida gadget injection
.method static constructor <clinit>()V
    .locals 3
    
    const-string v2, "frida-gadget"
    invoke-static {v2}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V
    
    return-void
.end method
''';
      
      lines.insert(insertIndex, fridaCode);
      
      // Write back to file
      await smaliFile.writeAsString(lines.join('\n'));
      
      return true;
    } catch (e) {
      onProgress('Error injecting smali code: $e');
      return false;
    }
  }

  Future<bool> _copyFridaLibraries() async {
    try {
      // Frida library source paths
      final fridaLibs = {
        'armeabi-v7a': path.join(ConfigManager.toolsDir, 'frida', 'armeabi-v7a', 'libfrida-gadget.so'),
        'arm64-v8a': path.join(ConfigManager.toolsDir, 'frida', 'arm64-v8a', 'libfrida-gadget.so'),
      };
      
      for (final entry in fridaLibs.entries) {
        final arch = entry.key;
        final sourcePath = entry.value;
        
        final sourceFile = File(sourcePath);
        if (!await sourceFile.exists()) {
          onProgress('Warning: Frida library not found: $sourcePath');
          continue;
        }
        
        // Create target directory
        final targetDir = Directory(path.join(decompiledPath, 'lib', arch));
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        
        // Copy library
        final targetPath = path.join(targetDir.path, 'libfrida-gadget.so');
        await sourceFile.copy(targetPath);
        
        onProgress('Copied Frida library for $arch');
      }
      
      return true;
    } catch (e) {
      onProgress('Error copying Frida libraries: $e');
      return false;
    }
  }

  Future<void> _createNetworkSecurityConfig() async {
    try {
      // Create res/xml directory if it doesn't exist
      final xmlDir = Directory(path.join(decompiledPath, 'res', 'xml'));
      if (!await xmlDir.exists()) {
        await xmlDir.create(recursive: true);
      }
      
      // Create network security config
      final configPath = path.join(xmlDir.path, 'ar_net_config.xml');
      final configFile = File(configPath);
      
      final configContent = '''<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </base-config>
</network-security-config>''';
      
      await configFile.writeAsString(configContent);
      
      onProgress('Created network security config');
    } catch (e) {
      onProgress('Error creating network security config: $e');
      throw e;
    }
  }
}