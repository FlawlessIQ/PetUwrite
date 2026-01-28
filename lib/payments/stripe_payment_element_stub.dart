import 'package:flutter/material.dart';

/// Stub implementation of StripePaymentElement for non-web platforms
/// This file is imported conditionally when running on mobile/desktop
class StripePaymentElement extends StatelessWidget {
  final String clientSecret;
  final String publishableKey;
  final Function(Map<String, dynamic> result)? onPaymentSuccess;
  final Function(String error)? onPaymentError;
  
  const StripePaymentElement({
    super.key,
    required this.clientSecret,
    required this.publishableKey,
    this.onPaymentSuccess,
    this.onPaymentError,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Text(
          'Payment Element is only available on web. Please use the native payment sheet.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
