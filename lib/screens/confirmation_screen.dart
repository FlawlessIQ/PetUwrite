import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/checkout_state.dart';
import '../services/policy_service.dart';

/// Step 4: Confirmation screen with policy details and PDF download
class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isCreatingPolicy = true;
  bool _policyCreated = false;
  String? _errorMessage;
  final _policyService = PolicyService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
    _createPolicy();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _createPolicy() async {
    try {
      final provider = context.read<CheckoutProvider>();
      
      // Generate policy number
      final policyNumber = _generatePolicyNumber();
      
      // Create policy document
      final policy = await _policyService.createPolicy(
        pet: provider.pet!,
        owner: provider.ownerDetails!,
        plan: provider.selectedPlan!,
        payment: provider.paymentInfo!,
        policyNumber: policyNumber,
      );

      // Update provider with policy
      provider.setPolicy(policy);

      // Send email notification
      await _policyService.sendPolicyEmail(policy);

      setState(() {
        _isCreatingPolicy = false;
        _policyCreated = true;
      });
    } catch (e) {
      setState(() {
        _isCreatingPolicy = false;
        _errorMessage = e.toString();
      });
    }
  }

  String _generatePolicyNumber() {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final random = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'PU$year$random';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CheckoutProvider>(
      builder: (context, provider, child) {
        if (_isCreatingPolicy) {
          return _buildLoadingState();
        }

        if (_errorMessage != null) {
          return _buildErrorState();
        }

        if (_policyCreated && provider.policy != null) {
          return _buildSuccessState(provider.policy!);
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          const Text(
            'Creating your policy...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we finalize your coverage',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Failed to create policy',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isCreatingPolicy = true;
                  _errorMessage = null;
                });
                _createPolicy();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState(PolicyDocument policy) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success Animation
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green.shade600,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Success Message
          const Text(
            'Coverage Activated!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your pet insurance policy is now active',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Policy Information Card
          _buildPolicyInfoCard(policy),
          const SizedBox(height: 16),

          // Coverage Summary Card
          _buildCoverageSummaryCard(policy),
          const SizedBox(height: 16),

          // What's Next Card
          _buildWhatsNextCard(policy),
          const SizedBox(height: 24),

          // Action Buttons
          _buildActionButtons(policy),
        ],
      ),
    );
  }

  Widget _buildPolicyInfoCard(PolicyDocument policy) {
    final dateFormat = DateFormat('MMM dd, yyyy');

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
                Icon(Icons.description, size: 24, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                const Text(
                  'Policy Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Policy Number', policy.policyNumber, isBold: true),
            const SizedBox(height: 12),
            _buildInfoRow('Pet Name', policy.pet.name),
            const SizedBox(height: 12),
            _buildInfoRow('Plan', policy.plan.name),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Coverage Start',
              dateFormat.format(policy.effectiveDate),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Coverage End',
              dateFormat.format(policy.expirationDate),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Monthly Premium',
              '\$${policy.plan.monthlyPremium.toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverageSummaryCard(PolicyDocument policy) {
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
                Icon(Icons.shield, size: 24, color: Colors.green.shade700),
                const SizedBox(width: 12),
                const Text(
                  'Coverage Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildCoverageItem(
                    'Deductible',
                    '\$${policy.plan.annualDeductible.toStringAsFixed(0)}',
                    Icons.attach_money,
                  ),
                ),
                Expanded(
                  child: _buildCoverageItem(
                    'Reimbursement',
                    policy.plan.coveragePercentage,
                    Icons.pie_chart,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCoverageItem(
                    'Annual Max',
                    '\$${(policy.plan.maxAnnualCoverage / 1000).toStringAsFixed(0)}K',
                    Icons.trending_up,
                  ),
                ),
                Expanded(
                  child: _buildCoverageItem(
                    'Co-pay',
                    '${policy.plan.coPayPercentage.toInt()}%',
                    Icons.handshake,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsNextCard(PolicyDocument policy) {
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
                Icon(Icons.lightbulb_outline, size: 24, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                const Text(
                  'What\'s Next?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildNextStepItem(
              '1',
              'Check Your Email',
              'We\'ve sent your policy documents to ${policy.owner.email}',
              Icons.email,
            ),
            const SizedBox(height: 12),
            _buildNextStepItem(
              '2',
              'Download Your Policy',
              'Save a copy of your policy PDF for your records',
              Icons.download,
            ),
            const SizedBox(height: 12),
            _buildNextStepItem(
              '3',
              'Visit Your Vet',
              'Schedule a checkup and start using your coverage',
              Icons.local_hospital,
            ),
            const SizedBox(height: 12),
            _buildNextStepItem(
              '4',
              'File a Claim',
              'Submit claims easily through our mobile app',
              Icons.receipt_long,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(PolicyDocument policy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => _downloadPDF(policy),
          icon: const Icon(Icons.download),
          label: const Text('Download Policy PDF'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.blue,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _emailReceipt(policy),
          icon: const Icon(Icons.email_outlined),
          label: const Text('Email Receipt'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: const Text('Go to Dashboard'),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.support_agent, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need Help?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    Text(
                      'Contact us at support@petunderwriter.ai',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCoverageItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Colors.blue.shade700),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepItem(String number, String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _downloadPDF(PolicyDocument policy) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(width: 16),
              Text('Generating PDF...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final pdfUrl = await _policyService.generatePolicyPDF(policy);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('PDF downloaded successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () {
                // Open PDF viewer
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _emailReceipt(PolicyDocument policy) async {
    try {
      await _policyService.sendPolicyEmail(policy);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Receipt sent to ${policy.owner.email}'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
