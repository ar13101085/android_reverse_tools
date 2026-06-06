import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'config_manager.dart';
import 'file_access_manager.dart';
import '../widgets/console_output.dart';

class ToolCopyHelper {
  static Future<Map<String, bool>> copyToolsToAppDirectory() async {
    final results = <String, bool>{};
    
    try {
      // Get app's document directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final appToolsDir = path.join(documentsDir.path, 'tools');
      
      // Create tools directory if it doesn't exist
      final toolsDirectory = Directory(appToolsDir);
      if (!await toolsDirectory.exists()) {
        await toolsDirectory.create(recursive: true);
      }
      
      ConsoleLogger.log('ToolCopyHelper: App tools directory: $appToolsDir');
      
      // Tools to copy
      final requiredTools = [
        'apktool.jar',
        'uber-apk-signer.jar',
        'jadx-gui.jar',
        'jd-gui.jar',
      ];
      
      // Try to copy each tool
      for (final toolName in requiredTools) {
        try {
          final sourcePath = path.join(ConfigManager.toolsDir, toolName);
          final destPath = path.join(appToolsDir, toolName);
          
          // Check if tool already exists in app directory
          final destFile = File(destPath);
          if (await destFile.exists()) {
            ConsoleLogger.log('ToolCopyHelper: Tool already exists in app directory: $toolName');
            results[toolName] = true;
            continue;
          }
          
          // Try to copy from configured tools directory
          final sourceFile = File(sourcePath);
          if (await sourceFile.exists()) {
            await sourceFile.copy(destPath);
            
            // Make it executable on Unix systems
            if (Platform.isMacOS || Platform.isLinux) {
              await Process.run('chmod', ['+x', destPath]);
            }
            
            ConsoleLogger.log('ToolCopyHelper: Successfully copied $toolName to app directory');
            results[toolName] = true;
          } else {
            ConsoleLogger.log('ToolCopyHelper: Tool not found at source: $sourcePath');
            results[toolName] = false;
          }
        } catch (e) {
          ConsoleLogger.log('ToolCopyHelper: Error copying $toolName: $e');
          results[toolName] = false;
        }
      }
      
      // Check for Frida and SignatureBypass directories
      await _copyDirectory('frida', ConfigManager.toolsDir, appToolsDir);
      await _copyDirectory('SignatureBypass', ConfigManager.toolsDir, appToolsDir);
      
    } catch (e) {
      ConsoleLogger.log('ToolCopyHelper: Error in copyToolsToAppDirectory: $e');
    }
    
    return results;
  }
  
  static Future<void> _copyDirectory(String dirName, String sourceParent, String destParent) async {
    try {
      final sourceDir = Directory(path.join(sourceParent, dirName));
      if (!await sourceDir.exists()) {
        ConsoleLogger.log('ToolCopyHelper: Directory not found: ${sourceDir.path}');
        return;
      }
      
      final destDir = Directory(path.join(destParent, dirName));
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }
      
      await for (final entity in sourceDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = path.relative(entity.path, from: sourceDir.path);
          final destPath = path.join(destDir.path, relativePath);
          
          // Create parent directory if needed
          final destFile = File(destPath);
          await destFile.parent.create(recursive: true);
          
          // Copy the file
          await entity.copy(destPath);
        }
      }
      
      ConsoleLogger.log('ToolCopyHelper: Successfully copied directory: $dirName');
    } catch (e) {
      ConsoleLogger.log('ToolCopyHelper: Error copying directory $dirName: $e');
    }
  }
  
  static Future<String?> promptForToolsWithFilePicker() async {
    ConsoleLogger.log('ToolCopyHelper: Prompting user to select tools directory');
    
    // Show file picker to select tools directory
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select directory containing APK tools (apktool.jar, etc.)',
    );
    
    if (selectedDirectory != null) {
      ConsoleLogger.log('ToolCopyHelper: User selected directory: $selectedDirectory');
      
      // Verify required tools exist
      final requiredTools = ['apktool.jar', 'uber-apk-signer.jar'];
      final missingTools = <String>[];
      
      for (final tool in requiredTools) {
        final toolFile = File(path.join(selectedDirectory, tool));
        if (!await toolFile.exists()) {
          missingTools.add(tool);
        }
      }
      
      if (missingTools.isNotEmpty) {
        ConsoleLogger.log('ToolCopyHelper: Missing required tools: ${missingTools.join(', ')}');
        return null;
      }
      
      return selectedDirectory;
    }
    
    return null;
  }
}