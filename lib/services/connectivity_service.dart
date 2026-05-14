import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum AppConnectivityStatus {
  online,
  offline,
}

class ConnectivityService {
  final _connectivity = Connectivity();
  final _controller = StreamController<AppConnectivityStatus>.broadcast();
  AppConnectivityStatus _currentStatus = AppConnectivityStatus.online;

  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal() {
    _connectivity.onConnectivityChanged.listen(_updateStatus);
    _initConnectivity();
  }

  Stream<AppConnectivityStatus> get statusStream => _controller.stream;
  AppConnectivityStatus get currentStatus => _currentStatus;

  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
    } catch (e) {
      debugPrint('Connectivity Error: $e');
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // If any result is not 'none', we are online
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    final newStatus = isOnline ? AppConnectivityStatus.online : AppConnectivityStatus.offline;
    
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _controller.add(_currentStatus);
      debugPrint('Connectivity Status Changed: $_currentStatus');
    }
  }

  void dispose() {
    _controller.close();
  }
}
