import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:io';

class ApkImportWidget extends StatefulWidget {
  final Function(String, bool) onApkSelected;
  final Function(String) onConsoleOutput;

  ApkImportWidget({
    required this.onApkSelected,
    required this.onConsoleOutput,
  });

  @override
  _ApkImportWidgetState createState() => _ApkImportWidgetState();
}

class _ApkImportWidgetState extends State<ApkImportWidget> {
  bool _isDragging = false;
  String? _selectedApkPath;
  bool _freshExtraction = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: DropTarget(
        onDragEntered: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onDragExited: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        onDragDone: (details) {
          setState(() {
            _isDragging = false;
          });
          _handleDroppedFiles(details.files);
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _isDragging ? Colors.blue : Colors.grey[300]!,
              width: _isDragging ? 3 : 2,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(12),
            color: _isDragging ? Colors.blue.withOpacity(0.1) : Colors.grey[50],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.android,
                size: 120,
                color: _isDragging ? Colors.blue : Colors.grey[400],
              ),
              SizedBox(height: 24),
              Text(
                _isDragging ? 'Drop APK file here' : 'Import APK File',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _isDragging ? Colors.blue : Colors.grey[700],
                ),
              ),
              SizedBox(height: 16),
              if (_selectedApkPath != null) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Selected: ${_selectedApkPath!.split('/').last}',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                CheckboxListTile(
                  title: Text('Fresh Extraction'),
                  subtitle: Text('Re-decompile APK even if already extracted'),
                  value: _freshExtraction,
                  onChanged: (bool? value) {
                    setState(() {
                      _freshExtraction = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _proceedWithSelectedApk,
                      icon: Icon(Icons.arrow_forward),
                      label: Text('Proceed with APK'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _clearSelection,
                      icon: Icon(Icons.clear),
                      label: Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  'Drag and drop an APK file here\nor click below to browse',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _selectApkFile,
                  icon: Icon(Icons.folder_open),
                  label: Text('Browse APK File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                ),
              ],
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(height: 8),
                    Text(
                      'Supported Files',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'APK files (.apk)',
                      style: TextStyle(
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDroppedFiles(List<XFile> files) {
    if (files.isEmpty) return;

    final file = files.first;
    final fileName = file.name.toLowerCase();

    if (fileName.endsWith('.apk')) {
      setState(() {
        _selectedApkPath = file.path;
      });
      widget.onConsoleOutput('APK file dropped: ${file.name}');
    } else {
      widget.onConsoleOutput('Error: Only APK files are supported');
      _showErrorDialog('Invalid file type. Please select an APK file.');
    }
  }

  Future<void> _selectApkFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
      dialogTitle: 'Select APK File',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedApkPath = result.files.single.path;
      });
      widget.onConsoleOutput('APK file selected: ${result.files.single.name}');
    }
  }

  void _proceedWithSelectedApk() {
    if (_selectedApkPath != null) {
      widget.onApkSelected(_selectedApkPath!, _freshExtraction);
      widget.onConsoleOutput('Processing APK: ${_selectedApkPath!.split('/').last}');
      if (_freshExtraction) {
        widget.onConsoleOutput('Fresh extraction enabled - will re-decompile APK');
      } else {
        widget.onConsoleOutput('Using existing decompiled folder if available');
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedApkPath = null;
    });
    widget.onConsoleOutput('APK selection cleared');
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
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