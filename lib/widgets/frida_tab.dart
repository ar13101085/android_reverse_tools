import 'package:flutter/material.dart';

class FridaTab extends StatefulWidget {
  final Function(String) onConsoleOutput;

  FridaTab({required this.onConsoleOutput});

  @override
  _FridaTabState createState() => _FridaTabState();
}

class _FridaTabState extends State<FridaTab> {
  final TextEditingController _packageNameController = TextEditingController();
  final TextEditingController _scriptController = TextEditingController();
  bool _isConnected = false;
  String _selectedDevice = 'No device selected';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Device: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(child: Text(_selectedDevice)),
              ElevatedButton(
                onPressed: _refreshDevices,
                child: Text('Refresh'),
              ),
            ],
          ),
          SizedBox(height: 16),
          TextField(
            controller: _packageNameController,
            decoration: InputDecoration(
              labelText: 'Package Name',
              hintText: 'com.example.app',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: _isConnected ? _disconnect : _connect,
                child: Text(_isConnected ? 'Disconnect' : 'Connect'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isConnected ? _spawn : null,
                child: Text('Spawn'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isConnected ? _attach : null,
                child: Text('Attach'),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text('Frida Script:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _scriptController,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: 'Enter your Frida script here...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: _isConnected ? _executeScript : null,
                child: Text('Execute Script'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: _loadSampleScript,
                child: Text('Load Sample'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _refreshDevices() {
    widget.onConsoleOutput('Refreshing devices...');
    setState(() {
      _selectedDevice = 'Device: SM-G975F (Android 11)';
    });
    widget.onConsoleOutput('Found device: SM-G975F');
  }

  void _connect() {
    if (_packageNameController.text.isEmpty) {
      widget.onConsoleOutput('Please enter a package name');
      return;
    }

    widget.onConsoleOutput('Connecting to Frida server...');
    setState(() {
      _isConnected = true;
    });
    widget.onConsoleOutput('Connected to Frida server');
  }

  void _disconnect() {
    widget.onConsoleOutput('Disconnecting from Frida server...');
    setState(() {
      _isConnected = false;
    });
    widget.onConsoleOutput('Disconnected from Frida server');
  }

  void _spawn() {
    widget.onConsoleOutput('Spawning process: ${_packageNameController.text}');
    widget.onConsoleOutput('Process spawned successfully');
  }

  void _attach() {
    widget.onConsoleOutput('Attaching to process: ${_packageNameController.text}');
    widget.onConsoleOutput('Attached to process successfully');
  }

  void _executeScript() {
    if (_scriptController.text.isEmpty) {
      widget.onConsoleOutput('Please enter a script to execute');
      return;
    }

    widget.onConsoleOutput('Executing Frida script...');
    widget.onConsoleOutput('Script executed successfully');
  }

  void _loadSampleScript() {
    setState(() {
      _scriptController.text = '''
Java.perform(function() {
    var Activity = Java.use("android.app.Activity");
    Activity.onCreate.implementation = function(savedInstanceState) {
        console.log("Activity.onCreate called");
        this.onCreate(savedInstanceState);
    };
    
    var Log = Java.use("android.util.Log");
    Log.d.implementation = function(tag, msg) {
        console.log("[" + tag + "] " + msg);
        return this.d(tag, msg);
    };
});
''';
    });
    widget.onConsoleOutput('Sample script loaded');
  }
}