import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/apk_info.dart';
import '../utils/config_manager.dart';
import '../utils/file_access_manager.dart';
import 'command_executor.dart';

class ApkAnalyzer {
  static Future<ApkAnalyzer> create() async {
    return ApkAnalyzer._();
  }
  
  String? _decompiledDirectory;
  
  ApkAnalyzer._();

  String? get decompiledDirectory => _decompiledDirectory;

  Future<ApkInfo> analyzeApk(String apkPath, Function(String) onProgress, {bool freshExtraction = false}) async {
    try {
      onProgress('Starting APK analysis...');
      
      // Create decompiled directory in the same location as APK
      final decompiledDir = await _createDecompiledDirectory(apkPath, freshExtraction: freshExtraction);
      _decompiledDirectory = decompiledDir;
      
      // Check if directory already has decompiled content
      final manifestFile = File(path.join(decompiledDir, 'AndroidManifest.xml'));
      final apktoolYml = File(path.join(decompiledDir, 'apktool.yml'));
      
      if (!freshExtraction && await manifestFile.exists() && await apktoolYml.exists()) {
        onProgress('Using existing decompiled directory: $decompiledDir');
        onProgress('Skipping decompilation - APK already decompiled');
      } else {
        onProgress('Created decompiled directory: $decompiledDir');
        // Decompile APK
        await _decompileApk(apkPath, decompiledDir, onProgress);
      }
      
      // Extract APK information
      final apkInfo = await _extractApkInfo(decompiledDir, onProgress);
      
      onProgress('APK analysis completed successfully!');
      return apkInfo;
      
    } catch (e) {
      onProgress('Error during APK analysis: $e');
      return ApkInfo.empty();
    }
  }

  Future<String> _createDecompiledDirectory(String apkPath, {bool freshExtraction = false}) async {
    final apkName = path.basenameWithoutExtension(apkPath);
    final apkDir = path.dirname(apkPath);
    
    // Try to create in the same directory as the APK first
    String decompiledDir = path.join(apkDir, '${apkName}_decompiled');
    Directory directory = Directory(decompiledDir);
    
    try {
      if (await directory.exists()) {
        if (freshExtraction) {
          await directory.delete(recursive: true);
          await directory.create(recursive: true);
        }
        // If not fresh extraction, use existing directory
        return decompiledDir;
      }
      await directory.create(recursive: true);
      return decompiledDir;
    } catch (e) {
      // If that fails (permissions), use the app's working directory
      final workDir = await ConfigManager.workDir;
      decompiledDir = path.join(workDir, '${apkName}_decompiled');
      directory = Directory(decompiledDir);
      
      if (await directory.exists()) {
        if (freshExtraction) {
          await directory.delete(recursive: true);
          await directory.create(recursive: true);
        }
        // If not fresh extraction, use existing directory
        return decompiledDir;
      }
      
      await directory.create(recursive: true);
      return decompiledDir;
    }
  }

  Future<void> _decompileApk(String apkPath, String outputDir, Function(String) onProgress) async {
    onProgress('Decompiling APK with APKTool...');
    onProgress('APKTool path: ${ConfigManager.apkToolPath}');
    
    // Check if APKTool exists in app directory first
    var apkToolPath = ConfigManager.apkToolPath;
    final apkToolFile = File(apkToolPath);
    var toolExists = await apkToolFile.exists();
    
    if (!toolExists) {
      onProgress('APKTool not found in app directory, checking configured directory...');
      
      // Check if we have access to the tools directory
      if (!FileAccessManager.hasAccess(apkToolPath)) {
        onProgress('Requesting access to tools directory...');
        
        // Request access to tools directory
        final granted = await FileAccessManager.requestDirectoryAccess('tools-directory');
        
        if (!granted) {
          throw Exception('Access denied to tools directory. Please grant access to use APKTool.');
        }
      }
      
      // Check again after access grant
      toolExists = await apkToolFile.exists();
      if (!toolExists) {
        // Try to copy the tool to app directory
        onProgress('Attempting to copy APKTool to app directory...');
        final appToolsDir = await _getAppToolsDirectory();
        final destPath = path.join(appToolsDir, 'apktool.jar');
        
        final copied = await FileAccessManager.copyFileWithAccess(
          apkToolPath,
          destPath,
        );
        
        if (copied) {
          apkToolPath = destPath;
          onProgress('APKTool copied to app directory');
        } else {
          throw Exception('APKTool not found and could not be copied');
        }
      }
    }
    
    onProgress('APKTool file exists: true');
    onProgress('APKTool file size: ${(await File(apkToolPath).stat()).size} bytes');
    
    // Try alternative execution method using Process.start
    try {
      final arguments = ['d', apkPath, '-o', outputDir, '-f'];
      onProgress('Executing: java -jar $apkToolPath ${arguments.join(' ')}');
      
      // First try the original method
      final result = await CommandExecutor.executeJarCommand(apkToolPath, arguments);
      
      if (result.exitCode != 0) {
        onProgress('Exit code: ${result.exitCode}');
        onProgress('stdout: ${result.stdout}');
        onProgress('stderr: ${result.stderr}');
        
        // Try alternative approach with full path
        onProgress('Trying alternative execution method...');
        final process = await Process.start(
          '/usr/bin/java',
          ['-jar', apkToolPath] + arguments,
          workingDirectory: null,
          runInShell: false,
        );
        
        final exitCode = await process.exitCode;
        final stdout = await process.stdout.transform(utf8.decoder).join();
        final stderr = await process.stderr.transform(utf8.decoder).join();
        
        onProgress('Alternative method exit code: $exitCode');
        if (exitCode != 0) {
          onProgress('Alternative stdout: $stdout');
          onProgress('Alternative stderr: $stderr');
          throw Exception('APKTool decompilation failed: $stderr');
        }
      }
      
      onProgress('APK decompiled successfully');
    } catch (e) {
      onProgress('Exception during decompilation: $e');
      rethrow;
    }
  }
  
  Future<String> _getAppToolsDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final toolsDir = path.join(documentsDir.path, 'tools');
    
    // Create directory if it doesn't exist
    final dir = Directory(toolsDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return toolsDir;
  }

  Future<ApkInfo> _extractApkInfo(String decompileDir, Function(String) onProgress) async {
    onProgress('Extracting APK information...');
    
    final manifestPath = path.join(decompileDir, 'AndroidManifest.xml');
    final manifestFile = File(manifestPath);
    
    if (!await manifestFile.exists()) {
      throw Exception('AndroidManifest.xml not found in decompiled APK');
    }
    
    final manifestContent = await manifestFile.readAsString();
    onProgress('Reading AndroidManifest.xml...');
    
    // Try to read apktool.yml for more reliable version info
    Map<String, String>? apktoolInfo;
    try {
      final apktoolYmlPath = path.join(decompileDir, 'apktool.yml');
      final apktoolYmlFile = File(apktoolYmlPath);
      if (await apktoolYmlFile.exists()) {
        final apktoolContent = await apktoolYmlFile.readAsString();
        apktoolInfo = _extractApktoolInfo(apktoolContent);
        onProgress('Found apktool.yml with version info');
      }
    } catch (e) {
      onProgress('Could not read apktool.yml: $e');
    }
    
    // Extract basic info from manifest
    final packageName = _extractPackageName(manifestContent);
    final versionName = apktoolInfo?['versionName'] ?? _extractVersionName(manifestContent);
    final versionCode = apktoolInfo?['versionCode'] ?? _extractVersionCode(manifestContent);
    final targetSdk = apktoolInfo?['targetSdkVersion'] ?? _extractTargetSdk(manifestContent);
    final minSdk = apktoolInfo?['minSdkVersion'] ?? _extractMinSdk(manifestContent);
    
    onProgress('Extracting permissions...');
    final permissions = _extractPermissions(manifestContent);
    
    onProgress('Extracting components...');
    final activities = _extractActivities(manifestContent);
    final services = _extractServices(manifestContent);
    final receivers = _extractReceivers(manifestContent);
    final providers = _extractProviders(manifestContent);
    
    onProgress('Analyzing native libraries...');
    final libraries = await _extractNativeLibraries(decompileDir);
    
    return ApkInfo(
      packageName: packageName,
      versionName: versionName,
      versionCode: versionCode,
      targetSdk: targetSdk,
      minSdk: minSdk,
      permissions: permissions,
      activities: activities,
      services: services,
      receivers: receivers,
      providers: providers,
      libraries: libraries,
      manifestContent: manifestContent,
    );
  }

  String _extractPackageName(String manifestContent) {
    final regex = RegExp(r'package="([^"]*)"');
    final match = regex.firstMatch(manifestContent);
    return match?.group(1) ?? 'Unknown';
  }

  String _extractVersionName(String manifestContent) {
    // Try different patterns for version name
    final patterns = [
      RegExp(r'android:versionName="([^"]*)"'),
      RegExp(r'versionName="([^"]*)"'),
      RegExp(r'platformBuildVersionName="([^"]*)"'),
    ];
    
    for (final regex in patterns) {
      final match = regex.firstMatch(manifestContent);
      if (match != null && match.group(1) != null && match.group(1)!.isNotEmpty) {
        return match.group(1)!;
      }
    }
    return 'Unknown';
  }

  String _extractVersionCode(String manifestContent) {
    // Try different patterns for version code
    final patterns = [
      RegExp(r'android:versionCode="([^"]*)"'),
      RegExp(r'versionCode="([^"]*)"'),
      RegExp(r'platformBuildVersionCode="([^"]*)"'),
    ];
    
    for (final regex in patterns) {
      final match = regex.firstMatch(manifestContent);
      if (match != null && match.group(1) != null && match.group(1)!.isNotEmpty) {
        return match.group(1)!;
      }
    }
    return 'Unknown';
  }

  String _extractTargetSdk(String manifestContent) {
    final regex = RegExp(r'<uses-sdk[^>]*android:targetSdkVersion="([^"]*)"');
    final match = regex.firstMatch(manifestContent);
    return match?.group(1) ?? 'Unknown';
  }

  String _extractMinSdk(String manifestContent) {
    final regex = RegExp(r'<uses-sdk[^>]*android:minSdkVersion="([^"]*)"');
    final match = regex.firstMatch(manifestContent);
    return match?.group(1) ?? 'Unknown';
  }

  List<String> _extractPermissions(String manifestContent) {
    final regex = RegExp(r'<uses-permission[^>]*android:name="([^"]*)"');
    final matches = regex.allMatches(manifestContent);
    return matches.map((match) => match.group(1)!).toList();
  }

  List<String> _extractActivities(String manifestContent) {
    final regex = RegExp(r'<activity[^>]*android:name="([^"]*)"');
    final matches = regex.allMatches(manifestContent);
    return matches.map((match) => match.group(1)!).toList();
  }

  List<String> _extractServices(String manifestContent) {
    final regex = RegExp(r'<service[^>]*android:name="([^"]*)"');
    final matches = regex.allMatches(manifestContent);
    return matches.map((match) => match.group(1)!).toList();
  }

  List<String> _extractReceivers(String manifestContent) {
    final regex = RegExp(r'<receiver[^>]*android:name="([^"]*)"');
    final matches = regex.allMatches(manifestContent);
    return matches.map((match) => match.group(1)!).toList();
  }

  List<String> _extractProviders(String manifestContent) {
    final regex = RegExp(r'<provider[^>]*android:name="([^"]*)"');
    final matches = regex.allMatches(manifestContent);
    return matches.map((match) => match.group(1)!).toList();
  }

  Future<List<String>> _extractNativeLibraries(String decompileDir) async {
    final libDir = Directory(path.join(decompileDir, 'lib'));
    final libraries = <String>[];
    
    if (await libDir.exists()) {
      await for (final entity in libDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.so')) {
          final relativePath = path.relative(entity.path, from: decompileDir);
          libraries.add(relativePath);
        }
      }
    }
    
    return libraries;
  }
  
  Map<String, String> _extractApktoolInfo(String apktoolContent) {
    final info = <String, String>{};
    
    // Extract versionCode
    final versionCodeMatch = RegExp(r'versionCode:\s*(\S+)').firstMatch(apktoolContent);
    if (versionCodeMatch != null) {
      String versionCode = versionCodeMatch.group(1)!;
      // Remove quotes if present
      versionCode = versionCode.replaceAll("'", '').replaceAll('"', '');
      info['versionCode'] = versionCode;
    }
    
    // Extract versionName
    final versionNameMatch = RegExp(r'versionName:\s*(.+)$', multiLine: true).firstMatch(apktoolContent);
    if (versionNameMatch != null) {
      String versionName = versionNameMatch.group(1)!.trim();
      // Remove quotes if present
      versionName = versionName.replaceAll("'", '').replaceAll('"', '');
      info['versionName'] = versionName;
    }
    
    // Extract minSdkVersion
    final minSdkMatch = RegExp(r'minSdkVersion:\s*(\S+)').firstMatch(apktoolContent);
    if (minSdkMatch != null) {
      String minSdk = minSdkMatch.group(1)!;
      // Remove quotes if present
      minSdk = minSdk.replaceAll("'", '').replaceAll('"', '');
      info['minSdkVersion'] = minSdk;
    }
    
    // Extract targetSdkVersion
    final targetSdkMatch = RegExp(r'targetSdkVersion:\s*(\S+)').firstMatch(apktoolContent);
    if (targetSdkMatch != null) {
      String targetSdk = targetSdkMatch.group(1)!;
      // Remove quotes if present
      targetSdk = targetSdk.replaceAll("'", '').replaceAll('"', '');
      info['targetSdkVersion'] = targetSdk;
    }
    
    return info;
  }

  Future<void> cleanupDecompiled() async {
    if (_decompiledDirectory != null) {
      final directory = Directory(_decompiledDirectory!);
      
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      _decompiledDirectory = null;
    }
  }
}