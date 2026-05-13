import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketingProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> get campaigns => _campaigns;

  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> get templates => _templates;

  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> get leads => _leads;

  List<Map<String, dynamic>> _optOuts = [];
  List<Map<String, dynamic>> get optOuts => _optOuts;

  Future<void> fetchCampaigns() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _supabase
          .from('marketing_campaigns')
          .select()
          .order('created_at', ascending: false);
      _campaigns = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching campaigns: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTemplates() async {
    try {
      final response = await _supabase
          .from('marketing_templates')
          .select()
          .order('name');
      _templates = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching templates: $e');
    }
  }

  Future<void> fetchLeads() async {
    try {
      final response = await _supabase
          .from('marketing_leads')
          .select()
          .order('created_at', ascending: false);
      _leads = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching leads: $e');
    }
  }

  Future<void> createCampaign(Map<String, dynamic> campaignData) async {
    try {
      await _supabase.from('marketing_campaigns').insert(campaignData);
      await fetchCampaigns();
    } catch (e) {
      debugPrint('Error creating campaign: $e');
      rethrow;
    }
  }

  Future<void> createTemplate(Map<String, dynamic> templateData) async {
    try {
      await _supabase.from('marketing_templates').insert(templateData);
      await fetchTemplates();
    } catch (e) {
      debugPrint('Error creating template: $e');
      rethrow;
    }
  }

  Future<void> addLead(Map<String, dynamic> leadData) async {
    try {
      await _supabase.from('marketing_leads').insert(leadData);
      await fetchLeads();
    } catch (e) {
      debugPrint('Error adding lead: $e');
      rethrow;
    }
  }

  Future<void> updateLeadStatus(String leadId, String status) async {
    try {
      final updates = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (status == 'converted') {
        updates['converted_at'] = DateTime.now().toIso8601String();
      }
      await _supabase.from('marketing_leads').update(updates).eq('id', leadId);
      await fetchLeads();
    } catch (e) {
      debugPrint('Error updating lead status: $e');
      rethrow;
    }
  }

  Future<void> logInteraction({
    required String type,
    String? campaignId,
    String? vendorId,
    String? leadId,
    required String status,
    String? error,
  }) async {
    try {
      await _supabase.from('marketing_logs').insert({
        'campaign_id': campaignId,
        'vendor_id': vendorId,
        'lead_id': leadId,
        'type': type,
        'status': status,
        'error_message': error,
      });
    } catch (e) {
      debugPrint('Error logging interaction: $e');
    }
  }
}
