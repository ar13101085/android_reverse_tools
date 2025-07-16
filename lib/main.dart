import 'package:flutter/material.dart';
import 'package:desktop_window/desktop_window.dart';
import 'screens/main_screen.dart';
import 'utils/config_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize configuration and tools
    print('Initializing AR-MITM-FRIDA...');
    await ConfigManager.initialize();
    await ConfigManager.createWorkingDirectory();
    
    // Validate tools exist
    await ConfigManager.validateToolsExist();
    
    // Print configuration in debug mode
    ConfigManager.printConfig();
    
    await DesktopWindow.setWindowSize(Size(1200, 800));
    await DesktopWindow.setMinWindowSize(Size(1000, 700));
    await DesktopWindow.setMaxWindowSize(Size(1400, 1000));
    
    print('Initialization complete!');
    
  } catch (e) {
    print('Error during initialization: $e');
    // Continue with app launch even if some initialization fails
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR-MITM-FRIDA',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}