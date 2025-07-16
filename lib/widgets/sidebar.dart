import 'package:flutter/material.dart';
import 'dart:io';
import '../services/apk_service.dart';
import '../services/command_executor.dart';
import '../utils/config_manager.dart';
import '../screens/settings_dialog.dart';

class SideBar extends StatefulWidget {
  final Function(String) onConsoleOutput;
  final String? currentApkPath;
  final String? decompiledDirectory;

  SideBar({
    required this.onConsoleOutput,
    this.currentApkPath,
    this.decompiledDirectory,
  });

  @override
  _SideBarState createState() => _SideBarState();
}

class _SideBarState extends State<SideBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      color: Colors.grey[200],
      child: Column(
        children: [
          SizedBox(height: 20),
          _buildSidebarButton(
            icon: Icons.settings,
            label: 'Settings',
            onPressed: () => _showSettingsDialog(context),
          ),
          SizedBox(height: 10),
          _buildSidebarButton(
            icon: Icons.build,
            label: 'Build APK',
            onPressed: () => _buildApk(),
          ),
          SizedBox(height: 10),
          _buildSidebarButton(
            icon: Icons.install_mobile,
            label: 'Install APK',
            onPressed: () => _installApk(),
          ),
          SizedBox(height: 10),
          _buildSidebarButton(
            icon: Icons.folder_open,
            label: 'Open in Explorer',
            onPressed: () => _openInExplorer(),
          ),
          SizedBox(height: 10),
          _buildSidebarButton(
            icon: Icons.code,
            label: 'Open with JD-GUI',
            onPressed: () => _openWithJDGui(),
          ),
          SizedBox(height: 10),
          _buildSidebarButton(
            icon: Icons.edit,
            label: 'Open with VSCode',
            onPressed: () => _openWithVSCode(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 100,
      height: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(icon, size: 32),
            onPressed: onPressed,
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SettingsDialog(),
    );
    
    if (result == true) {
      widget.onConsoleOutput('Settings updated successfully');
      // Optionally trigger a refresh or reinitialize the app
    } else {
      widget.onConsoleOutput('Settings dialog closed without saving');
    }
  }

  void _buildApk() async {
    try {
      if (widget.decompiledDirectory == null) {
        widget.onConsoleOutput('No APK has been decompiled yet');
        _showAlert(
          context, 
          'Build Failed', 
          'No APK has been decompiled yet. Please import and decompile an APK first.',
          isError: true
        );
        return;
      }
      
      widget.onConsoleOutput('Building APK from: ${widget.decompiledDirectory}');
      
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Building APK...'),
              ],
            ),
          );
        },
      );
      
      final service = ApkService.create();
      final outputApk = widget.currentApkPath?.replaceAll('.apk', '_modified.apk') ?? 'modified.apk';
      
      final result = await service.buildApk(widget.decompiledDirectory!, outputApk);
      
      // Close progress dialog
      Navigator.of(context).pop();
      
      if (result.exitCode == 0) {
        widget.onConsoleOutput('APK built successfully: $outputApk');
        widget.onConsoleOutput(result.stdout);
        
        // Now sign the APK
        widget.onConsoleOutput('Signing APK...');
        
        // Show signing progress dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Signing APK...'),
                ],
              ),
            );
          },
        );
        
        ProcessResult signResult;
        
        // Check if we have keystore configuration
        if (ConfigManager.keystorePath.isNotEmpty && 
            ConfigManager.keystorePassword.isNotEmpty && 
            ConfigManager.keyAlias.isNotEmpty) {
          // Sign with custom keystore
          widget.onConsoleOutput('Signing with custom keystore: ${ConfigManager.keystorePath}');
          signResult = await service.signApkWithKeystore(
            outputApk,
            ConfigManager.keystorePath,
            ConfigManager.keystorePassword,
            ConfigManager.keyAlias,
            ConfigManager.keyPassword.isNotEmpty ? ConfigManager.keyPassword : ConfigManager.keystorePassword,
          );
        } else {
          // Sign with default debug keystore using uber-apk-signer
          widget.onConsoleOutput('Signing with default debug keystore...');
          signResult = await service.signApk(outputApk);
        }
        
        // Close signing dialog
        Navigator.of(context).pop();
        
        if (signResult.exitCode == 0) {
          widget.onConsoleOutput('APK signed successfully!');
          widget.onConsoleOutput(signResult.stdout);
          _showAlert(
            context,
            'Build & Sign Successful',
            'APK built and signed successfully!\n\nOutput: $outputApk',
            isError: false
          );
        } else {
          widget.onConsoleOutput('Failed to sign APK');
          widget.onConsoleOutput('Error: ${signResult.stderr}');
          _showAlert(
            context,
            'Signing Failed',
            'APK was built but signing failed.\n\nError: ${signResult.stderr}',
            isError: true
          );
        }
      } else {
        widget.onConsoleOutput('Failed to build APK');
        widget.onConsoleOutput(result.stderr);
        _showAlert(
          context,
          'Build Failed',
          'Failed to build APK.\n\nError: ${result.stderr}',
          isError: true
        );
      }
    } catch (e) {
      // Close progress dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      widget.onConsoleOutput('Error building APK: $e');
      _showAlert(
        context,
        'Build Error',
        'An error occurred while building APK:\n\n$e',
        isError: true
      );
    }
  }

  void _installApk() async {
    try {
      widget.onConsoleOutput('Checking for connected devices...');
      
      final service = ApkService.create();
      final devicesResult = await service.getConnectedDevices();
      
      if (devicesResult.exitCode != 0 || devicesResult.stdout.trim().isEmpty || 
          !devicesResult.stdout.contains('device')) {
        widget.onConsoleOutput('No ADB devices found');
        _showAlert(
          context,
          'No Devices Found',
          'No Android devices connected.\n\nPlease connect a device and enable USB debugging.',
          isError: true
        );
        return;
      }
      
      // Parse connected devices
      final List<String> devices = [];
      final lines = devicesResult.stdout.split('\n');
      for (final line in lines) {
        if (line.contains('\tdevice') && !line.startsWith('List of devices')) {
          final parts = line.split('\t');
          if (parts.isNotEmpty) {
            final deviceId = parts.first.trim();
            if (deviceId.isNotEmpty) {
              devices.add(deviceId);
            }
          }
        }
      }
      
      if (devices.isEmpty) {
        widget.onConsoleOutput('No ready devices found');
        _showAlert(
          context,
          'No Ready Devices',
          'No devices are ready for installation.\n\nPlease check device connection.',
          isError: true
        );
        return;
      }
      
      widget.onConsoleOutput('Found ${devices.length} device(s): ${devices.join(", ")}');
      
      // Determine which APK to install
      String? apkToInstall;
      
      // First check if there's a built APK
      if (widget.currentApkPath != null) {
        final modifiedApkPath = widget.currentApkPath!.replaceAll('.apk', '_modified.apk');
        if (await File(modifiedApkPath).exists()) {
          apkToInstall = modifiedApkPath;
          widget.onConsoleOutput('Installing modified APK: $modifiedApkPath');
        } else {
          apkToInstall = widget.currentApkPath;
          widget.onConsoleOutput('Installing original APK: ${widget.currentApkPath}');
        }
      }
      
      if (apkToInstall == null) {
        widget.onConsoleOutput('No APK file available for installation');
        _showAlert(
          context,
          'No APK Available',
          'No APK file selected. Please import an APK first.',
          isError: true
        );
        return;
      }
      
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Installing APK...'),
              ],
            ),
          );
        },
      );
      
      // Install on all connected devices
      bool allSuccess = true;
      String installLog = '';
      
      for (final device in devices) {
        widget.onConsoleOutput('Installing on device: $device');
        final installResult = await service.installApkOnDevice(apkToInstall, device);
        
        if (installResult.exitCode == 0) {
          widget.onConsoleOutput('Successfully installed on $device');
          installLog += 'Device $device: SUCCESS\n';
        } else {
          widget.onConsoleOutput('Failed to install on $device: ${installResult.stderr}');
          installLog += 'Device $device: FAILED - ${installResult.stderr}\n';
          allSuccess = false;
        }
      }
      
      // Close progress dialog
      Navigator.of(context).pop();
      
      // Show result
      if (allSuccess) {
        _showAlert(
          context,
          'Installation Successful',
          'APK installed successfully on all devices!\n\n$installLog',
          isError: false
        );
      } else {
        _showAlert(
          context,
          'Installation Completed with Errors',
          'Some installations failed:\n\n$installLog',
          isError: true
        );
      }
      
    } catch (e) {
      // Close progress dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      widget.onConsoleOutput('Error during installation: $e');
      _showAlert(
        context,
        'Installation Error',
        'An error occurred while installing APK:\n\n$e',
        isError: true
      );
    }
  }

  void _openInExplorer() async {
    try {
      if (widget.decompiledDirectory == null) {
        widget.onConsoleOutput('No APK has been decompiled yet');
        return;
      }
      
      widget.onConsoleOutput('Opening decompiled directory in file explorer...');
      await CommandExecutor.openFileExplorer(widget.decompiledDirectory!);
      widget.onConsoleOutput('File explorer opened: ${widget.decompiledDirectory}');
    } catch (e) {
      widget.onConsoleOutput('Error opening explorer: $e');
    }
  }

  void _openWithJDGui() async {
    try {
      if (widget.currentApkPath == null) {
        widget.onConsoleOutput('No APK file selected');
        return;
      }
      
      widget.onConsoleOutput('Opening JD-GUI with APK: ${widget.currentApkPath}');
      final service = ApkService.create();
      await service.openWithJDGui(widget.currentApkPath!);
      widget.onConsoleOutput('JD-GUI launched');
    } catch (e) {
      widget.onConsoleOutput('Error opening JD-GUI: $e');
    }
  }

  void _openWithVSCode() async {
    try {
      if (widget.decompiledDirectory == null) {
        widget.onConsoleOutput('No APK has been decompiled yet');
        return;
      }
      
      widget.onConsoleOutput('Opening VSCode with decompiled directory...');
      await CommandExecutor.executeCommand(ConfigManager.vscodePath, ['-r', widget.decompiledDirectory!]);
      widget.onConsoleOutput('VSCode opened: ${widget.decompiledDirectory}');
    } catch (e) {
      widget.onConsoleOutput('Error opening VSCode: $e');
    }
  }
  
  void _showAlert(BuildContext context, String title, String message, {required bool isError}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isError ? Icons.error : Icons.check_circle,
                color: isError ? Colors.red : Colors.green,
              ),
              SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
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
}