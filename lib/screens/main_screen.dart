import 'package:flutter/material.dart';
import '../widgets/sidebar.dart';
import '../widgets/main_content.dart';
import '../widgets/console_panel.dart';
import '../widgets/console_output.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String _consoleOutput = '';
  String? _currentApkPath;
  String? _decompiledDirectory;
  
  @override
  void initState() {
    super.initState();
    // Connect ConsoleLogger to the existing console output
    ConsoleLogger.setConsoleOutputCallback(_addToConsole);
    
    // Load any existing logs from ConsoleLogger
    final existingLogs = ConsoleLogger.getLogs();
    if (existingLogs.isNotEmpty) {
      setState(() {
        _consoleOutput = existingLogs.join('\n') + '\n';
      });
    }
  }
  
  void _addToConsole(String text) {
    setState(() {
      _consoleOutput += text + '\n';
    });
  }
  
  void _clearConsole() {
    setState(() {
      _consoleOutput = '';
      ConsoleLogger.clearLogs();
    });
  }
  
  void _updatePaths(String? apkPath, String? decompiledDir) {
    setState(() {
      _currentApkPath = apkPath;
      _decompiledDirectory = decompiledDir;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SideBar(
            onConsoleOutput: _addToConsole,
            currentApkPath: _currentApkPath,
            decompiledDirectory: _decompiledDirectory,
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  flex: 7,
                  child: MainContent(
                    onConsoleOutput: _addToConsole,
                    onPathsUpdated: _updatePaths,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: ConsolePanel(
                    output: _consoleOutput,
                    onClear: _clearConsole,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}