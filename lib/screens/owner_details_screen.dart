import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/checkout_state.dart';

/// Step 2: Owner details form with e-sign consent
class OwnerDetailsScreen extends StatefulWidget {
  const OwnerDetailsScreen({super.key});

  @override
  State<OwnerDetailsScreen> createState() => _OwnerDetailsScreenState();
}

class _OwnerDetailsScreenState extends State<OwnerDetailsScreen> {
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Owner Information',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please provide your contact and address information',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),

            // Personal Information Section
            _buildSectionHeader('Personal Information', Icons.person),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
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
                    decoration: const InputDecoration(
                      labelText: 'Last Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
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
              decoration: const InputDecoration(
                labelText: 'Email Address *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
                helperText: 'We\'ll send your policy documents here',
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
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
                helperText: 'Format: (123) 456-7890',
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Address Section
            _buildSectionHeader('Billing Address', Icons.home),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressLine1Controller,
              decoration: const InputDecoration(
                labelText: 'Street Address *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
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
              decoration: const InputDecoration(
                labelText: 'Apt, Suite, etc. (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City *',
                      border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: 'State *',
                      border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: 'ZIP *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.length != 5) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // E-Sign Consent Section
            _buildSectionHeader('Electronic Signature Consent', Icons.draw),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _hasESignConsent ? Colors.green : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      value: _hasESignConsent,
                      onChanged: (value) {
                        setState(() => _hasESignConsent = value!);
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'I agree to use electronic signatures',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'By checking this box, I consent to electronically sign this insurance application and related documents. I understand that my electronic signature has the same legal effect as a handwritten signature.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _showESignTermsDialog(context),
                      icon: const Icon(Icons.article_outlined),
                      label: const Text('View full E-Sign Terms'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Privacy Policy Consent
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _hasPrivacyConsent ? Colors.green : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      value: _hasPrivacyConsent,
                      onChanged: (value) {
                        setState(() => _hasPrivacyConsent = value!);
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'I agree to the Terms of Service and Privacy Policy',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'I have read and agree to the Terms of Service and Privacy Policy. I understand how my personal information will be collected, used, and protected.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _showTermsDialog(context),
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('Terms of Service'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _showPrivacyDialog(context),
                          icon: const Icon(Icons.privacy_tip_outlined),
                          label: const Text('Privacy Policy'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Navigation Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      context.read<CheckoutProvider>().previousStep();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _hasESignConsent && _hasPrivacyConsent
                        ? () => _handleContinue(context)
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Continue to Payment',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 28, color: Colors.blue.shade700),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _handleContinue(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      if (!_hasESignConsent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please accept the e-sign consent to continue'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!_hasPrivacyConsent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please accept the Terms and Privacy Policy to continue'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

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

      context.read<CheckoutProvider>().setOwnerDetails(ownerDetails);
      context.read<CheckoutProvider>().nextStep();
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
