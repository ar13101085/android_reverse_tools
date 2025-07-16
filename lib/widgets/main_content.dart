import 'package:flutter/material.dart';
import 'apk_info_tab.dart';
import 'apk_tweaks_tab.dart';
import 'frida_tab.dart';
import 'adb_log_tab.dart';
import 'apk_import_widget.dart';
import '../services/apk_analyzer.dart';
import '../models/apk_info.dart';
import '../utils/config_manager.dart';

class MainContent extends StatefulWidget {
  final Function(String) onConsoleOutput;
  final Function(String?, String?) onPathsUpdated;

  MainContent({
    required this.onConsoleOutput,
    required this.onPathsUpdated,
  });

  @override
  _MainContentState createState() => _MainContentState();
}

class _MainContentState extends State<MainContent> {
  String? _selectedApkPath;
  bool _isApkImported = false;
  bool _isAnalyzing = false;
  ApkInfo? _apkInfo;
  ApkAnalyzer? _analyzer;

  @override
  Widget build(BuildContext context) {
    if (!_isApkImported) {
      return ApkImportWidget(
        onApkSelected: _handleApkSelected,
        onConsoleOutput: widget.onConsoleOutput,
      );
    }

    if (_isAnalyzing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing APK...'),
            SizedBox(height: 8),
            Text(
              'This may take a few minutes',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                    tabs: [
                      Tab(text: 'APK Info'),
                      Tab(text: 'APK Tweaks'),
                      Tab(text: 'Frida'),
                      Tab(text: 'ADB Log'),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.android, size: 16, color: Colors.green),
                            SizedBox(width: 4),
                            Text(
                              _selectedApkPath?.split('/').last ?? 'APK',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.close, size: 20),
                        onPressed: _resetApkSelection,
                        tooltip: 'Import different APK',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ApkInfoTab(
                  onConsoleOutput: widget.onConsoleOutput,
                  apkPath: _selectedApkPath,
                  apkInfo: _apkInfo,
                ),
                ApkTweaksTab(
                  onConsoleOutput: widget.onConsoleOutput,
                  initialApkPath: _selectedApkPath,
                  decompiledPath: _analyzer?.decompiledDirectory,
                ),
                FridaTab(onConsoleOutput: widget.onConsoleOutput),
                AdbLogTab(onConsoleOutput: widget.onConsoleOutput),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleApkSelected(String apkPath, bool freshExtraction) async {
    setState(() {
      _selectedApkPath = apkPath;
      _isApkImported = true;
      _isAnalyzing = true;
    });
    
    widget.onConsoleOutput('APK imported successfully: ${apkPath.split('/').last}');
    
    // Start APK analysis
    await _analyzeApk(apkPath, freshExtraction);
  }

  Future<void> _analyzeApk(String apkPath, bool freshExtraction) async {
    try {
      _analyzer = await ApkAnalyzer.create();
      
      final apkInfo = await _analyzer!.analyzeApk(apkPath, (progress) {
        widget.onConsoleOutput(progress);
      }, freshExtraction: freshExtraction);
      
      setState(() {
        _apkInfo = apkInfo;
        _isAnalyzing = false;
      });
      
      // Update parent with paths
      widget.onPathsUpdated(_selectedApkPath, _analyzer!.decompiledDirectory);
      
      widget.onConsoleOutput('APK analysis completed successfully!');
      
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      widget.onConsoleOutput('Error analyzing APK: $e');
    }
  }

  void _resetApkSelection() {
    setState(() {
      _selectedApkPath = null;
      _isApkImported = false;
      _isAnalyzing = false;
      _apkInfo = null;
      _analyzer = null;
    });
    widget.onPathsUpdated(null, null);
    widget.onConsoleOutput('APK selection reset. Ready for new import.');
  }
}