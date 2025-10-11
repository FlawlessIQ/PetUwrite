# Integrating Policy Functions with Flutter App

This guide shows how to use the Cloud Functions from your Flutter application.

## 🔧 Setup in Flutter

### 1. Ensure Cloud Functions Package

Already added in `pubspec.yaml`:
```yaml
dependencies:
  cloud_functions: ^5.0.0
```

### 2. Initialize in PolicyService

The `PolicyService` class (`lib/services/policy_service.dart`) is already configured to call these functions.

## 📞 Function Calls

### Generate and Send Policy Email

After creating a policy in Firestore, send the confirmation email:

```dart
// In confirmation_screen.dart or after policy creation

// 1. Generate PDF first (optional but recommended)
try {
  final pdfResult = await PolicyService.generatePolicyPDF(
    policyId: policy.policyId,
    policyNumber: policy.policyNumber,
    policyData: policy.toJson(),
  );
  
  final pdfUrl = pdfResult['pdfUrl'];
  print('PDF generated: $pdfUrl');
} catch (e) {
  print('Error generating PDF: $e');
  // Continue anyway - email can still be sent without PDF
}

// 2. Send email with policy details
try {
  await PolicyService.sendPolicyEmail(
    recipientEmail: policy.owner.email,
    policyData: policy.toJson(),
  );
  
  // Show success message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Policy confirmation sent to ${policy.owner.email}'),
      backgroundColor: Colors.green,
    ),
  );
} catch (e) {
  print('Error sending email: $e');
  // Show error but don't block user
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Could not send email. Check your inbox or contact support.'),
      backgroundColor: Colors.orange,
    ),
  );
}
```

### Download PDF

When user clicks "Download PDF" button:

```dart
Future<void> _downloadPDF() async {
  setState(() => _isDownloadingPdf = true);

  try {
    final result = await PolicyService.generatePolicyPDF(
      policyId: widget.policy.policyId,
      policyNumber: widget.policy.policyNumber,
      policyData: widget.policy.toJson(),
    );

    final pdfUrl = result['pdfUrl'] as String;

    // Option 1: Open in browser
    if (await canLaunchUrl(Uri.parse(pdfUrl))) {
      await launchUrl(Uri.parse(pdfUrl));
    }

    // Option 2: Use url_launcher package
    // await launch(pdfUrl);

    // Option 3: Download with flutter_downloader
    // await FlutterDownloader.enqueue(
    //   url: pdfUrl,
    //   savedDir: documentsDir,
    //   fileName: 'Policy_${widget.policy.policyNumber}.pdf',
    // );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF downloaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isDownloadingPdf = false);
    }
  }
}
```

### Email Receipt

When user clicks "Email Receipt" button:

```dart
Future<void> _emailReceipt() async {
  setState(() => _isSendingEmail = true);

  try {
    await PolicyService.sendPolicyEmail(
      recipientEmail: widget.policy.owner.email,
      policyData: widget.policy.toJson(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receipt sent to ${widget.policy.owner.email}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isSendingEmail = false);
    }
  }
}
```

## ⚠️ Error Handling

Handle different error types:

```dart
Future<void> callCloudFunction() async {
  try {
    final result = await PolicyService.sendPolicyEmail(...);
    // Success
  } on FirebaseFunctionsException catch (e) {
    // Handle specific Firebase errors
    switch (e.code) {
      case 'unauthenticated':
        // User needs to log in
        Navigator.pushReplacementNamed(context, '/login');
        break;
        
      case 'invalid-argument':
        // Invalid data provided
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid policy data. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        break;
        
      case 'deadline-exceeded':
        // Function timeout
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request timed out. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
        
      default:
        // Generic error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
    }
  } catch (e) {
    // Other errors (network, etc.)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unexpected error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

## 🧪 Testing with Emulator

### 1. Start Firebase Emulator

```bash
firebase emulators:start --only functions
```

### 2. Configure Flutter to Use Emulator

Add this to your main.dart (or wherever you initialize Firebase):

```dart
import 'package:cloud_functions/cloud_functions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Use emulator in debug mode
  if (kDebugMode) {
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  }

  runApp(MyApp());
}
```

### 3. Test Functions

Now when you run your app in debug mode, all Cloud Functions calls will go to the local emulator instead of production.

## 📱 UI Integration Examples

### Loading States

Show loading indicators while functions execute:

```dart
class ConfirmationScreen extends StatefulWidget {
  @override
  _ConfirmationScreenState createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  bool _isDownloadingPdf = false;
  bool _isSendingEmail = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ... policy details ...
          
          ElevatedButton.icon(
            onPressed: _isDownloadingPdf ? null : _downloadPDF,
            icon: _isDownloadingPdf
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.download),
            label: Text(_isDownloadingPdf ? 'Downloading...' : 'Download PDF'),
          ),
          
          SizedBox(height: 16),
          
          OutlinedButton.icon(
            onPressed: _isSendingEmail ? null : _emailReceipt,
            icon: _isSendingEmail
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.email),
            label: Text(_isSendingEmail ? 'Sending...' : 'Email Receipt'),
          ),
        ],
      ),
    );
  }
}
```

### Retry Logic

Add retry capability for failed operations:

```dart
Future<void> _sendEmailWithRetry({int maxRetries = 3}) async {
  int attempts = 0;
  
  while (attempts < maxRetries) {
    try {
      await PolicyService.sendPolicyEmail(
        recipientEmail: email,
        policyData: policyData,
      );
      
      // Success - break loop
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email sent successfully!')),
      );
      return;
      
    } catch (e) {
      attempts++;
      
      if (attempts >= maxRetries) {
        // Final failure
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send email after $maxRetries attempts'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _sendEmailWithRetry(),
            ),
          ),
        );
      } else {
        // Wait before retry
        await Future.delayed(Duration(seconds: 2 * attempts));
      }
    }
  }
}
```

## 🎨 User Experience Tips

### 1. Background Processing

Don't block the UI while sending emails:

```dart
// Send email in background after policy creation
Future<void> _createPolicy() async {
  // Create policy in Firestore
  final policy = await PolicyService.createPolicy(...);
  
  // Navigate to confirmation immediately
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => ConfirmationScreen(policy: policy),
    ),
  );
  
  // Send email in background (don't await)
  _sendEmailInBackground(policy);
}

void _sendEmailInBackground(PolicyDocument policy) async {
  try {
    await PolicyService.sendPolicyEmail(
      recipientEmail: policy.owner.email,
      policyData: policy.toJson(),
    );
  } catch (e) {
    // Log error but don't show to user
    print('Background email failed: $e');
  }
}
```

### 2. Offline Handling

Handle offline scenarios gracefully:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

Future<void> _downloadPDF() async {
  // Check connectivity first
  final connectivityResult = await Connectivity().checkConnectivity();
  
  if (connectivityResult == ConnectivityResult.none) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No internet connection. Please try again.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  
  // Proceed with download
  try {
    final result = await PolicyService.generatePolicyPDF(...);
    // ...
  } catch (e) {
    // Handle error
  }
}
```

### 3. Success Feedback

Provide clear success feedback:

```dart
Future<void> _emailReceipt() async {
  try {
    await PolicyService.sendPolicyEmail(...);
    
    // Show success dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Email Sent!'),
          ],
        ),
        content: Text(
          'A copy of your policy has been sent to ${email}. '
          'Please check your inbox and spam folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  } catch (e) {
    // Handle error
  }
}
```

## 🔐 Security Best Practices

### 1. Verify User Ownership

Always verify the user owns the policy:

```dart
Future<void> _downloadPDF(String policyId) async {
  // Get current user
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    // Redirect to login
    return;
  }
  
  // Verify policy belongs to user
  final policy = await PolicyService.getPolicy(policyId);
  if (policy.ownerId != user.uid) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You do not have permission to access this policy.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  // Proceed with download
  final result = await PolicyService.generatePolicyPDF(...);
}
```

### 2. Sanitize Email Addresses

Validate email before sending:

```dart
bool isValidEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
}

Future<void> _emailReceipt(String email) async {
  if (!isValidEmail(email)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invalid email address'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  // Proceed with sending
  await PolicyService.sendPolicyEmail(...);
}
```

## 📊 Analytics Integration

Track function usage:

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

Future<void> _downloadPDF() async {
  try {
    final result = await PolicyService.generatePolicyPDF(...);
    
    // Log successful download
    await FirebaseAnalytics.instance.logEvent(
      name: 'policy_pdf_downloaded',
      parameters: {
        'policy_id': policyId,
        'policy_number': policyNumber,
        'user_id': user.uid,
      },
    );
  } catch (e) {
    // Log error
    await FirebaseAnalytics.instance.logEvent(
      name: 'policy_pdf_download_failed',
      parameters: {
        'policy_id': policyId,
        'error': e.toString(),
      },
    );
  }
}
```

## 🚀 Performance Optimization

### Cache PDF URLs

Store PDF URLs to avoid regenerating:

```dart
class _ConfirmationScreenState extends State<ConfirmationScreen> {
  String? _cachedPdfUrl;

  Future<void> _downloadPDF() async {
    // Check cache first
    if (_cachedPdfUrl != null) {
      await launchUrl(Uri.parse(_cachedPdfUrl!));
      return;
    }
    
    // Generate if not cached
    final result = await PolicyService.generatePolicyPDF(...);
    _cachedPdfUrl = result['pdfUrl'];
    
    // Save to policy document for future use
    await FirebaseFirestore.instance
        .collection('policies')
        .doc(policyId)
        .update({'pdfUrl': _cachedPdfUrl});
    
    await launchUrl(Uri.parse(_cachedPdfUrl!));
  }
}
```

## 📝 Complete Example

Here's a complete confirmation screen implementation:

```dart
// See lib/screens/confirmation_screen.dart
// The screen is already fully implemented with all these features!
```

The `confirmation_screen.dart` file already includes:
- ✅ PDF download with loading states
- ✅ Email receipt with error handling
- ✅ Policy creation and saving
- ✅ Success animations
- ✅ Proper error handling
- ✅ User feedback

---

**You're all set!** The Cloud Functions are deployed and ready to use from your Flutter app.
