import 'package:flutter/material.dart';

class ArToolsTab extends StatefulWidget {
  final Function(String) onConsoleOutput;

  ArToolsTab({required this.onConsoleOutput});

  @override
  _ArToolsTabState createState() => _ArToolsTabState();
}

class _ArToolsTabState extends State<ArToolsTab> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AR Tools', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildToolCard(
                  'APK Analyzer',
                  'Analyze APK structure and components',
                  Icons.analytics,
                  () => widget.onConsoleOutput('APK Analyzer launched'),
                ),
                _buildToolCard(
                  'Certificate Viewer',
                  'View APK signing certificates',
                  Icons.security,
                  () => widget.onConsoleOutput('Certificate Viewer launched'),
                ),
                _buildToolCard(
                  'Manifest Editor',
                  'Edit AndroidManifest.xml',
                  Icons.edit_document,
                  () => widget.onConsoleOutput('Manifest Editor launched'),
                ),
                _buildToolCard(
                  'Resource Extractor',
                  'Extract APK resources',
                  Icons.folder_zip,
                  () => widget.onConsoleOutput('Resource Extractor launched'),
                ),
                _buildToolCard(
                  'String Decoder',
                  'Decode obfuscated strings',
                  Icons.text_fields,
                  () => widget.onConsoleOutput('String Decoder launched'),
                ),
                _buildToolCard(
                  'Native Library Analyzer',
                  'Analyze native libraries',
                  Icons.memory,
                  () => widget.onConsoleOutput('Native Library Analyzer launched'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(String title, String description, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.blue),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}