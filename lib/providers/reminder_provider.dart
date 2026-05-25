import 'package:flutter/material.dart';
import '../models/reminder_log.dart';
import '../services/payment_reminder_service.dart';

/// Provides reminder state to the UI: delivery stats, history, manual trigger.
class ReminderProvider with ChangeNotifier {
  final _service = PaymentReminderService.instance;

  bool _isLoading = false;
  bool _isSending = false;
  Map<String, int> _deliveryStats = {};
  List<ReminderLogModel> _vendorHistory = [];
  String? _lastError;

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  Map<String, int> get deliveryStats => _deliveryStats;
  List<ReminderLogModel> get vendorHistory => _vendorHistory;
  String? get lastError => _lastError;

  int get totalSent =>
      (_deliveryStats['Email_sent'] ?? 0) +
      (_deliveryStats['WhatsApp_sent'] ?? 0) +
      (_deliveryStats['SMS_sent'] ?? 0);

  int get totalFailed =>
      (_deliveryStats['Email_failed'] ?? 0) +
      (_deliveryStats['WhatsApp_failed'] ?? 0) +
      (_deliveryStats['SMS_failed'] ?? 0);

  int get totalDelivered =>
      (_deliveryStats['Email_delivered'] ?? 0) +
      (_deliveryStats['WhatsApp_delivered'] ?? 0) +
      (_deliveryStats['SMS_delivered'] ?? 0);

  /// Fetch today's delivery stats for the dashboard preview.
  Future<void> fetchDeliveryStats() async {
    _isLoading = true;
    notifyListeners();

    try {
      _deliveryStats = await _service.fetchDeliveryStats();
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch reminder history for a specific vendor.
  Future<void> fetchVendorHistory(String vendorId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _vendorHistory = await _service.fetchReminderHistory(vendorId);
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Manually trigger the initial (08:00) reminder pass from the admin UI.
  Future<bool> triggerInitialReminders() async {
    return _trigger(() => _service.sendInitialReminders());
  }

  /// Manually trigger the follow-up (18:00) reminder pass from the admin UI.
  Future<bool> triggerFollowUpReminders() async {
    return _trigger(() => _service.sendFollowUpReminders());
  }

  Future<bool> _trigger(Future<ReminderSummary> Function() fn) async {
    if (_isSending) return false;

    _isSending = true;
    _lastError = null;
    notifyListeners();

    try {
      await fn();
      await fetchDeliveryStats();
      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isSending = false;
      notifyListeners();
      return false;
    }
  }
}
