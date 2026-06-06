import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../widgets/console_output.dart';
import 'config_manager.dart';

class FileAccessManager {
  static final Map<String, String> _accessiblePaths = {};
  static const String _bookmarksFile = 'accessible_paths.json';
  
  /// Request access to a directory and remember it for future use
  static Future<bool> requestDirectoryAccess(String purpose) async {
    try {
      ConsoleLogger.log('FileAccessManager: Requesting directory access for: $purpose');
      
      // Show file picker to request access
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Grant access to directory for $purpose',
      );
      
      if (selectedDirectory != null) {
        ConsoleLogger.log('FileAccessManager: User granted access to: $selectedDirectory');
        _accessiblePaths[purpose] = selectedDirectory;
        await _saveAccessiblePaths();
        return true;
      }
      
      ConsoleLogger.log('FileAccessManager: User cancelled directory access request');
      return false;
    } catch (e) {
      ConsoleLogger.log('FileAccessManager: Error requesting directory access: $e');
      return false;
    }
  }
  
  /// Request access to a specific file
  static Future<String?> requestFileAccess(String dialogTitle, List<String>? allowedExtensions) async {
    try {
      ConsoleLogger.log('FileAccessManager: Requesting file access');
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: dialogTitle,
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );
      
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        ConsoleLogger.log('FileAccessManager: User granted access to file: $filePath');
        
        // Store the directory path for future access
        final dirPath = path.dirname(filePath);
        _accessiblePaths[dirPath] = dirPath;
        await _saveAccessiblePaths();
        
        return filePath;
      }
      
      ConsoleLogger.log('FileAccessManager: User cancelled file access request');
      return null;
    } catch (e) {
      ConsoleLogger.log('FileAccessManager: Error requesting file access: $e');
      return null;
    }
  }
  
  /// Check if we have access to a path
  static bool hasAccess(String filePath) {
    // Check if the exact path or any parent directory is accessible
    String currentPath = filePath;
    while (currentPath != '/' && currentPath.isNotEmpty) {
      if (_accessiblePaths.containsValue(currentPath)) {
        return true;
      }
      currentPath = path.dirname(currentPath);
    }
    return false;
  }
  
  /// Get accessible directory for a purpose
  static String? getAccessiblePath(String purpose) {
    return _accessiblePaths[purpose];
  }
  
  /// Store an accessible path
  static Future<void> storeAccessiblePath(String purpose, String path) async {
    _accessiblePaths[purpose] = path;
    await _saveAccessiblePaths();
  }
  
  /// Initialize and load saved accessible paths
  static Future<void> initialize() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final bookmarksPath = path.join(appDir.path, _bookmarksFile);
      final bookmarksFile = File(bookmarksPath);
      
      if (await bookmarksFile.exists()) {
        final content = await bookmarksFile.readAsString();
        // Simple JSON parsing for paths
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.contains(':')) {
            final parts = line.split(':');
            if (parts.length >= 2) {
              final key = parts[0].trim();
              final value = parts.sublist(1).join(':').trim();
              _accessiblePaths[key] = value;
            }
          }
        }
        ConsoleLogger.log('FileAccessManager: Loaded ${_accessiblePaths.length} accessible paths');
      }
    } catch (e) {
      ConsoleLogger.log('FileAccessManager: Error loading accessible paths: $e');
    }
  }
  
  /// Save accessible paths for persistence
  static Future<void> _saveAccessiblePaths() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final bookmarksPath = path.join(appDir.path, _bookmarksFile);
      final bookmarksFile = File(bookmarksPath);
      
      final content = _accessiblePaths.entries
          .map((e) => '${e.key}:${e.value}')
          .join('\n');
      
      await bookmarksFile.writeAsString(content);
      ConsoleLogger.log('FileAccessManager: Saved ${_accessiblePaths.length} accessible paths');
    } catch (e) {
      ConsoleLogger.log('FileAccessManager: Error saving accessible paths: $e');
    }
  }
  
  /// Copy file with access request if needed
  static Future<bool> copyFileWithAccess(String sourcePath, String destPath) async {
    try {
      final sourceFile = File(sourcePath);
      
      // Check if we already have access
      if (!hasAccess(sourcePath)) {
        ConsoleLogger.log('FileAccessManager: No access to source file, requesting...');
        
        // Request access to the source directory
        final sourceDir = path.dirname(sourcePath);
        final granted = await requestDirectoryAccess('tools-directory');
        
        if (!granted) {
          ConsoleLogger.log('FileAccessManager: Access denied to source directory');
          return false;
        }
      }
      
      // Try to copy the file
      if (await sourceFile.exists()) {
        await sourceFile.copy(destPath);
        ConsoleLogger.log('FileAccessManager: Successfully copied file to: $destPath');
        return true;
      } else {
        ConsoleLogger.log('FileAccessManager: Source file does not exist: $sourcePath');
        return false;
      }
    } catch (e) {
      ConsoleLogger.log('FileAccessManager: Error copying file: $e');
      return false;
    }
  }
  
  /// Execute operation with file access
  static Future<T?> executeWithAccess<T>(
    String filePath,
    Future<T> Function() operation,
    String accessPurpose,
  ) async {
    try {
      // First try the operation
      return await operation();
    } catch (e) {
      // If it fails, check if it's a permission error
      if (e.toString().contains('Operation not permitted') ||
          e.toString().contains('Permission denied') ||
          e.toString().contains('cannot access')) {
        
        ConsoleLogger.log('FileAccessManager: Permission error, requesting access...');
        
        // Request access
        final granted = await requestDirectoryAccess(accessPurpose);
        
        if (granted) {
          // Try the operation again
          try {
            return await operation();
          } catch (e2) {
            ConsoleLogger.log('FileAccessManager: Operation still failed after access grant: $e2');
            return null;
          }
        }
      }
      
      ConsoleLogger.log('FileAccessManager: Operation failed: $e');
      return null;
    }
  }
}