import 'package:flutter/material.dart';

class AppAnimations {
  AppAnimations._();

  // Standard durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);
  static const Duration spinner = Duration(milliseconds: 1500);
  static const Duration spinnerFull = Duration(milliseconds: 2000);
  static const Duration autoDismiss = Duration(seconds: 2);
  static const Duration fallbackTimeout = Duration(seconds: 10);

  // Standard curves
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve linear = Curves.linear;
}
