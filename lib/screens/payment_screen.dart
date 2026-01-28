import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, kReleaseMode;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import '../payments/stripe_payment_element.dart'
    if (dart.library.io) '../payments/stripe_payment_element_stub.dart';
import '../models/checkout_state.dart';
import '../services/draft_service.dart';
import '../services/quote_engine.dart';
import '../services/stripe_service.dart';
import '../services/user_session_service.dart';
import '../services/marketing_attribution_service.dart';
import '../ui/tokens.dart';
import '../ui/components/checkout_components.dart';
import '../ui/components/clovara_logo.dart';
import '../ui/components/max_width.dart';
import '../ui/components/save_resume_dialog.dart';

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
  bool _showCouponField = false; // Toggle for showing coupon input
  bool _isCouponApplied = false;
  double _discountAmount = 0.0;
  String? _appliedCouponCode;
  bool _bypassPayment = false; // For TEST100 coupon

  // Stripe card field controller
  stripe.CardFieldInputDetails? _cardFieldDetails;

  // Payment Element (web)
  String? _clientSecret;
  GlobalKey<_PaymentElementWidgetState>? _paymentElementKey;

  // Dev-only bypass
  static const bool _kAllowPaymentBypass = bool.fromEnvironment(
    'ALLOW_PAYMENT_BYPASS',
    defaultValue: false,
  );

  bool get _showBypassButton => kDebugMode || _kAllowPaymentBypass;

  @override
  void initState() {
    super.initState();
    _loadPendingCheckoutPaymentState();
    if (kIsWeb) {
      _paymentElementKey = GlobalKey<_PaymentElementWidgetState>();
      _initializePaymentIntent();
    }
  }

  Future<void> _initializePaymentIntent() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final provider = context.read<CheckoutProvider>();
      final plan = provider.selectedPlan;
      if (plan == null) return;

      final amount = (plan.monthlyPremium - _discountAmount).clamp(
        0.0,
        double.infinity,
      );
      final policyId =
          'policy_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';

      final callable = FirebaseFunctions.instance.httpsCallable(
        'createPaymentIntent',
      );
      final response = await callable.call({
        'amount': (amount * 100).round(), // Convert to cents
        'currency': 'usd',
        'policyId': policyId,
      });

      if (response.data != null && response.data['clientSecret'] != null) {
        setState(() {
          _clientSecret = response.data['clientSecret'];
        });
        print('✅ PaymentIntent created with clientSecret');
      }
    } catch (e) {
      print('⚠️ Error initializing payment intent: $e');
      // In dev mode with bypass button available, this is not critical
      if (kDebugMode) {
        print(
          '💡 Dev mode: Payment initialization failed but bypass button is available',
        );
        setState(() {
          _errorMessage = null; // Don't show error in dev mode
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to initialize payment form. Please try again.';
        });
      }
    }
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
    final provider = context.read<CheckoutProvider>();
    final plan = provider.selectedPlan;
    await SaveResumeDialog.show(
      context,
      ensureSaved: () async {
        final snapshot = _buildCheckoutSnapshot(provider, plan);
        await UserSessionService().savePendingCheckout(snapshot);
        await DraftService().upsertCheckoutDraft(
          state: 'CHECKOUT_PAYMENT',
          checkoutData: snapshot,
        );
      },
      title: 'Save & resume later',
      body:
          'We’ll save your progress. Use this code to resume from the home page on any device.',
      copyLabel: 'Copy code',
      doneLabel: 'Done',
    );
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

        return MaxWidth(
          maxWidth: 960,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: 120, // Space for pinned CTA
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;

                    return Row(
                      children: [
                        const ClovaraLogoLockup(
                          compact: true,
                          boxedMark: false,
                          markSize: 20,
                          textSize: 20,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => context.go('/'),
                          icon: const Icon(Icons.home_outlined, size: 18),
                          label: Text(compact ? 'Home' : 'Website home'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.deepGreen,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Page Header
                Text(
                  'Review & Pay',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure payment powered by Stripe',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                // Order Summary Card
                _buildOrderSummaryCard(plan, ownerDetails),
                const SizedBox(height: 20),

                // Payment Method Card
                _buildPaymentMethodCard(),
                const SizedBox(height: 20),

                // Security Banner
                InlineBanner(
                  type: BannerType.info,
                  message:
                      'Your payment is encrypted and secure. We use industry-standard SSL encryption and are PCI DSS compliant.',
                  icon: const Icon(Icons.lock_outline),
                ),

                // Exclusions Section (if any)
                if (provider.exclusions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildExclusionsCard(provider),
                ],

                // Error Message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  InlineBanner(type: BannerType.error, message: _errorMessage!),
                ],

                const SizedBox(height: 24),

                // Save & Resume Options
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TertiaryButton(
                      text: 'Save & finish later',
                      onPressed: () =>
                          _saveAndFinishLater(context, provider, plan),
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

                // DEV-ONLY: Bypass Payment Button
                if (_showBypassButton && !_bypassPayment) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleDevBypass(context, provider),
                      icon: const Icon(Icons.code, size: 16),
                      label: const Text(
                        'Bypass Payment (DEV)',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: BorderSide(color: AppColors.warning),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderSummaryCard(plan, ownerDetails) {
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

    return CheckoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Order Summary',
            padding: const EdgeInsets.only(bottom: 16),
          ),

          // Price Summary First (most important)
          InfoRow(
            label: 'Monthly Premium',
            value: '\$${plan.monthlyPremium.toStringAsFixed(2)}',
            isBold: true,
          ),
          if (plan.multiPetDiscount > 0)
            InfoRow(
              label: 'Multi-pet Discount',
              value: '-\$${plan.discountAmount.toStringAsFixed(2)}',
              valueColor: AppColors.success,
            ),
          if (_isCouponApplied && _discountAmount > 0)
            InfoRow(
              label: 'Coupon Discount',
              value: '-\$${_discountAmount.toStringAsFixed(2)}',
              valueColor: AppColors.success,
            ),

          const CheckoutDivider(),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Due Today',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              Text(
                _bypassPayment
                    ? '\$0.00'
                    : '\$${finalAmount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green,
                ),
              ),
            ],
          ),

          const CheckoutDivider(),

          // Coverage Details
          InfoRow(label: 'Plan', value: plan.name),
          InfoRow(
            label: 'Reimbursement',
            value: '${plan.reimbursementPercent}%',
          ),
          InfoRow(
            label: 'Annual Deductible',
            value: '\$${plan.annualDeductible.toStringAsFixed(0)}',
          ),
          InfoRow(label: 'Annual Limit', value: annualLimitLabel()),
          if ((plan.selectedAddOns as List).isNotEmpty)
            InfoRow(
              label: 'Add-ons',
              value: (plan.selectedAddOns as List).join(', '),
            ),

          const CheckoutDivider(margin: EdgeInsets.symmetric(vertical: 12)),

          InfoRow(label: 'Policy Holder', value: ownerDetails.fullName),
          InfoRow(label: 'Email', value: ownerDetails.email),

          const SizedBox(height: 12),
          InlineBanner(
            type: BannerType.success,
            message: 'Coverage starts immediately after payment',
            margin: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    return CheckoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Payment Method',
            padding: const EdgeInsets.only(bottom: 20),
          ),

          // Collapsible Coupon Code Section
          _buildCouponSection(),
          const SizedBox(height: 20),

          // Card Input or Bypass Message
          if (!_bypassPayment) ...[
            // Stripe Card Field (Native only)
            if (!kIsWeb)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppRadii.br12,
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
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
            // Web: Stripe Payment Element
            if (kIsWeb)
              _clientSecret != null
                  ? _PaymentElementWidget(
                      key: _paymentElementKey,
                      clientSecret: _clientSecret!,
                    )
                  : _buildMockPaymentForm(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.credit_card, size: 18, color: AppColors.textSubtle),
                const SizedBox(width: 8),
                Text(
                  'Visa • Mastercard • Amex • Discover',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ] else
            InlineBanner(
              type: BannerType.success,
              message: 'Test coupon applied - no payment required',
              margin: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  Widget _buildCouponSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show applied coupon banner or toggle link
        if (_isCouponApplied && _appliedCouponCode != null)
          InlineBanner(
            type: BannerType.success,
            message: _bypassPayment
                ? 'Test coupon applied - Payment waived'
                : 'Coupon "$_appliedCouponCode" applied - Save \$${_discountAmount.toStringAsFixed(2)}',
            margin: EdgeInsets.zero,
          )
        else
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showCouponField = !_showCouponField;
              });
            },
            icon: Icon(
              _showCouponField ? Icons.remove : Icons.add,
              size: 16,
              color: AppColors.green,
            ),
            label: Text(
              _showCouponField ? 'Hide coupon code' : 'Have a coupon code?',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.green,
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),

        // Expandable coupon input field
        if (_showCouponField && !_isCouponApplied) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _couponController,
                  enabled: !_isValidatingCoupon,
                  decoration: checkoutInputDecoration(label: 'Enter code')
                      .copyWith(
                        errorText: _couponError,
                        prefixIcon: const Icon(
                          Icons.local_offer_outlined,
                          color: AppColors.textMuted,
                        ),
                      ),
                  textCapitalization: TextCapitalization.characters,
                  onFieldSubmitted: (_) => _applyCoupon(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isValidatingCoupon ? null : _applyCoupon,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    backgroundColor: AppColors.green,
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.br12),
                  ),
                  child: _isValidatingCoupon
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Apply',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMockPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadii.br12,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Number
          TextFormField(
            decoration: checkoutInputDecoration(label: 'Card number').copyWith(
              hintText: '1234 1234 1234 1234',
              prefixIcon: const Icon(Icons.credit_card, size: 20),
            ),
            keyboardType: TextInputType.number,
            enabled: false,
          ),
          const SizedBox(height: 16),

          // Expiry and CVC
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: checkoutInputDecoration(
                    label: 'Expiry date',
                  ).copyWith(hintText: 'MM / YY'),
                  keyboardType: TextInputType.number,
                  enabled: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  decoration: checkoutInputDecoration(
                    label: 'CVC',
                  ).copyWith(hintText: '123'),
                  keyboardType: TextInputType.number,
                  enabled: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ZIP Code
          TextFormField(
            decoration: checkoutInputDecoration(
              label: 'ZIP / Postal code',
            ).copyWith(hintText: '12345'),
            keyboardType: TextInputType.number,
            enabled: false,
          ),

          if (kDebugMode) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo mode - Configure Stripe to enable live payments',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExclusionsCard(CheckoutProvider provider) {
    return CheckoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Important: Policy Exclusions',
            subtitle:
                'Please review and acknowledge these exclusions before proceeding',
            padding: const EdgeInsets.only(bottom: 16),
          ),

          InlineBanner(
            type: BannerType.warning,
            message:
                'The following conditions are excluded from your policy and will not be covered',
            margin: const EdgeInsets.only(bottom: 16),
          ),

          ...provider.exclusions.map((exclusion) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.cancel_outlined,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exclusion.conditionName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        if (exclusion.notes != null &&
                            exclusion.notes!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              exclusion.notes!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          const CheckoutDivider(),

          // Acknowledgement Checkbox
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E6),
              borderRadius: AppRadii.br12,
              border: Border.all(
                color: _exclusionsAcknowledged
                    ? AppColors.green
                    : AppColors.warning,
                width: _exclusionsAcknowledged ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _exclusionsAcknowledged,
                    onChanged: (value) {
                      final nextValue = value ?? false;
                      setState(() {
                        _exclusionsAcknowledged = nextValue;
                      });
                      if (nextValue) {
                        provider.recordExclusionsAcknowledgement(
                          source: 'payment',
                        );
                      }
                    },
                    activeColor: AppColors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I understand and acknowledge that the conditions listed above are excluded from my policy and will not be covered',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.text,
                      height: 1.4,
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

  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
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
                  backgroundColor: AppColors.green,
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

  // ignore: unused_element
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

  /// DEV-ONLY: Bypass payment for testing
  Future<void> _handleDevBypass(
    BuildContext context,
    CheckoutProvider provider,
  ) async {
    // Safety check: never allow in release mode
    assert(
      !kReleaseMode,
      'Payment bypass must never be enabled in release mode',
    );

    if (kReleaseMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment bypass is not available in release mode'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Dev Mode: Bypass Payment'),
          ],
        ),
        content: const Text(
          'This will skip payment processing and mark the payment as TEST_BYPASS. '
          'This feature is only available in development mode.\\n\\n'
          'Continue to confirmation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Bypass Payment'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final paymentInfo = PaymentInfo(
        paymentIntentId: 'TEST_BYPASS_${DateTime.now().millisecondsSinceEpoch}',
        paymentMethodId: 'test_bypass',
        amount: 0.0,
        currency: 'usd',
        status: 'test_waived', // Must match validation in checkout_state.dart
        paidAt: DateTime.now(),
        last4: 'XXXX',
        brand: 'Test',
        couponCode: _appliedCouponCode,
        discountAmount: _discountAmount,
      );

      provider.setPaymentInfo(paymentInfo);

      print(
        '\u26a0\ufe0f DEV MODE: Payment bypassed - ${paymentInfo.paymentIntentId}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text('DEV MODE: Payment bypassed!'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));
      provider.nextStep();
    } catch (e) {
      setState(() {
        _errorMessage = 'Bypass failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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

      // On web, use Payment Element
      if (kIsWeb) {
        if (_clientSecret == null || _paymentElementKey?.currentState == null) {
          throw Exception('Payment form not initialized');
        }

        // Confirm payment using the Payment Element
        final result = await _paymentElementKey!.currentState!.confirmPayment();

        if (result['error'] != null) {
          throw Exception(result['error']);
        }

        // Payment successful on web
        final paymentInfo = PaymentInfo(
          paymentIntentId:
              result['paymentIntent']?['id'] ??
              'web_payment_${DateTime.now().millisecondsSinceEpoch}',
          paymentMethodId:
              result['paymentIntent']?['payment_method'] ?? 'web_pm',
          amount: (plan.monthlyPremium - _discountAmount).clamp(
            0.0,
            double.infinity,
          ),
          currency: 'usd',
          status: 'succeeded',
          paidAt: DateTime.now(),
          last4: '****',
          brand: 'Card',
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
                  Text('Payment successful!'),
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

      // Mobile: Validate card details are entered
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

/// Payment Element Widget wrapper
class _PaymentElementWidget extends StatefulWidget {
  final String clientSecret;

  const _PaymentElementWidget({super.key, required this.clientSecret});

  @override
  State<_PaymentElementWidget> createState() => _PaymentElementWidgetState();
}

class _PaymentElementWidgetState extends State<_PaymentElementWidget> {
  final GlobalKey<_StripePaymentElementWrapperState> _elementKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Center(
        child: Text('Payment Element is only available on web'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadii.br12,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: _StripePaymentElementWrapper(
        key: _elementKey,
        clientSecret: widget.clientSecret,
        publishableKey:
            'pk_test_51SI7vTPzjq9wJkU5zFAJvBSWvFLKfu9Be4klAyLdG8IOjHpQwsw8My1WxhrbagFztc549VKyQAmAtCklGOpbeo4v00IAlWsINb',
      ),
    );
  }

  /// Expose confirmPayment method to parent
  Future<Map<String, dynamic>> confirmPayment() async {
    if (_elementKey.currentState != null) {
      return await _elementKey.currentState!.confirmPayment();
    }
    return {'error': 'Payment element not initialized'};
  }
}

/// Inner wrapper for StripePaymentElement with state access
class _StripePaymentElementWrapper extends StatefulWidget {
  final String clientSecret;
  final String publishableKey;

  const _StripePaymentElementWrapper({
    super.key,
    required this.clientSecret,
    required this.publishableKey,
  });

  @override
  State<_StripePaymentElementWrapper> createState() =>
      _StripePaymentElementWrapperState();
}

class _StripePaymentElementWrapperState
    extends State<_StripePaymentElementWrapper> {
  StripePaymentElement? _element;
  final GlobalKey _widgetKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    _element = StripePaymentElement(
      key: _widgetKey,
      clientSecret: widget.clientSecret,
      publishableKey: widget.publishableKey,
      onPaymentSuccess: (result) {
        print('✅ Payment confirmed: $result');
      },
      onPaymentError: (error) {
        print('❌ Payment error: $error');
      },
    );

    return _element!;
  }

  Future<Map<String, dynamic>> confirmPayment() async {
    if (_element != null && kIsWeb) {
      // Call confirmPayment directly on the StripePaymentElement
      try {
        // Use reflection-like access since we can't directly access the state
        // The Payment Element widget internally handles the confirmation
        final state = _widgetKey.currentState;
        if (state != null && state.mounted) {
          // The StripePaymentElement has its own confirmPayment method
          // We need to call it via the widget's state
          return await (state as dynamic).confirmPayment();
        }
      } catch (e) {
        print('Error confirming payment: $e');
      }
    }
    return {'error': 'Payment element not initialized'};
  }
}
