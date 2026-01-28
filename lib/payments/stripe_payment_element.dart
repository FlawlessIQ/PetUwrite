import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

/// Web-only Stripe Payment Element widget using HtmlElementView
/// This widget embeds the Stripe.js Payment Element for secure card collection
class StripePaymentElement extends StatefulWidget {
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
  State<StripePaymentElement> createState() => _StripePaymentElementState();
}

class _StripePaymentElementState extends State<StripePaymentElement> {
  final String _viewId = 'stripe-payment-element-${DateTime.now().millisecondsSinceEpoch}';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _registerViewFactory();
  }

  void _registerViewFactory() {
    // Register the view factory for the HTML element
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        // Create container div for the Stripe Payment Element
        final container = html.DivElement()
          ..id = 'payment-element-container-$viewId'
          ..style.width = '100%'
          ..style.minHeight = '200px';

        // Create the payment element mount point
        final paymentElementDiv = html.DivElement()
          ..id = 'payment-element-$viewId';
        
        container.append(paymentElementDiv);

        // Initialize Stripe after a short delay to ensure DOM is ready
        Future.delayed(const Duration(milliseconds: 100), () {
          _initializeStripeElement(viewId);
        });

        return container;
      },
    );
    
    setState(() {
      _isInitialized = true;
    });
  }

  void _initializeStripeElement(int viewId) {
    try {
      // Check if Stripe is loaded
      if (!_isStripeLoaded()) {
        _loadStripeScript(() {
          _createPaymentElement(viewId);
        });
      } else {
        _createPaymentElement(viewId);
      }
    } catch (e) {
      print('Error initializing Stripe element: $e');
      widget.onPaymentError?.call('Failed to initialize payment form');
    }
  }

  bool _isStripeLoaded() {
    try {
      return js.context['Stripe'] != null;
    } catch (_) {
      return false;
    }
  }

  void _loadStripeScript(Function callback) {
    final script = html.ScriptElement()
      ..src = 'https://js.stripe.com/v3/'
      ..type = 'text/javascript'
      ..async = true;

    script.onLoad.listen((_) {
      callback();
    });

    script.onError.listen((_) {
      widget.onPaymentError?.call('Failed to load Stripe.js');
    });

    html.document.head?.append(script);
  }

  void _createPaymentElement(int viewId) {
    try {
      // Create Stripe instance
      final stripeJs = js.JsObject(
        js.context['Stripe'] as js.JsFunction,
        [widget.publishableKey],
      );

      // Create Elements instance with clientSecret
      final elementsOptions = js.JsObject.jsify({
        'clientSecret': widget.clientSecret,
        'appearance': {
          'theme': 'stripe',
          'variables': {
            'colorPrimary': '#10b981',
            'colorBackground': '#ffffff',
            'colorText': '#1a1a1a',
            'colorDanger': '#ef4444',
            'fontFamily': 'Inter, system-ui, sans-serif',
            'spacingUnit': '4px',
            'borderRadius': '12px',
          },
          'rules': {
            '.Input': {
              'border': '1px solid #e5e7eb',
              'boxShadow': 'none',
            },
            '.Input:focus': {
              'border': '1px solid #10b981',
              'boxShadow': '0 0 0 2px rgba(16, 185, 129, 0.1)',
            },
            '.Label': {
              'fontSize': '14px',
              'fontWeight': '600',
            },
          },
        },
      });

      final elements = stripeJs.callMethod('elements', [elementsOptions]);

      // Create payment element
      final paymentElementOptions = js.JsObject.jsify({
        'layout': {
          'type': 'accordion',
          'defaultCollapsed': false,
          'radios': true,
          'spacedAccordionItems': false,
        },
      });

      final paymentElement = elements.callMethod(
        'create',
        ['payment', paymentElementOptions],
      );

      // Mount the payment element
      paymentElement.callMethod('mount', ['#payment-element-$viewId']);

      // Store references for later use
      js.context['stripeInstance_$viewId'] = stripeJs;
      js.context['elements_$viewId'] = elements;

      print('✅ Stripe Payment Element mounted successfully');
    } catch (e) {
      print('❌ Error creating payment element: $e');
      widget.onPaymentError?.call('Failed to create payment form: $e');
    }
  }

  /// Confirm payment - call this from parent widget
  Future<Map<String, dynamic>> confirmPayment({
    String? returnUrl,
  }) async {
    try {
      final stripeInstance = js.context['stripeInstance_$_viewId'];
      final elements = js.context['elements_$_viewId'];

      if (stripeInstance == null || elements == null) {
        throw Exception('Stripe not initialized');
      }

      // Confirm payment
      final confirmParams = js.JsObject.jsify({
        'elements': elements,
        'confirmParams': {
          if (returnUrl != null) 'return_url': returnUrl,
        },
        'redirect': 'if_required',
      });

      final result = await _promiseToFuture(
        stripeInstance.callMethod('confirmPayment', [confirmParams]),
      );

      final resultMap = _jsObjectToMap(result);

      if (resultMap['error'] != null) {
        final error = resultMap['error'] as Map<String, dynamic>;
        final message = error['message'] as String? ?? 'Payment failed';
        widget.onPaymentError?.call(message);
        return {'error': message};
      }

      widget.onPaymentSuccess?.call(resultMap);
      return resultMap;
    } catch (e) {
      final errorMsg = 'Payment confirmation failed: $e';
      widget.onPaymentError?.call(errorMsg);
      return {'error': errorMsg};
    }
  }

  Future<dynamic> _promiseToFuture(js.JsObject promise) {
    final completer = Completer<dynamic>();
    
    promise.callMethod('then', [
      js.allowInterop((result) {
        completer.complete(result);
      }),
    ]);
    
    promise.callMethod('catch', [
      js.allowInterop((error) {
        completer.completeError(error);
      }),
    ]);
    
    return completer.future;
  }

  Map<String, dynamic> _jsObjectToMap(dynamic jsObject) {
    if (jsObject == null) return {};
    try {
      final json = js.context['JSON'].callMethod('stringify', [jsObject]);
      return jsonDecode(json as String) as Map<String, dynamic>;
    } catch (e) {
      print('Error converting JS object to map: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 300,
      child: HtmlElementView(
        viewType: _viewId,
      ),
    );
  }

  @override
  void dispose() {
    // Clean up JS objects
    try {
      js.context.deleteProperty('stripeInstance_$_viewId');
      js.context.deleteProperty('elements_$_viewId');
    } catch (e) {
      print('Error cleaning up Stripe instance: $e');
    }
    super.dispose();
  }
}

