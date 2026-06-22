import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_assets.dart';
import '../core/app_breakpoints.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // Slow cinematic zoom
    )..repeat(reverse: true); // Zoom in and out infinitely

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');

    if (savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in both email and password.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Artificial delay to simulate network request for polish
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    final errorMsg = await context.read<AuthProvider>().login(email, password);

    setState(() => _isLoading = false);

    if (errorMsg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
      );
    } else if (errorMsg == null) {
      // Success! Handle remember me.
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', email);
        await prefs.setString('saved_password', password);
      } else {
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
      }
    }
    // If successful, the AuthProvider state change will automatically route
    // the user to the MainShell via main.dart's Consumer.
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog(BuildContext ctx) {
    final emailCtrl = TextEditingController();
    bool isSubmitting = false;
    bool submitted = false;
    String? error;

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF181818),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
          ),
          title: Row(
            children: [
              Icon(
                submitted ? Icons.check_circle : Icons.lock_reset,
                color: submitted ? Colors.green : const Color(0xFFD4AF37),
              ),
              const SizedBox(width: 12),
              Text(
                submitted ? 'Request Submitted' : 'Forgot Password',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: submitted
              ? const Text(
                  'Your password reset request has been submitted.\n\n'
                  'An administrator will review and approve it. You will receive '
                  'a reset link via email once approved.',
                  style: TextStyle(color: Colors.grey, height: 1.5),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your account email address. A password reset request will be sent to the system administrator for approval.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Colors.grey,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
          actions: [
            if (!submitted)
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            if (!submitted)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          setDialogState(
                            () => error = 'Please enter a valid email address.',
                          );
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = true;
                          error = null;
                        });
                        final err = await context
                            .read<AuthProvider>()
                            .submitPasswordResetRequest(email);
                        setDialogState(() {
                          isSubmitting = false;
                          if (err != null) {
                            error = err;
                          } else {
                            submitted = true;
                          }
                        });
                      },
                child: isSubmitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black,
                          ),
                        ),
                      )
                    : const Text(
                        'Submit Request',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            if (submitted)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(
        0xFF050505,
      ), // Very dark background behind the card
      body: Stack(
        children: [
          // Background Image with Zoom Animation
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: const AssetImage('assets/images/login_bg.jpg'),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(
                            0.5,
                          ), // Dark overlay so the card pops
                          BlendMode.darken,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Foreground Login Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Builder(
                builder: (context) {
                  final isDesktop =
                      MediaQuery.of(context).size.width >=
                      AppBreakpoints.loginSplitMin;
                  return Container(
                    width: isDesktop ? 900 : double.infinity,
                    constraints: BoxConstraints(minHeight: isDesktop ? 500 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.8),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Flex(
                      direction: isDesktop ? Axis.horizontal : Axis.vertical,
                      children: [
                        // Left Side (Logo and Branding)
                        Flexible(
                          flex: isDesktop ? 1 : 0,
                          fit: isDesktop ? FlexFit.tight : FlexFit.loose,
                          child: Container(
                            width: isDesktop ? null : double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            color: const Color(0xFF151515),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  AppAssets.logo,
                                  height: isDesktop ? 250 : 150,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                        Icons.security,
                                        size: isDesktop ? 250 : 150,
                                        color: Colors.amber,
                                      ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Welcome Back',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 2.0,
                                        fontSize: isDesktop ? 24 : 20,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please sign in to continue',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Right Side (Login Form)
                        Flexible(
                          flex: isDesktop ? 1 : 0,
                          fit: isDesktop ? FlexFit.tight : FlexFit.loose,
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 15.0,
                                sigmaY: 15.0,
                              ),
                              child: Container(
                                color: Colors.black.withOpacity(0.6),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isDesktop ? 60 : 24,
                                  vertical: 40,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Sign In',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                    ),
                                    const SizedBox(height: 32),

                                    // Email Field
                                    const Text(
                                      'Email Address',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _emailController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Enter your email',
                                        hintStyle: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(
                                          0.05,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: theme.primaryColor,
                                          ),
                                        ),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 24),

                                    // Password Field
                                    const Text(
                                      'Password',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _passwordController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        hintText: 'Enter your password',
                                        hintStyle: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(
                                          0.05,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: theme.primaryColor,
                                          ),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: Colors.grey,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Remember Me & Forgot Password Row
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: Checkbox(
                                                value: _rememberMe,
                                                onChanged: (val) => setState(
                                                  () => _rememberMe =
                                                      val ?? false,
                                                ),
                                                activeColor: theme.primaryColor,
                                                checkColor: Colors.black,
                                                side: const BorderSide(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Remember me',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              _showForgotPasswordDialog(
                                                context,
                                              ),
                                          child: Text(
                                            'Forgot password?',
                                            style: TextStyle(
                                              color: theme.primaryColor,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),

                                    // Login Button
                                    SizedBox(
                                      height: 50,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.primaryColor,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: _isLoading
                                            ? null
                                            : _handleLogin,
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.black),
                                                ),
                                              )
                                            : const Text(
                                                'SIGN IN',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
