import 'dart:collection';

// Console logger singleton that integrates with the existing console
class ConsoleLogger {
  static final List<void Function()> _listeners = [];
  static final Queue<String> _logQueue = Queue<String>();
  static const int _maxQueueSize = 1000;
  static void Function(String)? _consoleOutputCallback;
  
  // Set the callback to the main console output function
  static void setConsoleOutputCallback(void Function(String) callback) {
    _consoleOutputCallback = callback;
  }
  
  static void log(String message) {
    // Add timestamp
    final timestamp = DateTime.now().toString().split('.')[0];
    final logMessage = '[$timestamp] $message';
    
    // Add to queue
    _logQueue.add(logMessage);
    if (_logQueue.length > _maxQueueSize) {
      _logQueue.removeFirst();
    }
    
    // Send to console output if callback is set
    if (_consoleOutputCallback != null) {
      _consoleOutputCallback!(logMessage);
    }
    
    // Notify listeners
    for (final listener in _listeners) {
      listener();
    }
  }
  
  static void addListener(void Function() listener) {
    _listeners.add(listener);
  }
  
  static void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }
  
  static List<String> getLogs() {
    return _logQueue.toList();
  }
  
  static void clearLogs() {
    _logQueue.clear();
  }
}