import 'package:flutter/material.dart';

class AdbLogTab extends StatefulWidget {
  final Function(String) onConsoleOutput;

  AdbLogTab({required this.onConsoleOutput});

  @override
  _AdbLogTabState createState() => _AdbLogTabState();
}

class _AdbLogTabState extends State<AdbLogTab> {
  final TextEditingController _filterController = TextEditingController();
  bool _isLogging = false;
  String _selectedLevel = 'Verbose';
  String _logContent = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Log Level:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: 10),
              DropdownButton<String>(
                value: _selectedLevel,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedLevel = newValue!;
                  });
                },
                items: <String>['Verbose', 'Debug', 'Info', 'Warning', 'Error']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              SizedBox(width: 20),
              Expanded(
                child: TextField(
                  controller: _filterController,
                  decoration: InputDecoration(
                    labelText: 'Filter (tag or text)',
                    hintText: 'Enter filter text...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: _isLogging ? _stopLogging : _startLogging,
                child: Text(_isLogging ? 'Stop Logging' : 'Start Logging'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: _clearLog,
                child: Text('Clear Log'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: _saveLog,
                child: Text('Save Log'),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8),
                  child: Text(
                    _logContent,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startLogging() {
    setState(() {
      _isLogging = true;
      _logContent = 'Starting ADB logging...\n';
    });
    
    widget.onConsoleOutput('ADB logging started');
    
    // Simulate log messages
    Future.delayed(Duration(seconds: 1), () {
      if (_isLogging) {
        setState(() {
          _logContent += '01-01 12:00:00.000  1234  1234 I MainActivity: Activity created\n';
          _logContent += '01-01 12:00:01.000  1234  1234 D NetworkManager: Network available\n';
          _logContent += '01-01 12:00:02.000  1234  1234 W SecurityManager: Permission requested\n';
          _logContent += '01-01 12:00:03.000  1234  1234 E FileManager: File not found\n';
        });
      }
    });
  }

  void _stopLogging() {
    setState(() {
      _isLogging = false;
      _logContent += 'ADB logging stopped.\n';
    });
    widget.onConsoleOutput('ADB logging stopped');
  }

  void _clearLog() {
    setState(() {
      _logContent = '';
    });
    widget.onConsoleOutput('Log cleared');
  }

  void _saveLog() {
    widget.onConsoleOutput('Log saved to file');
  }
}