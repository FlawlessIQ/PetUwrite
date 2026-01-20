import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/checkout_state.dart';
import '../services/draft_service.dart';
import '../services/quote_engine.dart';
import '../services/stripe_service.dart';
import '../services/user_session_service.dart';
import '../services/marketing_attribution_service.dart';

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

  // Exclusions acknowledgement (if any exclusions exist)
  bool _exclusionsAcknowledged = false;
  String _exclusionsKey = '';

  // Coupon state
  bool _isCouponApplied = false;
  double _discountAmount = 0.0;
  String? _appliedCouponCode;
  bool _bypassPayment = false; // For TEST100 coupon

  // Stripe card field controller
  stripe.CardFieldInputDetails? _cardFieldDetails;

  @override
  void initState() {
    super.initState();
    _loadPendingCheckoutPaymentState();
  }

  Future<void> _loadPendingCheckoutPaymentState() async {
    try {
      final pending = await UserSessionService().getPendingCheckout();
      final payment = pending?['payment'];
      if (payment is! Map) return;

      final data = payment.cast<String, dynamic>();
      final coupon = (data['couponCode'] ?? '').toString();
      final discount = data['discountAmount'];

      if (!mounted) return;
      setState(() {
        if (coupon.trim().isNotEmpty) {
          _couponController.text = coupon.trim();
          _appliedCouponCode = coupon.trim().toUpperCase();
          _isCouponApplied = data['isCouponApplied'] == true;
        }
        _discountAmount = (discount is num)
            ? discount.toDouble()
            : _discountAmount;
        _bypassPayment = data['bypassPayment'] == true;
        _exclusionsAcknowledged = data['exclusionsAcknowledged'] == true;
      });
    } catch (e) {
      print('⚠️ Error loading pending payment state: $e');
    }
  }

  Map<String, dynamic> _buildPaymentDraft(CheckoutProvider provider, plan) {
    return {
      'couponCode': _appliedCouponCode,
      'isCouponApplied': _isCouponApplied,
      'discountAmount': _discountAmount,
      'bypassPayment': _bypassPayment,
      'exclusionsAcknowledged': _exclusionsAcknowledged,
      'exclusionsKey': _exclusionsKey,
      'planAmount': (plan is Plan) ? plan.monthlyPremium : null,
      'savedAt': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _buildCheckoutSnapshot(CheckoutProvider provider, plan) {
    return {
      'pet': provider.pet?.toJson(),
      'selectedPlan': provider.selectedPlan?.toJson(),
      'ownerDetails': provider.ownerDetails?.toJson(),
      'underwritingCaseId': provider.underwritingCaseId,
      'exclusions': provider.exclusions
          .map((e) => e.toJson())
          .toList(growable: false),
      'underwritingSnapshot': provider.underwritingSnapshot,
      'currentStep': 'payment',
      'payment': _buildPaymentDraft(provider, plan),
      'savedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _saveAndFinishLater(
    BuildContext context,
    CheckoutProvider provider,
    plan,
  ) async {
    final snapshot = _buildCheckoutSnapshot(provider, plan);

    await UserSessionService().savePendingCheckout(snapshot);
    await DraftService().upsertCheckoutDraft(
      state: 'CHECKOUT_PAYMENT',
      checkoutData: snapshot,
    );

    if (!mounted) return;
    final resumeKey = await DraftService().getOrCreateLocalResumeKey();
    final pretty = DraftService().prettyCode(resumeKey);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved. Resume code: $pretty')));

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  Future<void> _copyResumeCodeToClipboard() async {
    try {
      final draftService = DraftService();
      final resumeKey = await draftService.getOrCreateLocalResumeKey();
      await Clipboard.setData(
        ClipboardData(text: draftService.encodeForSharing(resumeKey)),
      );

      if (!mounted) return;
      final pretty = draftService.prettyCode(resumeKey);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Resume code copied: $pretty')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to copy resume code')),
      );
    }
  }

  String _computeExclusionsKey(List exclusions) {
    final names =
        exclusions
            .map((e) {
              if (e is String) return e;
              try {
                final conditionName = (e as dynamic).conditionName?.toString();
                if (conditionName != null && conditionName.trim().isNotEmpty) {
                  return conditionName;
                }
              } catch (_) {
                // ignore
              }
              return e.toString();
            })
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names.join('|');
  }

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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final provider = context.read<CheckoutProvider>();
      final plan = provider.selectedPlan;
      final owner = provider.ownerDetails;
      final amount = (plan is Plan) ? plan.monthlyPremium : null;

      await MarketingAttributionService().ensureSessionStarted();

      final callable = FirebaseFunctions.instance.httpsCallable(
        'validatePromotionCode',
      );
      final response = await callable.call({
        'code': code,
        if (amount != null) 'amount': amount,
        'currency': 'usd',
        'sessionId': MarketingAttributionService().sessionId,
        if (owner != null) 'state': owner.state,
      });

      final data = (response.data is Map)
          ? (response.data as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      if (data['valid'] == true) {
        final bypassPayment = data['bypassPayment'] == true;
        final discount = (data['discountAmount'] is num)
            ? (data['discountAmount'] as num).toDouble()
            : 0.0;

        setState(() {
          _isCouponApplied = true;
          _appliedCouponCode = code;
          _bypassPayment = bypassPayment;
          _discountAmount = bypassPayment ? 0.0 : discount;
          _isValidatingCoupon = false;
        });

        final message = (data['message'] ?? '').toString().trim();
        final snackText = message.isNotEmpty
            ? message
            : (bypassPayment
                  ? 'Promo code applied - Payment bypassed'
                  : 'Promo code applied! Save \$${_discountAmount.toStringAsFixed(2)}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(snackText)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _couponError = (data['message'] ?? 'Invalid promo code').toString();
          _isValidatingCoupon = false;
        });
      }
    } catch (e) {
      setState(() {
        _couponError = 'Error validating promo code. Please try again.';
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
        final exclusionsKey = _computeExclusionsKey(provider.exclusions);
        if (exclusionsKey != _exclusionsKey) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _exclusionsKey = exclusionsKey;
              _exclusionsAcknowledged = false;
            });
          });
        }

        final plan = provider.selectedPlan!;
        final ownerDetails = provider.ownerDetails!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () =>
                          _saveAndFinishLater(context, provider, plan),
                      child: const Text('Save & finish later'),
                    ),
                    TextButton(
                      onPressed: _copyResumeCodeToClipboard,
                      child: const Text('Copy resume code'),
                    ),
                  ],
                ),
              ),
              const Text(
                'Payment',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Secure payment powered by Stripe',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
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

              // Exclusions Summary (if any)
              if (provider.exclusions.isNotEmpty) ...[
                _buildExclusionsSummaryCard(provider.exclusions),
                const SizedBox(height: 12),
                _buildExclusionsAcknowledgement(provider),
                const SizedBox(height: 24),
              ],

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

  Widget _buildExclusionsAcknowledgement(CheckoutProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: CheckboxListTile(
        value: _exclusionsAcknowledged,
        onChanged: (value) {
          final nextValue = value ?? false;
          setState(() {
            _exclusionsAcknowledged = nextValue;
          });
          if (nextValue) {
            provider.recordExclusionsAcknowledgement(source: 'payment');
          }
        },
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          'I understand these exclusions will not be covered.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.orange.shade900,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary(plan, ownerDetails) {
    final double finalAmount = _bypassPayment
        ? 0.0
        : (plan.monthlyPremium - _discountAmount);

    String annualLimitLabel() {
      try {
        if (plan.isUnlimitedAnnualCoverage == true ||
            (plan.maxAnnualCoverage as double).isInfinite) {
          return 'Unlimited';
        }
        final v = (plan.maxAnnualCoverage as double).toDouble();
        return '\$${v.toStringAsFixed(0)}';
      } catch (_) {
        return '—';
      }
    }

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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Plan', plan.name),
            const SizedBox(height: 8),
            _buildSummaryRow('Reimbursement', '${plan.reimbursementPercent}%'),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Annual Deductible',
              '\$${plan.annualDeductible.toStringAsFixed(0)}',
            ),
            const SizedBox(height: 8),
            _buildSummaryRow('Annual Limit', annualLimitLabel()),
            if ((plan.selectedAddOns as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Add-ons',
                (plan.selectedAddOns as List).join(', '),
              ),
            ],
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
              _bypassPayment
                  ? '\$0.00 (Waived)'
                  : '\$${finalAmount.toStringAsFixed(2)}',
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
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                      Icon(
                        Icons.credit_card,
                        size: 48,
                        color: Colors.blue.shade700,
                      ),
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
                        'Payment processing on web is currently in development. Please use the mobile app or contact support@clovara.com to complete your purchase.',
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
                              content: Text('Email: support@clovara.com'),
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
                  Icon(
                    Icons.credit_card,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Visa • Mastercard • Amex • Discover',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Stripe will securely collect your payment information. Your card details are never stored on our servers.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 32,
                    ),
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
                  fillColor: _isCouponApplied
                      ? Colors.green.shade50
                      : Colors.grey.shade50,
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
              onPressed: _isCouponApplied || _isValidatingCoupon
                  ? null
                  : _applyCoupon,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
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
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade700,
                  size: 20,
                ),
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
                  style: TextStyle(fontSize: 13, color: Colors.green.shade800),
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

  Widget _buildNavigationButtons(
    BuildContext context,
    CheckoutProvider provider,
    plan,
  ) {
    final double finalAmount = _bypassPayment
        ? 0.0
        : (plan.monthlyPremium - _discountAmount);
    final requiresExclusionsAck = provider.exclusions.isNotEmpty;
    final isPayEnabled = !requiresExclusionsAck || _exclusionsAcknowledged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (requiresExclusionsAck && !isPayEnabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Please acknowledge the exclusions to continue.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade900,
              ),
              textAlign: TextAlign.center,
            ),
          ),
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
                child: const Text('Back', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (_isProcessing || !isPayEnabled)
                    ? null
                    : () => _handlePayment(context, provider, plan),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _bypassPayment
                                ? Icons.check_circle_outline
                                : Icons.lock_outline,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _bypassPayment
                                ? 'Complete Setup'
                                : 'Pay \$${finalAmount.toStringAsFixed(2)}',
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
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    bool isTotal = false,
    bool isDiscount = false,
  }) {
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

  Widget _buildExclusionsSummaryCard(List exclusions) {
    final exclusionNames =
        exclusions
            .map((e) {
              if (e is String) return e;
              try {
                final conditionName = (e as dynamic).conditionName?.toString();
                if (conditionName != null && conditionName.trim().isNotEmpty) {
                  return conditionName;
                }
              } catch (_) {
                // ignore
              }
              return e.toString();
            })
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (exclusionNames.isEmpty) return const SizedBox.shrink();

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
                Icon(Icons.gpp_maybe, size: 22, color: Colors.orange.shade800),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Coverage exclusions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'You are about to pay for a policy that will not cover treatment related to these conditions:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: exclusionNames
                  .map(
                    (name) => Chip(
                      label: Text(
                        name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      backgroundColor: Colors.orange.shade50,
                      side: BorderSide(color: Colors.orange.shade200),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayment(
    BuildContext context,
    CheckoutProvider provider,
    plan,
  ) async {
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
          discountAmount: _discountAmount,
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
        throw Exception(
          'Payment processing is not yet available on web. Please use the mobile app or contact support.',
        );
      }

      // Validate card details are entered (mobile only)
      if (_cardFieldDetails == null || !_cardFieldDetails!.complete) {
        throw Exception('Please enter complete card details');
      }

      // Calculate final amount with discount
      final double finalAmount = plan.monthlyPremium - _discountAmount;

      // Create payment intent
      final policyId =
          'policy_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
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
            colors: stripe.PaymentSheetAppearanceColors(primary: Colors.blue),
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
