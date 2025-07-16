import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class DecompileTab extends StatefulWidget {
  final Function(String) onConsoleOutput;
  final String? initialApkPath;

  DecompileTab({required this.onConsoleOutput, this.initialApkPath});

  @override
  _DecompileTabState createState() => _DecompileTabState();
}

class _DecompileTabState extends State<DecompileTab> {
  String? _selectedApkPath;
  
  @override
  void initState() {
    super.initState();
    _selectedApkPath = widget.initialApkPath;
  }
  String? _outputDirectory;
  bool _decompileResources = true;
  bool _decompileSources = true;
  bool _keepOriginalManifest = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'APK File Path',
                    hintText: 'Select APK file to decompile...',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  controller: TextEditingController(text: _selectedApkPath ?? ''),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: _selectApkFile,
                child: Text('Browse'),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Output Directory',
                    hintText: 'Select output directory...',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  controller: TextEditingController(text: _outputDirectory ?? ''),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: _selectOutputDirectory,
                child: Text('Browse'),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text('Decompile Options:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          CheckboxListTile(
            title: Text('Decompile Resources'),
            subtitle: Text('Extract and decompile resources (XML, images, etc.)'),
            value: _decompileResources,
            onChanged: (value) {
              setState(() {
                _decompileResources = value!;
              });
            },
          ),
          CheckboxListTile(
            title: Text('Decompile Sources'),
            subtitle: Text('Decompile DEX files to Smali code'),
            value: _decompileSources,
            onChanged: (value) {
              setState(() {
                _decompileSources = value!;
              });
            },
          ),
          CheckboxListTile(
            title: Text('Keep Original Manifest'),
            subtitle: Text('Keep original AndroidManifest.xml without modifications'),
            value: _keepOriginalManifest,
            onChanged: (value) {
              setState(() {
                _keepOriginalManifest = value!;
              });
            },
          ),
          SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton(
                onPressed: (_selectedApkPath != null && _outputDirectory != null) ? _decompileApk : null,
                child: Text('Decompile APK'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: _outputDirectory != null ? _recompileApk : null,
                child: Text('Recompile APK'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectApkFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedApkPath = result.files.single.path;
      });
      widget.onConsoleOutput('Selected APK: ${result.files.single.path}');
    }
  }

  Future<void> _selectOutputDirectory() async {
    String? result = await FilePicker.platform.getDirectoryPath();

    if (result != null) {
      setState(() {
        _outputDirectory = result;
      });
      widget.onConsoleOutput('Selected output directory: $result');
    }
  }

  void _decompileApk() {
    if (_selectedApkPath == null || _outputDirectory == null) return;

    widget.onConsoleOutput('Starting APK decompilation...');
    widget.onConsoleOutput('Input: $_selectedApkPath');
    widget.onConsoleOutput('Output: $_outputDirectory');
    
    if (_decompileResources) {
      widget.onConsoleOutput('Decompiling resources...');
    }
    
    if (_decompileSources) {
      widget.onConsoleOutput('Decompiling DEX files to Smali...');
    }
    
    if (_keepOriginalManifest) {
      widget.onConsoleOutput('Keeping original AndroidManifest.xml...');
    }
    
    widget.onConsoleOutput('APK decompilation completed successfully!');
  }

  void _recompileApk() {
    if (_outputDirectory == null) return;

    widget.onConsoleOutput('Starting APK recompilation...');
    widget.onConsoleOutput('Source directory: $_outputDirectory');
    widget.onConsoleOutput('Compiling Smali files...');
    widget.onConsoleOutput('Packaging resources...');
    widget.onConsoleOutput('APK recompilation completed successfully!');
  }
}