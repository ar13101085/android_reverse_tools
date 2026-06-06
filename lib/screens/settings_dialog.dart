import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as path;
import '../utils/config_manager.dart';
import '../utils/tool_copy_helper.dart';
import '../utils/file_access_manager.dart';
import '../widgets/console_output.dart';

class SettingsDialog extends StatefulWidget {
  @override
  _SettingsDialogState createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  TextEditingController? _toolsDirController;
  TextEditingController? _keystorePathController;
  TextEditingController? _keystorePasswordController;
  TextEditingController? _keyAliasController;
  TextEditingController? _keyPasswordController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }
  
  Future<void> _initializeControllers() async {
    try {
      // Get the env file path
      final envPath = await ConfigManager.envFilePath;
      ConsoleLogger.log('Settings Dialog - Env file path: $envPath');
      
      // Check if file exists and read its contents
      final envFile = File(envPath);
      if (await envFile.exists()) {
        final contents = await envFile.readAsString();
        ConsoleLogger.log('Settings Dialog - Current .env file contents:');
        ConsoleLogger.log(contents);
      } else {
        ConsoleLogger.log('Settings Dialog - .env file does not exist at: $envPath');
      }
      
      // Reload the .env file to get fresh values
      await ConfigManager.reloadEnv();
      
      // Debug: Print loaded values from dotenv
      ConsoleLogger.log('Settings Dialog - After reload, dotenv values:');
      try {
        ConsoleLogger.log('TOOLS_DIR from dotenv: "${dotenv.env['TOOLS_DIR']}"');
        ConsoleLogger.log('KEYSTORE_PATH from dotenv: "${dotenv.env['KEYSTORE_PATH']}"');
        ConsoleLogger.log('All dotenv keys: ${dotenv.env.keys.toList()}');
      } catch (e) {
        ConsoleLogger.log('Settings Dialog - Error accessing dotenv: $e');
      }
      
      // Debug: Print loaded values from ConfigManager
      ConsoleLogger.log('Settings Dialog - ConfigManager raw values:');
      ConsoleLogger.log('TOOLS_DIR: "${ConfigManager.toolsDirRaw}"');
      ConsoleLogger.log('KEYSTORE_PATH: "${ConfigManager.keystorePathRaw}"');
      
      if (mounted) {
        setState(() {
          // Use raw ConfigManager getters to show actual values without defaults
          _toolsDirController = TextEditingController(text: ConfigManager.toolsDirRaw);
          _keystorePathController = TextEditingController(text: ConfigManager.keystorePathRaw);
          _keystorePasswordController = TextEditingController(text: ConfigManager.keystorePasswordRaw);
          _keyAliasController = TextEditingController(text: ConfigManager.keyAliasRaw);
          _keyPasswordController = TextEditingController(text: ConfigManager.keyPasswordRaw);
          
          // Add listener to enable/disable test button
          _keystorePathController!.addListener(() => setState(() {}));
          _keystorePasswordController!.addListener(() => setState(() {}));
          _keyAliasController!.addListener(() => setState(() {}));
          
          _isLoading = false;
        });
      }
    } catch (e) {
      ConsoleLogger.log('Error loading .env file in settings dialog: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  

  @override
  void dispose() {
    _toolsDirController?.dispose();
    _keystorePathController?.dispose();
    _keystorePasswordController?.dispose();
    _keyAliasController?.dispose();
    _keyPasswordController?.dispose();
    super.dispose();
  }

  Future<void> _selectToolsDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Tools Directory (this grants access)',
    );

    if (selectedDirectory != null && mounted) {
      setState(() {
        // Ensure controller exists before updating
        if (_toolsDirController != null) {
          _toolsDirController!.text = selectedDirectory;
        } else {
          // If controller doesn't exist yet, create it with the selected value
          _toolsDirController = TextEditingController(text: selectedDirectory);
        }
      });
      
      // Store the access permission
      await FileAccessManager.storeAccessiblePath('tools-directory', selectedDirectory);
      ConsoleLogger.log('Settings Dialog - Tools directory selected and access granted: $selectedDirectory');
      
      // Check if we can access the directory and copy tools
      await _checkAndCopyTools(selectedDirectory);
    }
  }
  
  Future<void> _checkAndCopyTools(String toolsDir) async {
    try {
      ConsoleLogger.log('Settings Dialog - Checking tools directory: $toolsDir');
      
      // Check if we can access the directory
      final dir = Directory(toolsDir);
      if (!await dir.exists()) {
        ConsoleLogger.log('Settings Dialog - Tools directory does not exist');
        return;
      }
      
      // Check for required tools
      final requiredTools = ['apktool.jar', 'uber-apk-signer.jar'];
      final foundTools = <String>[];
      final missingTools = <String>[];
      
      for (final tool in requiredTools) {
        final toolFile = File(path.join(toolsDir, tool));
        if (await toolFile.exists()) {
          foundTools.add(tool);
          ConsoleLogger.log('Settings Dialog - Found tool: $tool');
        } else {
          missingTools.add(tool);
          ConsoleLogger.log('Settings Dialog - Missing tool: $tool');
        }
      }
      
      if (missingTools.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Missing tools: ${missingTools.join(', ')}'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ConsoleLogger.log('Settings Dialog - All required tools found');
      }
    } catch (e) {
      ConsoleLogger.log('Settings Dialog - Error checking tools: $e');
    }
  }

  Future<void> _selectKeystoreFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Keystore File (this grants access)',
      type: FileType.custom,
      allowedExtensions: ['keystore', 'jks'],
    );

    if (result != null && result.files.single.path != null && mounted) {
      final selectedPath = result.files.single.path!;
      
      setState(() {
        // Ensure controller exists before updating
        if (_keystorePathController != null) {
          _keystorePathController!.text = selectedPath;
        } else {
          // If controller doesn't exist yet, create it with the selected value
          _keystorePathController = TextEditingController(text: selectedPath);
        }
      });
      
      // Store the access permission
      final dirPath = path.dirname(selectedPath);
      await FileAccessManager.storeAccessiblePath('keystore-directory', dirPath);
      
      ConsoleLogger.log('Settings Dialog - Keystore file selected and access granted: $selectedPath');
    }
  }

  Future<void> _testKeystore() async {
    final keystorePath = _keystorePathController?.text ?? '';
    final keystorePassword = _keystorePasswordController?.text ?? '';
    final keyAlias = _keyAliasController?.text ?? '';
    final keyPassword = _keyPasswordController?.text ?? '';
    
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Testing Keystore'),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Validating keystore configuration...'),
            ],
          ),
        );
      },
    );
    
    try {
      // Check if keystore file exists with file access handling
      final keystoreFile = File(keystorePath);
      bool fileExists = false;
      
      // Try to check if file exists
      try {
        fileExists = await keystoreFile.exists();
      } catch (e) {
        ConsoleLogger.log('Settings Dialog - Error accessing keystore file: $e');
        fileExists = false;
      }
      
      if (!fileExists) {
        // Check if we have access to the keystore directory
        if (!FileAccessManager.hasAccess(keystorePath)) {
          Navigator.of(context).pop();
          ConsoleLogger.log('Settings Dialog - No access to keystore file, requesting permission...');
          
          // Request access to the keystore file
          final granted = await FileAccessManager.requestFileAccess(
            'Select keystore file to grant access',
            ['keystore', 'jks'],
          );
          
          if (granted == null) {
            _showTestResult(
              'Access Denied',
              'Access to keystore file was denied. Please grant access to test the keystore.',
              false,
            );
            return;
          }
          
          // Update the path if a different file was selected
          if (granted != keystorePath && mounted) {
            setState(() {
              _keystorePathController?.text = granted;
            });
          }
          
          // Re-show the progress dialog
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Testing Keystore'),
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 20),
                      Text('Validating keystore configuration...'),
                    ],
                  ),
                );
              },
            );
          }
          
          // Check again after permission grant
          try {
            fileExists = await File(granted).exists();
          } catch (e) {
            fileExists = false;
          }
        }
        
        if (!fileExists) {
          Navigator.of(context).pop();
          _showTestResult(
            'Keystore Not Found',
            'The keystore file does not exist or cannot be accessed at the specified path:\n$keystorePath',
            false,
          );
          return;
        }
      }
      
      // Test keystore with keytool command
      // Use the actual keystore path that we have access to
      final actualKeystorePath = FileAccessManager.hasAccess(keystorePath) 
          ? keystorePath 
          : (_keystorePathController?.text ?? keystorePath);
      
      final result = await FileAccessManager.executeWithAccess<ProcessResult>(
        actualKeystorePath,
        () => Process.run(
          'keytool',
          [
            '-list',
            '-keystore', actualKeystorePath,
            '-storepass', keystorePassword,
            '-alias', keyAlias,
          ],
          runInShell: true,
        ),
        'keystore-validation',
      ) ?? ProcessResult(0, 1, '', 'Failed to execute keytool command');
      
      Navigator.of(context).pop();
      
      if (result.exitCode == 0) {
        // Parse keytool output for certificate info
        final output = result.stdout.toString();
        String certInfo = 'Keystore is valid!\n\n';
        
        // Extract certificate type
        final certTypeMatch = RegExp(r'Certificate fingerprints:.*?(\w+):').firstMatch(output);
        if (certTypeMatch != null) {
          certInfo += 'Certificate Type: ${certTypeMatch.group(1)}\n';
        }
        
        // Extract creation date
        final creationMatch = RegExp(r'Creation date: (.+)').firstMatch(output);
        if (creationMatch != null) {
          certInfo += 'Creation Date: ${creationMatch.group(1)}\n';
        }
        
        // Check if key password is correct (if different from store password)
        if (keyPassword.isNotEmpty && keyPassword != keystorePassword) {
          final keyResult = await Process.run(
            'keytool',
            [
              '-list',
              '-keystore', keystorePath,
              '-storepass', keystorePassword,
              '-alias', keyAlias,
              '-keypass', keyPassword,
              '-v',
            ],
            runInShell: true,
          );
          
          if (keyResult.exitCode != 0) {
            certInfo += '\nWarning: Key password may be incorrect';
          } else {
            certInfo += '\nKey password is valid';
          }
        }
        
        _showTestResult(
          'Keystore Valid',
          certInfo,
          true,
        );
      } else {
        // Parse error message
        final error = result.stderr.toString();
        String errorMessage = 'Failed to validate keystore:\n\n';
        
        if (error.contains('password was incorrect')) {
          errorMessage += 'The keystore password is incorrect.';
        } else if (error.contains('Alias <$keyAlias> does not exist')) {
          errorMessage += 'The key alias "$keyAlias" does not exist in this keystore.';
        } else if (error.contains('Invalid keystore format')) {
          errorMessage += 'The file is not a valid keystore.';
        } else {
          errorMessage += error.isNotEmpty ? error : result.stdout.toString();
        }
        
        _showTestResult(
          'Keystore Invalid',
          errorMessage,
          false,
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showTestResult(
        'Test Failed',
        'An error occurred while testing the keystore:\n\n$e',
        false,
      );
    }
  }
  
  void _showTestResult(String title, String message, bool success) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green : Colors.red,
              ),
              SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(message),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _saveSettings() async {
    // Get current values from controllers
    final toolsDir = _toolsDirController?.text ?? '';
    final keystorePath = _keystorePathController?.text ?? '';
    final keystorePassword = _keystorePasswordController?.text ?? '';
    final keyAlias = _keyAliasController?.text ?? '';
    final keyPassword = _keyPasswordController?.text ?? '';
    
    ConsoleLogger.log('Settings Dialog - Values to save:');
    ConsoleLogger.log('  TOOLS_DIR: "$toolsDir"');
    ConsoleLogger.log('  KEYSTORE_PATH: "$keystorePath"');
    ConsoleLogger.log('  KEYSTORE_PASSWORD: "${keystorePassword.isNotEmpty ? "***" : ""}"');
    ConsoleLogger.log('  KEY_ALIAS: "$keyAlias"');
    ConsoleLogger.log('  KEY_PASSWORD: "${keyPassword.isNotEmpty ? "***" : ""}"');
    
    // Create the updated .env content
    final envContent = '''# Tools Directory
TOOLS_DIR=$toolsDir
# Keystore Configuration (optional)
KEYSTORE_PATH=$keystorePath
KEYSTORE_PASSWORD=$keystorePassword
KEY_ALIAS=$keyAlias
KEY_PASSWORD=$keyPassword''';

    try {
      // Write to .env file at the correct location
      final envPath = await ConfigManager.envFilePath;
      final envFile = File(envPath);
      
      ConsoleLogger.log('Settings Dialog - Saving to: $envPath');
      ConsoleLogger.log('Content to save:\n$envContent');
      
      await envFile.writeAsString(envContent);
      
      // Verify file was written
      if (await envFile.exists()) {
        final savedContent = await envFile.readAsString();
        ConsoleLogger.log('Settings Dialog - Saved content verified:\n$savedContent');
      }
      
      // Reload the configuration to ensure everything is in sync
      await ConfigManager.reloadEnv();
      
      // Verify values were loaded correctly after reload
      ConsoleLogger.log('Settings Dialog - After reload verification:');
      ConsoleLogger.log('  TOOLS_DIR from ConfigManager: "${ConfigManager.toolsDirRaw}"');
      ConsoleLogger.log('  KEYSTORE_PATH from ConfigManager: "${ConfigManager.keystorePathRaw}"');
      
      // Try to copy tools to app directory after saving
      if (toolsDir.isNotEmpty) {
        ConsoleLogger.log('Settings Dialog - Verifying access to tools directory...');
        
        // Check if we have access
        if (!FileAccessManager.hasAccess(toolsDir)) {
          ConsoleLogger.log('Settings Dialog - No access to tools directory, will request when needed');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tools directory saved. Access will be requested when needed.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          // Try to copy tools
          ConsoleLogger.log('Settings Dialog - Attempting to copy tools to app directory...');
          final copyResults = await ToolCopyHelper.copyToolsToAppDirectory();
          
          final successCount = copyResults.values.where((v) => v).length;
          final totalCount = copyResults.length;
          
          if (successCount == totalCount) {
            ConsoleLogger.log('Settings Dialog - All tools copied successfully');
          } else if (successCount > 0) {
            ConsoleLogger.log('Settings Dialog - Copied $successCount of $totalCount tools');
          } else {
            ConsoleLogger.log('Settings Dialog - Tools will be accessed on demand');
          }
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ConsoleLogger.log('Settings Dialog - Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Settings'),
      content: _isLoading 
        ? Container(
            width: 500,
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        : SingleChildScrollView(
            child: Container(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              
              // Tools Directory Section
              Text(
                'Tools Directory',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _toolsDirController,
                      decoration: InputDecoration(
                        labelText: 'Tools Directory Path',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      readOnly: true,
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _selectToolsDirectory,
                    icon: Icon(Icons.folder_open),
                    label: Text('Browse'),
                  ),
                ],
              ),
              SizedBox(height: 24),
              
              // Keystore Configuration Section
              Text(
                'Keystore Configuration (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              
              // Keystore Path
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keystorePathController,
                      decoration: InputDecoration(
                        labelText: 'Keystore Path',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      readOnly: true,
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _selectKeystoreFile,
                    icon: Icon(Icons.file_open),
                    label: Text('Browse'),
                  ),
                ],
              ),
              SizedBox(height: 12),
              
              // Keystore Password
              TextField(
                controller: _keystorePasswordController,
                decoration: InputDecoration(
                  labelText: 'Keystore Password',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                obscureText: true,
              ),
              SizedBox(height: 12),
              
              // Key Alias
              TextField(
                controller: _keyAliasController,
                decoration: InputDecoration(
                  labelText: 'Key Alias',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              SizedBox(height: 12),
              
              // Key Password
              TextField(
                controller: _keyPasswordController,
                decoration: InputDecoration(
                  labelText: 'Key Password',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              
              // Test Keystore Button
              Center(
                child: ElevatedButton.icon(
                  onPressed: (_keystorePathController?.text.isNotEmpty == true &&
                      _keystorePasswordController?.text.isNotEmpty == true &&
                      _keyAliasController?.text.isNotEmpty == true) 
                    ? _testKeystore 
                    : null,
                  icon: Icon(Icons.verified_user),
                  label: Text('Test Keystore Configuration'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
                ],
              ),
            ),
          ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () async {
            await _saveSettings();
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}