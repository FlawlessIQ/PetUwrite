import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/checkout_state.dart';
import '../services/draft_service.dart';
import '../services/user_session_service.dart';
import '../ui/tokens.dart';
import '../ui/components/checkout_components.dart';
import '../ui/components/max_width.dart';
import '../ui/components/save_resume_dialog.dart';

/// Step 2: Owner details form with e-sign consent
class OwnerDetailsScreen extends StatefulWidget {
  const OwnerDetailsScreen({super.key});

  @override
  State<OwnerDetailsScreen> createState() => OwnerDetailsScreenState();
}

class OwnerDetailsScreenState extends State<OwnerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  
  bool _hasESignConsent = false;
  bool _hasPrivacyConsent = false;
  
  @override
  void initState() {
    super.initState();
    _loadPendingCheckout();
    _loadUserProfile();
  }

  Future<void> _loadPendingCheckout() async {
    try {
      final pending = await UserSessionService().getPendingCheckout();
      final owner = pending?['ownerDetails'];
      if (owner is! Map) return;

      if (!mounted) return;
      setState(() {
        final data = owner.cast<String, dynamic>();
        _firstNameController.text = (data['firstName'] ?? '').toString();
        _lastNameController.text = (data['lastName'] ?? '').toString();
        _emailController.text = (data['email'] ?? '').toString();
        _phoneController.text = (data['phone'] ?? '').toString();
        _addressLine1Controller.text = (data['addressLine1'] ?? '').toString();
        _addressLine2Controller.text = (data['addressLine2'] ?? '').toString();
        _cityController.text = (data['city'] ?? '').toString();
        _stateController.text = (data['state'] ?? '').toString();
        _zipCodeController.text = (data['zipCode'] ?? '').toString();
        _hasESignConsent = data['hasESignConsent'] == true;
        _hasPrivacyConsent = data['hasPrivacyConsent'] == true;
      });
    } catch (e) {
      print('⚠️ Error loading pending checkout: $e');
    }
  }

  Map<String, dynamic> _buildOwnerDraft() {
    return {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'addressLine1': _addressLine1Controller.text.trim(),
      'addressLine2': _addressLine2Controller.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'zipCode': _zipCodeController.text.trim(),
      'hasESignConsent': _hasESignConsent,
      'hasPrivacyConsent': _hasPrivacyConsent,
      'savedAt': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _buildCheckoutSnapshot(CheckoutProvider provider) {
    return {
      'pet': provider.pet?.toJson(),
      'selectedPlan': provider.selectedPlan?.toJson(),
      'ownerDetails': _buildOwnerDraft(),
      'underwritingCaseId': provider.underwritingCaseId,
      'exclusions': provider.exclusions.map((e) => e.toJson()).toList(growable: false),
      'underwritingSnapshot': provider.underwritingSnapshot,
      'currentStep': 'ownerDetails',
      'savedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _saveAndFinishLater(BuildContext context) async {
    final provider = context.read<CheckoutProvider>();
    final snapshot = _buildCheckoutSnapshot(provider);

    await UserSessionService().savePendingCheckout(snapshot);
    await DraftService().upsertCheckoutDraft(
      state: 'CHECKOUT_OWNER',
      checkoutData: snapshot,
    );

    if (!mounted) return;
    final resumeKey = await DraftService().getOrCreateLocalResumeKey();
    final pretty = DraftService().prettyCode(resumeKey);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved. Resume code: $pretty')),
    );

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  Future<void> _copyResumeCodeToClipboard() async {
    await SaveResumeDialog.show(
      context,
      ensureSaved: () async {
        final provider = context.read<CheckoutProvider>();
        final snapshot = _buildCheckoutSnapshot(provider);
        await UserSessionService().savePendingCheckout(snapshot);
        await DraftService().upsertCheckoutDraft(
          state: 'CHECKOUT_OWNER',
          checkoutData: snapshot,
        );
      },
      title: 'Save & resume later',
      body:
          'We’ll save your owner details. Use this code to resume from the home page on any device.',
      copyLabel: 'Copy code',
      doneLabel: 'Done',
    );
  }
  
  /// Load user profile and pre-populate form fields
  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // Get user profile from Firestore
      final userProfile = await UserSessionService().getUserProfile();
      
      setState(() {
        // Pre-populate email from Firebase Auth
        _emailController.text = user.email ?? '';
        
        // Pre-populate name fields from profile
        final firstName = userProfile['firstName'] as String?;
        final lastName = userProfile['lastName'] as String?;
        
        if (firstName != null && firstName.isNotEmpty) {
          _firstNameController.text = firstName;
        }
        if (lastName != null && lastName.isNotEmpty) {
          _lastNameController.text = lastName;
        }
        
        // Pre-populate other profile fields if they exist
        final phone = userProfile['phone'] as String?;
        final zipCode = userProfile['zipCode'] as String?;
        final address = userProfile['address'] as String?;
        
        if (phone != null && phone.isNotEmpty) {
          _phoneController.text = phone;
        }
        if (zipCode != null && zipCode.isNotEmpty) {
          _zipCodeController.text = zipCode;
        }
        if (address != null && address.isNotEmpty) {
          _addressLine1Controller.text = address;
        }
      });
      
      print('✅ Pre-populated owner details from user profile');
    } catch (e) {
      print('⚠️ Error loading user profile: $e');
      // Fallback to just email from Firebase Auth
      if (user.email != null) {
        setState(() {
          _emailController.text = user.email!;
        });
      }
    }
  }
  
  /// Update user profile with form data for future pre-population
  Future<void> _updateUserProfile(OwnerDetails ownerDetails) async {
    try {
      await UserSessionService().updateUserProfile(
        firstName: ownerDetails.firstName,
        lastName: ownerDetails.lastName,
        phone: ownerDetails.phone,
        zipCode: ownerDetails.zipCode,
        address: ownerDetails.addressLine1,
      );
      print('✅ Updated user profile with owner details');
    } catch (e) {
      print('⚠️ Error updating user profile: $e');
      // Don't block the flow if profile update fails
    }
  }
  
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaxWidth(
      maxWidth: 960,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: 120, // Space for pinned CTA
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              Text(
                'Owner Information',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We\'ll use this to create your policy and send important updates',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Contact Information Card
              CheckoutCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Contact Information',
                      padding: const EdgeInsets.only(bottom: 20),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            decoration: checkoutInputDecoration(
                              label: 'First Name *',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter first name';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: checkoutInputDecoration(
                              label: 'Last Name *',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter last name';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: checkoutInputDecoration(
                        label: 'Email Address *',
                        hint: 'We\'ll send your policy documents here',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: checkoutInputDecoration(
                        label: 'Phone Number *',
                        hint: 'Format: (123) 456-7890',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter phone number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Billing Address Card
              CheckoutCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Billing Address',
                      padding: const EdgeInsets.only(bottom: 20),
                    ),
                    TextFormField(
                      controller: _addressLine1Controller,
                      decoration: checkoutInputDecoration(
                        label: 'Street Address *',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter street address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressLine2Controller,
                      decoration: checkoutInputDecoration(
                        label: 'Apt, Suite, etc. (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cityController,
                            decoration: checkoutInputDecoration(
                              label: 'City *',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _stateController,
                            decoration: checkoutInputDecoration(
                              label: 'State *',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _zipCodeController,
                            decoration: checkoutInputDecoration(
                              label: 'ZIP Code *',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Consent & Communications Card
              CheckoutCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Consent & Communications',
                      padding: const EdgeInsets.only(bottom: 16),
                    ),
                    
                    // E-Sign Consent
                    _buildConsentCheckbox(
                      value: _hasESignConsent,
                      onChanged: (value) {
                        setState(() {
                          _hasESignConsent = value ?? false;
                        });
                      },
                      label: 'I consent to using electronic signatures',
                      onLearnMore: () => _showESignTermsDialog(context),
                    ),
                    const SizedBox(height: 12),
                    
                    // Privacy Consent
                    _buildConsentCheckbox(
                      value: _hasPrivacyConsent,
                      onChanged: (value) {
                        setState(() {
                          _hasPrivacyConsent = value ?? false;
                        });
                      },
                      label: 'I agree to the Terms of Service and Privacy Policy',
                      onLearnMore: () => _showTermsDialog(context),
                    ),
                  ],
                ),
              ),
              
              // Error banner if consent not checked
              if (_showConsentError())
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: InlineBanner(
                    type: BannerType.error,
                    message: _getConsentErrorMessage(),
                  ),
                ),
              
              const SizedBox(height: 24),

              // Save & Resume Options
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TertiaryButton(
                    text: 'Save & finish later',
                    onPressed: () => _saveAndFinishLater(context),
                    icon: Icons.bookmark_outline,
                  ),
                  const SizedBox(width: 16),
                    TertiaryButton(
                      text: 'Save resume code',
                      onPressed: _copyResumeCodeToClipboard,
                      icon: Icons.bookmark_add_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsentCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    required VoidCallback onLearnMore,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadii.br12,
        border: value 
          ? Border.all(color: AppColors.green, width: 1.5)
          : Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.text,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onLearnMore,
                  child: Text(
                    'Learn more',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.green,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _showConsentError() {
    // Only show error if form has been attempted (add state tracking if needed)
    return false; // Will be handled by inline check on continue press
  }

  String _getConsentErrorMessage() {
    if (!_hasESignConsent && !_hasPrivacyConsent) {
      return 'Please accept both consent requirements to continue';
    } else if (!_hasESignConsent) {
      return 'Please accept the e-sign consent to continue';
    } else {
      return 'Please accept the Terms and Privacy Policy to continue';
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.green),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  /// Public method to handle continue action (called from parent checkout screen)
  Future<void> handleContinue(BuildContext context) async {
    return _handleContinue(context);
  }

  Future<void> _handleContinue(BuildContext context) async {
    print('🔍 _handleContinue called');
    print('🔍 Form valid: ${_formKey.currentState?.validate()}');
    print('🔍 E-sign consent: $_hasESignConsent');
    print('🔍 Privacy consent: $_hasPrivacyConsent');
    
    if (_formKey.currentState!.validate()) {
      print('✅ Form validation passed');
      
      if (!_hasESignConsent) {
        print('❌ E-sign consent not accepted');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please accept the e-sign consent to continue'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!_hasPrivacyConsent) {
        print('❌ Privacy consent not accepted');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please accept the Terms and Privacy Policy to continue'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print('✅ All validations passed, creating OwnerDetails');
      
      final ownerDetails = OwnerDetails(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        addressLine1: _addressLine1Controller.text,
        addressLine2: _addressLine2Controller.text,
        city: _cityController.text,
        state: _stateController.text,
        zipCode: _zipCodeController.text,
        hasESignConsent: _hasESignConsent,
        eSignConsentDate: DateTime.now(),
      );

      // Update user profile with the entered information for future use
      _updateUserProfile(ownerDetails);

      context.read<CheckoutProvider>().setOwnerDetails(ownerDetails);
      context.read<CheckoutProvider>().nextStep();

      // Persist draft at step transition so resume-by-code works even if the
      // user closes on the payment step.
      try {
        final provider = context.read<CheckoutProvider>();
        final snapshot = {
          'pet': provider.pet?.toJson(),
          'selectedPlan': provider.selectedPlan?.toJson(),
          'ownerDetails': {
            ...ownerDetails.toJson(),
            'hasPrivacyConsent': _hasPrivacyConsent,
          },
          'underwritingCaseId': provider.underwritingCaseId,
          'exclusions': provider.exclusions.map((e) => e.toJson()).toList(growable: false),
          'underwritingSnapshot': provider.underwritingSnapshot,
          'currentStep': 'payment',
          'savedAt': DateTime.now().toIso8601String(),
        };
        await UserSessionService().savePendingCheckout(snapshot);
        await DraftService().upsertCheckoutDraft(
          state: 'CHECKOUT_PAYMENT',
          checkoutData: snapshot,
        );
      } catch (e) {
        print('⚠️ Unable to persist checkout draft on continue: $e');
      }
    }
  }

  void _showESignTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Electronic Signature Terms'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'E-SIGN Consent and Disclosure',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                '1. Consent to Electronic Signatures\n\n'
                'By checking the E-Sign consent box, you agree that your electronic signature on this application and related documents is the legal equivalent of your handwritten signature.\n\n'
                '2. Scope of Consent\n\n'
                'This consent applies to:\n'
                '• Insurance applications and enrollment forms\n'
                '• Policy documents and endorsements\n'
                '• Billing and payment notices\n'
                '• Claims documents\n'
                '• Any other insurance-related communications\n\n'
                '3. Hardware and Software Requirements\n\n'
                '• A device with internet access\n'
                '• A current web browser (Chrome, Safari, Firefox, Edge)\n'
                '• Email account for receiving documents\n'
                '• PDF reader for viewing documents\n\n'
                '4. Withdrawing Consent\n\n'
                'You may withdraw your consent at any time by contacting us at support@petunderwriter.ai. Withdrawal will not affect the validity of prior electronic signatures.\n\n'
                '5. Obtaining Paper Copies\n\n'
                'You may request paper copies of any electronically signed documents at no charge by contacting customer service.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'Terms of Service\n\n'
            '1. Acceptance of Terms\n'
            'By using our services, you agree to be bound by these Terms of Service.\n\n'
            '2. Insurance Coverage\n'
            'Coverage is subject to policy terms, conditions, and exclusions. Please read your policy documents carefully.\n\n'
            '3. Premium Payments\n'
            'Premiums must be paid on time to maintain coverage. Non-payment may result in policy cancellation.\n\n'
            '4. Claims\n'
            'Claims must be submitted according to policy requirements with proper documentation.\n\n'
            '5. Cancellation\n'
            'You may cancel your policy at any time. Refunds are provided according to policy terms.\n\n'
            '6. Modifications\n'
            'We reserve the right to modify these terms. You will be notified of any changes.\n\n'
            'For full Terms of Service, visit: www.petunderwriter.ai/terms',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Privacy Policy\n\n'
            '1. Information We Collect\n'
            '• Personal information (name, address, contact details)\n'
            '• Pet information (name, breed, age, medical history)\n'
            '• Payment information (processed securely through Stripe)\n'
            '• Usage data and analytics\n\n'
            '2. How We Use Your Information\n'
            '• To provide insurance coverage and process claims\n'
            '• To communicate about your policy\n'
            '• To improve our services\n'
            '• To comply with legal requirements\n\n'
            '3. Information Sharing\n'
            'We do not sell your personal information. We may share data with:\n'
            '• Service providers (payment processors, email services)\n'
            '• Veterinary clinics (for claims processing)\n'
            '• Legal authorities (when required by law)\n\n'
            '4. Data Security\n'
            'We use industry-standard security measures to protect your information.\n\n'
            '5. Your Rights\n'
            'You have the right to access, correct, or delete your personal information.\n\n'
            'For full Privacy Policy, visit: www.petunderwriter.ai/privacy',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
