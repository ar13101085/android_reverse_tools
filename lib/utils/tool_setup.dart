import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'config_manager.dart';

class ToolSetup {
  static bool _isInitialized = false;
  static late String _appToolsDir;
  
  static String get appToolsDir => _appToolsDir;
  
  static Future<void> initializeTools() async {
    if (_isInitialized) return;
    
    try {
      // Get app's document directory
      final documentsDir = await getApplicationDocumentsDirectory();
      _appToolsDir = path.join(documentsDir.path, 'tools');
      
      // Create tools directory if it doesn't exist
      final toolsDirectory = Directory(_appToolsDir);
      if (!await toolsDirectory.exists()) {
        await toolsDirectory.create(recursive: true);
      }
      
      // Copy essential tools
      await _copyToolIfNeeded('apktool.jar');
      await _copyToolIfNeeded('uber-apk-signer.jar');
      
      _isInitialized = true;
      print('Tools initialized in: $_appToolsDir');
    } catch (e) {
      print('Error initializing tools: $e');
      throw e;
    }
  }
  
  static Future<void> _copyToolIfNeeded(String toolName) async {
    final sourcePath = path.join(ConfigManager.toolsDir, toolName);
    final destPath = path.join(_appToolsDir, toolName);
    
    final sourceFile = File(sourcePath);
    final destFile = File(destPath);
    
    // Check if source exists
    if (!await sourceFile.exists()) {
      print('Warning: Tool not found at source: $sourcePath');
      return;
    }
    
    // Check if already copied and up to date
    if (await destFile.exists()) {
      final sourceStats = await sourceFile.stat();
      final destStats = await destFile.stat();
      
      // If sizes match, assume it's already copied
      if (sourceStats.size == destStats.size) {
        print('Tool already exists: $toolName');
        return;
      }
    }
    
    // Copy the file
    print('Copying tool: $toolName');
    await sourceFile.copy(destPath);
    
    // Make it executable on Unix systems
    if (Platform.isMacOS || Platform.isLinux) {
      await Process.run('chmod', ['+x', destPath]);
    }
  }
  
  static String getToolPath(String toolName) {
    if (!_isInitialized) {
      throw Exception('Tools not initialized. Call initializeTools() first.');
    }
    return path.join(_appToolsDir, toolName);
  }
  
  static Future<bool> verifyTool(String toolName) async {
    if (!_isInitialized) return false;
    
    final toolPath = getToolPath(toolName);
    final toolFile = File(toolPath);
    return await toolFile.exists();
  }
}