import 'package:flutter/material.dart';
import '../services/apk_modifier.dart';

class ApkTweaksTab extends StatefulWidget {
  final Function(String) onConsoleOutput;
  final String? initialApkPath;
  final String? decompiledPath;

  ApkTweaksTab({
    required this.onConsoleOutput, 
    this.initialApkPath,
    this.decompiledPath,
  });

  @override
  _ApkTweaksTabState createState() => _ApkTweaksTabState();
}

class _ApkTweaksTabState extends State<ApkTweaksTab> {
  String? _selectedApkPath;
  String? _decompiledPath;
  bool _isChecking = true;
  bool _isApplying = false;
  
  // Tweak states
  bool _debugMode = false;
  bool _fridaGadget = false;
  bool _mitm = false;
  bool _signatureBypass = false;
  bool _sslBypass = false;
  
  // Track which tweaks are already applied
  Map<String, bool> _appliedTweaks = {};

  @override
  void initState() {
    super.initState();
    _selectedApkPath = widget.initialApkPath;
    _decompiledPath = widget.decompiledPath;
    _checkAppliedTweaks();
  }

  @override
  void didUpdateWidget(ApkTweaksTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialApkPath != oldWidget.initialApkPath || 
        widget.decompiledPath != oldWidget.decompiledPath) {
      _selectedApkPath = widget.initialApkPath;
      _decompiledPath = widget.decompiledPath;
      _checkAppliedTweaks();
    }
  }

  Future<void> _checkAppliedTweaks() async {
    if (_selectedApkPath == null || _decompiledPath == null) {
      setState(() {
        _isChecking = false;
      });
      return;
    }

    setState(() {
      _isChecking = true;
    });

    try {
      // Check which tweaks are already applied
      final modifier = ApkModifier(
        decompiledPath: _decompiledPath!,
        onProgress: widget.onConsoleOutput,
      );
      
      final appliedTweaks = await modifier.checkAppliedTweaks();
      
      setState(() {
        _appliedTweaks = appliedTweaks;
        _debugMode = appliedTweaks['debugMode'] ?? false;
        _fridaGadget = appliedTweaks['fridaGadget'] ?? false;
        _mitm = appliedTweaks['mitm'] ?? false;
        _signatureBypass = appliedTweaks['signatureBypass'] ?? false;
        _sslBypass = appliedTweaks['sslBypass'] ?? false;
        _isChecking = false;
      });
      
      widget.onConsoleOutput('Checked existing APK modifications');
    } catch (e) {
      setState(() {
        _isChecking = false;
      });
      widget.onConsoleOutput('Error checking APK modifications: $e');
    }
  }

  Future<void> _applyTweaks() async {
    if (_decompiledPath == null) {
      widget.onConsoleOutput('No decompiled APK found');
      return;
    }

    setState(() {
      _isApplying = true;
    });

    try {
      final modifier = ApkModifier(
        decompiledPath: _decompiledPath!,
        onProgress: widget.onConsoleOutput,
      );

      bool success = true;

      // Apply selected tweaks
      if (_debugMode && !(_appliedTweaks['debugMode'] ?? false)) {
        success &= await modifier.enableDebugMode();
      }

      if (_fridaGadget && !(_appliedTweaks['fridaGadget'] ?? false)) {
        success &= await modifier.injectFridaGadget();
      }

      if (_mitm && !(_appliedTweaks['mitm'] ?? false)) {
        success &= await modifier.enableMitm();
      }

      if (_signatureBypass && !(_appliedTweaks['signatureBypass'] ?? false)) {
        success &= await modifier.applySignatureBypass();
      }

      if (_sslBypass && !(_appliedTweaks['sslBypass'] ?? false)) {
        success &= await modifier.applySslBypass();
      }

      if (success) {
        widget.onConsoleOutput('All selected tweaks applied successfully!');
        // Refresh the applied tweaks status
        await _checkAppliedTweaks();
      } else {
        widget.onConsoleOutput('Some tweaks failed to apply. Check the console for details.');
      }
    } catch (e) {
      widget.onConsoleOutput('Error applying tweaks: $e');
    } finally {
      setState(() {
        _isApplying = false;
      });
    }
  }

  bool _hasChanges() {
    return (_debugMode != (_appliedTweaks['debugMode'] ?? false)) ||
           (_fridaGadget != (_appliedTweaks['fridaGadget'] ?? false)) ||
           (_mitm != (_appliedTweaks['mitm'] ?? false)) ||
           (_signatureBypass != (_appliedTweaks['signatureBypass'] ?? false)) ||
           (_sslBypass != (_appliedTweaks['sslBypass'] ?? false));
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking APK modifications...'),
          ],
        ),
      );
    }

    if (_selectedApkPath == null || _decompiledPath == null) {
      return Center(
        child: Text(
          'Please import and decompile an APK first',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'APK Modifications:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Check the modifications you want to apply:',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            
            CheckboxListTile(
              title: Text('Enable Debug Mode'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adds android:debuggable="true" to AndroidManifest.xml'),
                  if (_appliedTweaks['debugMode'] == true)
                    Text(
                      'Already applied',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                ],
              ),
              value: _debugMode,
              onChanged: _isApplying ? null : (value) {
                setState(() {
                  _debugMode = value!;
                });
              },
            ),
            
            CheckboxListTile(
              title: Text('Inject Frida Gadget'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Injects Frida gadget for runtime instrumentation'),
                  if (_appliedTweaks['fridaGadget'] == true)
                    Text(
                      'Already applied',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                ],
              ),
              value: _fridaGadget,
              onChanged: _isApplying ? null : (value) {
                setState(() {
                  _fridaGadget = value!;
                });
              },
            ),
            
            CheckboxListTile(
              title: Text('Enable MITM'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Configures network security for MITM attacks'),
                  if (_appliedTweaks['mitm'] == true)
                    Text(
                      'Already applied',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                ],
              ),
              value: _mitm,
              onChanged: _isApplying ? null : (value) {
                setState(() {
                  _mitm = value!;
                });
              },
            ),
            
            CheckboxListTile(
              title: Text('Signature Bypass'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Implements signature verification bypass'),
                  Text(
                    'Requires nkstool.jar in tools directory',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
              value: _signatureBypass,
              onChanged: _isApplying ? null : (value) {
                setState(() {
                  _signatureBypass = value!;
                });
              },
            ),
            
            CheckboxListTile(
              title: Text('SSL Bypass'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SSL certificate pinning bypass'),
                  Text(
                    'Not implemented yet',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
              value: _sslBypass,
              enabled: false,
              onChanged: null,
            ),
            
            SizedBox(height: 24),
            
            Center(
              child: ElevatedButton.icon(
                onPressed: (_isApplying || !_hasChanges()) ? null : _applyTweaks,
                icon: _isApplying 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.build),
                label: Text(_isApplying ? 'Applying Tweaks...' : 'Apply Tweaks'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
            
            if (!_hasChanges() && !_isApplying)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    'No new tweaks selected',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}