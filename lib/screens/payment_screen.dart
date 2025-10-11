import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/checkout_state.dart';
import '../services/stripe_service.dart';

/// Step 3: Payment screen with Stripe integration
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  String? _errorMessage;
  final _stripeService = StripeService();

  @override
  Widget build(BuildContext context) {
    return Consumer<CheckoutProvider>(
      builder: (context, provider, child) {
        final plan = provider.selectedPlan!;
        final ownerDetails = provider.ownerDetails!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payment',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Secure payment powered by Stripe',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),

              // Order Summary Card
              _buildOrderSummary(plan, ownerDetails),
              const SizedBox(height: 24),

              // Payment Information Card
              _buildPaymentInfoCard(),
              const SizedBox(height: 24),

              // Security Info
              _buildSecurityInfo(),
              const SizedBox(height: 24),

              // Error Message
              if (_errorMessage != null) ...[
                _buildErrorMessage(),
                const SizedBox(height: 16),
              ],

              // Navigation Buttons
              _buildNavigationButtons(context, provider, plan),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderSummary(plan, ownerDetails) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Plan', plan.name),
            const SizedBox(height: 12),
            _buildSummaryRow('Policy Holder', ownerDetails.fullName),
            const SizedBox(height: 12),
            _buildSummaryRow('Email', ownerDetails.email),
            const Divider(height: 32),
            _buildSummaryRow(
              'Monthly Premium',
              '\$${plan.monthlyPremium.toStringAsFixed(2)}',
              isBold: true,
            ),
            if (plan.multiPetDiscount > 0) ...[
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Multi-pet Discount',
                '-\$${plan.discountAmount.toStringAsFixed(2)}',
                isDiscount: true,
              ),
            ],
            const Divider(height: 32),
            _buildSummaryRow(
              'Total Due Today',
              '\$${plan.monthlyPremium.toStringAsFixed(2)}',
              isTotal: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Coverage starts immediately after payment',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card, size: 24, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/visa.png',
                        height: 32,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.credit_card, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Image.asset(
                        'assets/images/mastercard.png',
                        height: 32,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.credit_card, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Image.asset(
                        'assets/images/amex.png',
                        height: 32,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.credit_card, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Image.asset(
                        'assets/images/discover.png',
                        height: 32,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.credit_card, size: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Click "Pay Now" to enter card details',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Stripe will securely collect your payment information. Your card details are never stored on our servers.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.lock, color: Colors.green.shade700, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Payment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your payment is encrypted and secure. We use industry-standard SSL encryption and are PCI DSS compliant.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: Colors.red.shade700,
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context, CheckoutProvider provider, plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isProcessing
                    ? null
                    : () {
                        provider.previousStep();
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
                onPressed: _isProcessing ? null : () => _handlePayment(context, provider, plan),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline),
                          const SizedBox(width: 8),
                          Text(
                            'Pay \$${plan.monthlyPremium.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/stripe-badge.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) =>
                  Text(
                    'Powered by Stripe',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, bool isTotal = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal || isBold ? FontWeight.bold : FontWeight.normal,
            color: isDiscount ? Colors.green.shade700 : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 24 : (isBold ? 16 : 14),
            fontWeight: isTotal || isBold ? FontWeight.bold : FontWeight.w600,
            color: isTotal
                ? Colors.blue.shade700
                : (isDiscount ? Colors.green.shade700 : null),
          ),
        ),
      ],
    );
  }

  Future<void> _handlePayment(BuildContext context, CheckoutProvider provider, plan) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create payment intent
      final policyId = 'policy_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final paymentIntentData = await _stripeService.createPaymentIntent(
        amount: plan.monthlyPremium,
        currency: 'usd',
        policyId: policyId,
      );

      // Initialize payment sheet
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['clientSecret'],
          merchantDisplayName: 'Pet Underwriter AI',
          customerId: paymentIntentData['customerId'],
          customerEphemeralKeySecret: paymentIntentData['ephemeralKey'],
          style: ThemeMode.system,
          appearance: const stripe.PaymentSheetAppearance(
            colors: stripe.PaymentSheetAppearanceColors(
              primary: Colors.blue,
            ),
          ),
        ),
      );

      // Present payment sheet
      await stripe.Stripe.instance.presentPaymentSheet();

      // Payment successful
      final paymentInfo = PaymentInfo(
        paymentIntentId: paymentIntentData['paymentIntentId'],
        paymentMethodId: paymentIntentData['paymentMethodId'],
        amount: plan.monthlyPremium,
        currency: 'usd',
        status: 'succeeded',
        paidAt: DateTime.now(),
        last4: paymentIntentData['last4'],
        brand: paymentIntentData['brand'],
      );

      provider.setPaymentInfo(paymentInfo);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Payment successful!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Move to next step
      await Future.delayed(const Duration(milliseconds: 500));
      provider.nextStep();

    } on stripe.StripeException catch (e) {
      setState(() {
        _errorMessage = e.error.message ?? 'Payment failed. Please try again.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
