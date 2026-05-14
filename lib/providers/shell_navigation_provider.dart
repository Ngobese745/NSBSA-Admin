import 'package:flutter/material.dart';

class ShellNavigationProvider with ChangeNotifier {
  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  // Helper to find the correct index by title if needed, 
  // but let's stick to indices for now for simplicity.
}
