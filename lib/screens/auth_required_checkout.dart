import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_screen.dart';
import 'checkout_screen.dart';

/// Wrapper that ensures user is authenticated before accessing checkout
class AuthRequiredCheckout extends StatelessWidget {
  final dynamic pet;
  final dynamic selectedPlan;

  const AuthRequiredCheckout({
    super.key,
    required this.pet,
    required this.selectedPlan,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is authenticated - show checkout
        if (snapshot.hasData) {
          return CheckoutScreen(
            pet: pet,
            selectedPlan: selectedPlan,
          );
        }

        // User not authenticated - show login required screen
        return _LoginRequiredScreen(
          pet: pet,
          selectedPlan: selectedPlan,
        );
      },
    );
  }
}

/// Screen prompting user to login or create account before checkout
class _LoginRequiredScreen extends StatelessWidget {
  final dynamic pet;
  final dynamic selectedPlan;

  const _LoginRequiredScreen({
    required this.pet,
    required this.selectedPlan,
  });

  // Helper methods to safely extract data from dynamic types
  String _getPlanName(dynamic plan) {
    if (plan == null) return 'Unknown Plan';
    if (plan is Map) return plan['name']?.toString() ?? 'Unknown Plan';
    try {
      return plan.name?.toString() ?? 'Unknown Plan';
    } catch (e) {
      return 'Unknown Plan';
    }
  }

  String _getPetName(dynamic petData) {
    if (petData == null) return 'your pet';
    if (petData is Map) return petData['petName']?.toString() ?? petData['name']?.toString() ?? 'your pet';
    try {
      return petData.name?.toString() ?? 'your pet';
    } catch (e) {
      return 'your pet';
    }
  }

  String _getMonthlyPrice(dynamic plan) {
    if (plan == null) return '0.00';
    if (plan is Map) {
      final price = plan['monthlyPrice'] ?? plan['monthlyPremium'];
      if (price != null) return price.toStringAsFixed(2);
    }
    try {
      final price = plan.monthlyPrice ?? plan.monthlyPremium;
      if (price != null) return price.toStringAsFixed(2);
    } catch (e) {
      // Try alternate property name
      try {
        if (plan.monthlyPremium != null) return plan.monthlyPremium.toStringAsFixed(2);
      } catch (e2) {
        // Ignore
      }
    }
    return '0.00';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In Required'),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Sign In to Continue',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'Create an account or sign in to complete your purchase and manage your policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),

              // Plan summary card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Selected Plan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getPlanName(selectedPlan),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'For ${_getPetName(pet)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '\$${_getMonthlyPrice(selectedPlan)}/mo',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Sign in / Create account button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Navigate to login screen
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                    // After login, pop back - StreamBuilder will auto-redirect to checkout
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Sign In or Create Account',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Why sign in section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Why create an account?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildBenefitItem('Manage your policies online'),
                    _buildBenefitItem('File claims easily'),
                    _buildBenefitItem('Track your pet\'s coverage'),
                    _buildBenefitItem('Access 24/7 customer support'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
