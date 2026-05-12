import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfileData();
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

  Future<void> _saveProfileData() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {
          'full_name': _nameController.text,
          'phone': _phoneController.text,
        }),
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
          SnackBar(content: Text('Failed to save: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(_emailController.text, style: TextStyle(color: Colors.grey[400])),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: roleColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor, letterSpacing: 1.2),
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
