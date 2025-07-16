import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import '../utils/config_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SettingsDialog extends StatefulWidget {
  @override
  _SettingsDialogState createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _toolsDirController;
  late TextEditingController _keystorePathController;
  late TextEditingController _keystorePasswordController;
  late TextEditingController _keyAliasController;
  late TextEditingController _keyPasswordController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _toolsDirController = TextEditingController(text: ConfigManager.toolsDir);
    _keystorePathController = TextEditingController(text: ConfigManager.keystorePath);
    _keystorePasswordController = TextEditingController(text: ConfigManager.keystorePassword);
    _keyAliasController = TextEditingController(text: ConfigManager.keyAlias);
    _keyPasswordController = TextEditingController(text: ConfigManager.keyPassword);
    
    // Add listeners to save on text change
    _keystorePasswordController.addListener(_onTextChanged);
    _keyAliasController.addListener(_onTextChanged);
    _keyPasswordController.addListener(_onTextChanged);
    
    // Add listener to enable/disable test button
    _keystorePathController.addListener(() => setState(() {}));
    _keystorePasswordController.addListener(() => setState(() {}));
    _keyAliasController.addListener(() => setState(() {}));
  }
  
  void _onTextChanged() {
    // Cancel any existing timer
    _debounceTimer?.cancel();
    
    // Save settings after a short delay to avoid saving on every keystroke
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      _saveSettings();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _toolsDirController.dispose();
    _keystorePathController.dispose();
    _keystorePasswordController.dispose();
    _keyAliasController.dispose();
    _keyPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectToolsDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Tools Directory',
    );

    if (selectedDirectory != null) {
      setState(() {
        _toolsDirController.text = selectedDirectory;
      });
      await _saveSettings();
    }
  }

  Future<void> _selectKeystoreFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Keystore File',
      type: FileType.custom,
      allowedExtensions: ['keystore', 'jks'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _keystorePathController.text = result.files.single.path!;
      });
      await _saveSettings();
    }
  }

  Future<void> _testKeystore() async {
    final keystorePath = _keystorePathController.text;
    final keystorePassword = _keystorePasswordController.text;
    final keyAlias = _keyAliasController.text;
    final keyPassword = _keyPasswordController.text;
    
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
      // Check if keystore file exists
      final keystoreFile = File(keystorePath);
      if (!await keystoreFile.exists()) {
        Navigator.of(context).pop();
        _showTestResult(
          'Keystore Not Found',
          'The keystore file does not exist at the specified path:\n$keystorePath',
          false,
        );
        return;
      }
      
      // Test keystore with keytool command
      final result = await Process.run(
        'keytool',
        [
          '-list',
          '-keystore', keystorePath,
          '-storepass', keystorePassword,
          '-alias', keyAlias,
        ],
        runInShell: true,
      );
      
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
  
  Future<void> _saveSettings({bool showMessage = false}) async {
    // Create the updated .env content
    final envContent = '''# Tools Directory
TOOLS_DIR=${_toolsDirController.text}
# Keystore Configuration (optional)
KEYSTORE_PATH=${_keystorePathController.text}
KEYSTORE_PASSWORD=${_keystorePasswordController.text}
KEY_ALIAS=${_keyAliasController.text}
KEY_PASSWORD=${_keyPasswordController.text}''';

    try {
      // Write to .env file
      final envFile = File('.env');
      await envFile.writeAsString(envContent);
      
      // Reload dotenv
      dotenv.clean();
      await dotenv.load(fileName: '.env');
      
      if (showMessage && mounted) {
        // Show success message only when explicitly requested
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
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
      content: SingleChildScrollView(
        child: Container(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Auto-save notice
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Settings are saved automatically',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              
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
                    onPressed: _selectToolsDirectory,
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
                    onPressed: _selectKeystoreFile,
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
                  onPressed: (_keystorePathController.text.isNotEmpty &&
                      _keystorePasswordController.text.isNotEmpty &&
                      _keyAliasController.text.isNotEmpty) 
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
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: Text('Close'),
        ),
      ],
    );
  }
}