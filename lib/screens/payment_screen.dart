import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  bool _isValidatingCoupon = false;
  String? _errorMessage;
  String? _couponError;
  final _stripeService = StripeService();
  final _couponController = TextEditingController();
  
  // Coupon state
  bool _isCouponApplied = false;
  double _discountAmount = 0.0;
  String? _appliedCouponCode;
  bool _bypassPayment = false; // For TEST100 coupon
  
  // Stripe card field controller
  stripe.CardFieldInputDetails? _cardFieldDetails;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    
    if (code.isEmpty) {
      setState(() {
        _couponError = 'Please enter a coupon code';
      });
      return;
    }

    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
    });

    try {
      // Check for TEST100 special code
      if (code == 'TEST100') {
        setState(() {
          _isCouponApplied = true;
          _appliedCouponCode = code;
          _bypassPayment = true;
          _discountAmount = 0.0; // Not used when bypassing
          _isValidatingCoupon = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Test coupon applied - Payment bypassed'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Validate coupon with Stripe via Cloud Function
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await http.post(
        Uri.parse('https://us-central1-pet-underwriter-ai.cloudfunctions.net/validateCoupon'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'couponCode': code,
          'userId': user.uid,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['valid'] == true) {
          setState(() {
            _isCouponApplied = true;
            _appliedCouponCode = code;
            _discountAmount = (data['discountAmount'] ?? 0.0).toDouble();
            _bypassPayment = false;
            _isValidatingCoupon = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Coupon applied! Save \$${_discountAmount.toStringAsFixed(2)}'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          setState(() {
            _couponError = data['message'] ?? 'Invalid coupon code';
            _isValidatingCoupon = false;
          });
        }
      } else {
        throw Exception('Failed to validate coupon');
      }
    } catch (e) {
      setState(() {
        _couponError = 'Error validating coupon. Please try again.';
        _isValidatingCoupon = false;
      });
    }
  }

  void _removeCoupon() {
    setState(() {
      _isCouponApplied = false;
      _appliedCouponCode = null;
      _discountAmount = 0.0;
      _bypassPayment = false;
      _couponError = null;
      _couponController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coupon removed'),
        duration: Duration(seconds: 2),
      ),
    );
  }

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
    final double finalAmount = _bypassPayment ? 0.0 : (plan.monthlyPremium - _discountAmount);
    
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
            if (_isCouponApplied && _discountAmount > 0) ...[
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Coupon Discount',
                '-\$${_discountAmount.toStringAsFixed(2)}',
                isDiscount: true,
              ),
            ],
            const Divider(height: 32),
            _buildSummaryRow(
              'Total Due Today',
              _bypassPayment ? '\$0.00 (Waived)' : '\$${finalAmount.toStringAsFixed(2)}',
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
            
            // Coupon Code Field
            _buildCouponCodeField(),
            const SizedBox(height: 20),
            
            // Only show card input if not bypassing payment
            if (!_bypassPayment) ...[
              // Stripe Card Field (Native only - not supported on web yet)
              if (!kIsWeb)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: stripe.CardField(
                    onCardChanged: (card) {
                      setState(() {
                        _cardFieldDetails = card;
                      });
                    },
                    enablePostalCode: true,
                    autofocus: false,
                  ),
                ),
              // Web placeholder - Stripe Elements will be integrated separately
              if (kIsWeb)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.credit_card, size: 48, color: Colors.blue.shade700),
                      const SizedBox(height: 16),
                      Text(
                        'Web Payment Coming Soon',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Payment processing on web is currently in development. Please use the mobile app or contact support@petuwrite.com to complete your purchase.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Copy email to clipboard or open email client
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email: support@petuwrite.com'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                        icon: const Icon(Icons.email),
                        label: const Text('Contact Support'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.credit_card, size: 20, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Visa • Mastercard • Amex • Discover',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Stripe will securely collect your payment information. Your card details are never stored on our servers.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ] else ...[
              // Show message when payment is bypassed
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Waived',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Test coupon applied - no payment required',
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
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCouponCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coupon Code (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _couponController,
                enabled: !_isCouponApplied && !_isValidatingCoupon,
                decoration: InputDecoration(
                  hintText: 'Enter coupon code',
                  prefixIcon: Icon(
                    _isCouponApplied ? Icons.check_circle : Icons.local_offer,
                    color: _isCouponApplied ? Colors.green : Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: _isCouponApplied ? Colors.green.shade50 : Colors.grey.shade50,
                  errorText: _couponError,
                  suffixIcon: _isCouponApplied
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: _removeCoupon,
                          color: Colors.grey.shade600,
                        )
                      : null,
                ),
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _applyCoupon(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isCouponApplied || _isValidatingCoupon ? null : _applyCoupon,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                backgroundColor: _isCouponApplied ? Colors.green : Colors.blue,
              ),
              child: _isValidatingCoupon
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(_isCouponApplied ? 'Applied' : 'Apply'),
            ),
          ],
        ),
        if (_isCouponApplied && _appliedCouponCode != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _bypassPayment
                        ? 'Test coupon applied - Payment waived for testing'
                        : 'Coupon "$_appliedCouponCode" applied - Save \$${_discountAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
    final double finalAmount = _bypassPayment ? 0.0 : (plan.monthlyPremium - _discountAmount);
    
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
                          Icon(_bypassPayment ? Icons.check_circle_outline : Icons.lock_outline),
                          const SizedBox(width: 8),
                          Text(
                            _bypassPayment ? 'Complete Setup' : 'Pay \$${finalAmount.toStringAsFixed(2)}',
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
            Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              'Secure payment powered by Stripe',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
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

      // If payment is bypassed (TEST100), skip Stripe and proceed
      if (_bypassPayment) {
        final paymentInfo = PaymentInfo(
          paymentIntentId: 'test_${DateTime.now().millisecondsSinceEpoch}',
          paymentMethodId: 'test_payment_method',
          amount: 0.0,
          currency: 'usd',
          status: 'test_waived',
          paidAt: DateTime.now(),
          last4: '0000',
          brand: 'Test',
          couponCode: _appliedCouponCode,
        );

        provider.setPaymentInfo(paymentInfo);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Test mode - Payment bypassed!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        await Future.delayed(const Duration(milliseconds: 500));
        provider.nextStep();
        return;
      }

      // On web, payment is not yet supported - show error
      if (kIsWeb) {
        throw Exception('Payment processing is not yet available on web. Please use the mobile app or contact support.');
      }
      
      // Validate card details are entered (mobile only)
      if (_cardFieldDetails == null || !_cardFieldDetails!.complete) {
        throw Exception('Please enter complete card details');
      }

      // Calculate final amount with discount
      final double finalAmount = plan.monthlyPremium - _discountAmount;

      // Create payment intent
      final policyId = 'policy_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final paymentIntentData = await _stripeService.createPaymentIntent(
        amount: finalAmount,
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
        amount: finalAmount,
        currency: 'usd',
        status: 'succeeded',
        paidAt: DateTime.now(),
        last4: paymentIntentData['last4'],
        brand: paymentIntentData['brand'],
        couponCode: _appliedCouponCode,
        discountAmount: _discountAmount,
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
