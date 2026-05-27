import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/inactivity_timeout_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String _displayName = 'User';
  bool _isSaving = false;

  // Timeout settings state
  int _timeoutMinutes = 15;
  bool _timeoutDisabled = false;
  bool _isSavingTimeout = false;

  static const List<int> _timeoutOptions = [5, 10, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadTimeoutPreference();
  }

  Future<void> _loadProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final metadata = user.userMetadata ?? {};
      setState(() {
        _emailController.text = user.email ?? 'Unknown Email';
        final savedName = metadata['full_name'] as String?;
        final savedPhone = metadata['phone'] as String?;
        if (savedName != null && savedName.isNotEmpty) {
          _nameController.text = savedName;
          _displayName = savedName;
        } else {
          _nameController.text = user.email?.split('@').first ?? 'User';
          _displayName = _nameController.text;
        }
        if (savedPhone != null && savedPhone.isNotEmpty) {
          _phoneController.text = savedPhone;
        }
      });
    }
  }

  Future<void> _loadTimeoutPreference() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('timeout_minutes, timeout_disabled')
          .eq('id', user.id)
          .maybeSingle();
      if (data != null) {
        setState(() {
          _timeoutMinutes = data['timeout_minutes'] as int? ?? 15;
          _timeoutDisabled = data['timeout_disabled'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveProfileData() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': _nameController.text,
            'phone': _phoneController.text,
          },
        ),
      );
      setState(() => _displayName = _nameController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveTimeoutPreference() async {
    if (_isSavingTimeout) return;
    setState(() => _isSavingTimeout = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('profiles').update({
        'timeout_minutes': _timeoutDisabled ? null : _timeoutMinutes,
        'timeout_disabled': _timeoutDisabled,
      }).eq('id', user.id);

      await InactivityTimeoutService.instance.refreshPreference();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timeout settings saved.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save timeout settings: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingTimeout = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  static const Map<String, Color> _roleColors = {
    'Super Admin': Color(0xFFD4AF37),
    'Admin': Color(0xFF4FC3F7),
    'Finance': Color(0xFF81C784),
    'Marketing': Color(0xFFBA68C8),
    'Development Facilitator': Color(0xFFFFB74D),
    'Verifying Operator': Color(0xFF4DB6AC),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final role = authProvider.userRole;
    final roleColor = _roleColors[role] ?? theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Preferences'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: roleColor.withOpacity(0.1),
                        child: Icon(Icons.person, size: 50, color: roleColor),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _displayName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _emailController.text,
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: roleColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // Details Form
                Text(
                  'Personal Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Full Name',
                  _nameController,
                  Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Email Address',
                  _emailController,
                  Icons.email_outlined,
                  enabled: false,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Phone Number',
                  _phoneController,
                  Icons.phone_outlined,
                ),
                const SizedBox(height: 40),

                // Security Section
                Text(
                  'Security',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      color: Theme.of(context).iconTheme.color,
                    ),
                  ),
                  title: const Text('Change Password'),
                  subtitle: const Text('Update your password securely'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Password reset link sent to your email.',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Timeout Settings Section
                Text(
                  'Session Timeout',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Automatically log out after a period of inactivity.',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),

                // Disable timeout toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Disable timeout',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    _timeoutDisabled
                        ? 'Session will not expire due to inactivity'
                        : 'Session will expire after the selected duration',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  value: _timeoutDisabled,
                  activeColor: theme.primaryColor,
                  onChanged: (val) => setState(() => _timeoutDisabled = val),
                ),

                if (!_timeoutDisabled) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _timeoutOptions.contains(_timeoutMinutes)
                        ? _timeoutMinutes
                        : 15,
                    dropdownColor: Theme.of(context).cardColor,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Timeout Duration',
                      labelStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(),
                    ),
                    items: _timeoutOptions.map((minutes) {
                      return DropdownMenuItem(
                        value: minutes,
                        child: Text('$minutes minute${minutes == 1 ? '' : 's'}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _timeoutMinutes = val);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isSavingTimeout ? null : _saveTimeoutPreference,
                    child: _isSavingTimeout
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black,
                              ),
                            ),
                          )
                        : const Text(
                            'Save Timeout Settings',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 1.1,
                            ),
                          ),
                  ),
                ),
                Divider(
                  height: 48,
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isSaving ? null : _saveProfileData,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black,
                              ),
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 1.1,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(color: enabled ? Colors.white : Colors.grey),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: enabled
            ? Theme.of(context).cardColor
            : Theme.of(context).scaffoldBackgroundColor,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
      ),
    );
  }
}
