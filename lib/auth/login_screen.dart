import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/tokens.dart';
import '../services/app_analytics_service.dart';
import '../services/user_session_service.dart';
import '../ui/components/clovara_logo.dart';

/// Phone number input formatter
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (text.length <= 3) {
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } else if (text.length <= 6) {
      final formatted = '(${text.substring(0, 3)}) ${text.substring(3)}';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    } else if (text.length <= 10) {
      final formatted =
          '(${text.substring(0, 3)}) ${text.substring(3, 6)}-${text.substring(6)}';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    } else {
      final formatted =
          '(${text.substring(0, 3)}) ${text.substring(3, 6)}-${text.substring(6, 10)}';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }
}

/// Clovara branded login screen with prominent logo
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _isSignUp = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _isSignUp = _tabController.index == 1;
        _errorMessage = null;
        _clearFormFields();
      });
    });
  }

  void _clearFormFields() {
    _emailController.clear();
    _passwordController.clear();
    _firstNameController.clear();
    _lastNameController.clear();
    _phoneController.clear();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _closeOrRedirectAfterAuth() {
    if (!mounted) return;

    // This screen is used in two ways:
    // 1) As a pushed Material route (e.g. checkout gating) -> pop back.
    // 2) As a top-level go_router route (/sign-in) -> popping would empty the
    //    router stack and crash; redirect to the authenticated app shell.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    context.go('/app');
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    unawaited(
      AppAnalyticsService.instance.track(
        'sign_in_started',
        properties: {'method': 'email_password', 'surface': 'login_screen'},
      ),
    );

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Pop back after successful sign-in to let AuthGate handle navigation
      // Migrate any locally saved pending quote for this user, then pop back.
      try {
        await UserSessionService().migratePendingQuoteOnSignIn();
      } catch (e) {
        print('Error migrating pending quote after sign-in: $e');
      }

      unawaited(
        AppAnalyticsService.instance.track(
          'sign_in_success',
          properties: {'method': 'email_password', 'surface': 'login_screen'},
        ),
      );

      _closeOrRedirectAfterAuth();
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error - Code: ${e.code}, Message: ${e.message}');
      unawaited(
        AppAnalyticsService.instance.track(
          'sign_in_failed',
          properties: {
            'method': 'email_password',
            'code': e.code,
            'surface': 'login_screen',
          },
        ),
      );
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      print('Unexpected Error during sign in: $e');
      unawaited(
        AppAnalyticsService.instance.track(
          'sign_in_failed',
          properties: {
            'method': 'email_password',
            'code': 'unexpected',
            'surface': 'login_screen',
          },
        ),
      );
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    unawaited(
      AppAnalyticsService.instance.track(
        'sign_up_started',
        properties: {'method': 'email_password', 'surface': 'login_screen'},
      ),
    );

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print(
        'Attempting to create user with email: ${_emailController.text.trim()}',
      );
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      print('User created successfully: ${credential.user!.uid}');

      // Create comprehensive user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
            'email': _emailController.text.trim(),
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'userRole': 0, // Customer role
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'isEmailVerified': false,
            'isPhoneVerified': false,
          });

      print('User document created in Firestore');
      unawaited(
        AppAnalyticsService.instance.track(
          'sign_up_success',
          properties: {'method': 'email_password', 'surface': 'login_screen'},
        ),
      );

      // Pop back after successful sign-up to let AuthGate handle navigation
      _closeOrRedirectAfterAuth();
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error - Code: ${e.code}, Message: ${e.message}');
      unawaited(
        AppAnalyticsService.instance.track(
          'sign_up_failed',
          properties: {
            'method': 'email_password',
            'code': e.code,
            'surface': 'login_screen',
          },
        ),
      );
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      print('Unexpected Error during signup: $e');
      unawaited(
        AppAnalyticsService.instance.track(
          'sign_up_failed',
          properties: {
            'method': 'email_password',
            'code': 'unexpected',
            'surface': 'login_screen',
          },
        ),
      );
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'The password must be at least 6 characters.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 760;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 48,
                    vertical: isMobile ? 20 : 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context, isMobile),
                      SizedBox(height: isMobile ? 36 : 64),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: isMobile
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildAccessPanel(isMobile),
                                    const SizedBox(height: 28),
                                    _buildAuthStack(isMobile),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: _buildAccessPanel(isMobile),
                                    ),
                                    const SizedBox(width: 56),
                                    Expanded(child: _buildAuthStack(isMobile)),
                                  ],
                                ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 40 : 64),
                      _buildFooter(context, isMobile),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAuthStack(bool isMobile) {
    return Column(
      children: [
        _buildAuthCard(isMobile),
        const SizedBox(height: 20),
        if (!_isSignUp) _buildAdditionalActions(),
      ],
    );
  }

  Widget _buildAccessPanel(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Secure account access',
          style: GoogleFonts.dmSans(
            color: AppColors.green,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'One sign-in for policies, claims, and operations.',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.text,
            fontSize: isMobile ? 38 : 54,
            fontWeight: FontWeight.w700,
            height: 1.02,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Customers land in policy management. Clovara operators are routed to the operations dashboard automatically based on account role.',
          style: GoogleFonts.dmSans(
            color: AppColors.textSubtle,
            fontSize: 16,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _TrustPill(icon: Icons.policy_outlined, label: 'Policy portal'),
            _TrustPill(icon: Icons.receipt_long_outlined, label: 'Claims'),
            _TrustPill(icon: Icons.admin_panel_settings_outlined, label: 'Ops'),
          ],
        ),
      ],
    );
  }

  /// Header with Clovara logo matching homepage
  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const ClovaraLogo(size: ClovaraLogoSize.medium, showText: true),
        ],
      ),
    );
  }

  Widget _buildAuthCard(bool isMobile) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isMobile ? 500 : 520),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.br20,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.green,
                indicatorWeight: 4,
                labelColor: AppColors.deepGreen,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(text: 'Sign In'),
                  Tab(text: 'Create Account'),
                ],
              ),
            ),

            // Form Content - White card inside gradient
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.all(isMobile ? 24.0 : 40.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Error Message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Sign Up Fields (First Name, Last Name, Phone)
                    if (_isSignUp) ...[
                      // First Name Field
                      TextFormField(
                        controller: _firstNameController,
                        keyboardType: TextInputType.name,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.green,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: _isSignUp
                            ? (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your first name';
                                }
                                if (value.length < 2) {
                                  return 'First name must be at least 2 characters';
                                }
                                return null;
                              }
                            : null,
                        enabled: !_isLoading,
                      ),

                      const SizedBox(height: 16),

                      // Last Name Field
                      TextFormField(
                        controller: _lastNameController,
                        keyboardType: TextInputType.name,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.green,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: _isSignUp
                            ? (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your last name';
                                }
                                if (value.length < 2) {
                                  return 'Last name must be at least 2 characters';
                                }
                                return null;
                              }
                            : null,
                        enabled: !_isLoading,
                      ),

                      const SizedBox(height: 16),

                      // Phone Number Field
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 16),
                        inputFormatters: [
                          PhoneNumberFormatter(),
                          LengthLimitingTextInputFormatter(
                            14,
                          ), // (123) 456-7890
                        ],
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          hintText: '(555) 123-4567',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.green,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: _isSignUp
                            ? (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                // Basic phone validation - at least 10 digits
                                final digitsOnly = value.replaceAll(
                                  RegExp(r'[^\d]'),
                                  '',
                                );
                                if (digitsOnly.length < 10) {
                                  return 'Please enter a valid phone number';
                                }
                                return null;
                              }
                            : null,
                        enabled: !_isLoading,
                      ),

                      const SizedBox(height: 16),
                    ],

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.green,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                      enabled: !_isLoading,
                    ),

                    const SizedBox(height: 20),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.green,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (_isSignUp) {
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          if (!RegExp(
                            r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)',
                          ).hasMatch(value)) {
                            return 'Password must contain uppercase, lowercase, and numbers';
                          }
                        } else if (value.length < 6) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                      enabled: !_isLoading,
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_isSignUp) {
                                  _signUp();
                                } else {
                                  _signIn();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.deepGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.deepGreen
                              .withOpacity(0.45),
                          disabledForegroundColor: Colors.white.withOpacity(
                            0.9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isSignUp ? 'Create Account' : 'Sign In',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 20),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalActions() {
    return TextButton(
      onPressed: _isLoading ? null : () => _showForgotPasswordDialog(),
      child: Text(
        'Forgot Password?',
        style: TextStyle(
          color: AppColors.green,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Footer section
  Widget _buildFooter(BuildContext context, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        children: [
          // Copyright
          Text(
            '© 2026 FlawlessIQ Inc. • Clovara',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSubtle,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a password reset link.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty && email.contains('@')) {
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: email,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset email sent!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_getErrorMessage(e.code)),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.green),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
