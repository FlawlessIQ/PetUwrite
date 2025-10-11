import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/checkout_state.dart';
import '../models/medical_history.dart';

/// Step 1: Review pet and quote information
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CheckoutProvider>(
      builder: (context, provider, child) {
        // Handle null pet or plan with loading state
        if (provider.pet == null || provider.selectedPlan == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading your quote...'),
              ],
            ),
          );
        }
        
        final pet = provider.pet!;
        final plan = provider.selectedPlan!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Review Your Coverage',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please review your pet and coverage details before proceeding',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),

              // Pet Information Card
              _buildPetInfoCard(pet),
              const SizedBox(height: 16),

              // Medical History Card (if available)
              if (pet.hasDetailedMedicalHistory || 
                  pet.preExistingConditions.isNotEmpty)
                _buildMedicalHistoryCard(pet),
              if (pet.hasDetailedMedicalHistory || 
                  pet.preExistingConditions.isNotEmpty)
                const SizedBox(height: 16),

              // Plan Information Card
              _buildPlanInfoCard(plan),
              const SizedBox(height: 16),

              // Coverage Details Card
              _buildCoverageDetailsCard(plan),
              const SizedBox(height: 16),

              // Features Card
              _buildFeaturesCard(plan),
              const SizedBox(height: 24),

              // Continue Button
              _buildContinueButton(context, provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPetInfoCard(pet) {
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.pets,
                    size: 32,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${pet.breed} • ${pet.species}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            _buildInfoRow('Age', '${pet.age} years old', Icons.calendar_today),
            const SizedBox(height: 12),
            _buildInfoRow('Gender', pet.gender, Icons.info_outline),
            const SizedBox(height: 12),
            _buildInfoRow('Weight', '${pet.weight} lbs', Icons.monitor_weight),
            const SizedBox(height: 12),
            _buildInfoRow('Breed', pet.breed, Icons.category),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanInfoCard(plan) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getPlanGradient(plan.type),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getPlanIcon(plan.type),
                    size: 32,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          plan.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Monthly Premium',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '\$${plan.monthlyPremium.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (plan.multiPetDiscount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Multi-pet discount: -\$${plan.discountAmount.toStringAsFixed(2)}/mo',
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverageDetailsCard(plan) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Coverage Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildCoverageRow(
              'Annual Deductible',
              '\$${plan.annualDeductible.toStringAsFixed(0)}',
              'Amount you pay before coverage starts',
              Icons.attach_money,
            ),
            const Divider(height: 32),
            _buildCoverageRow(
              'Reimbursement',
              plan.coveragePercentage,
              'Percentage of eligible costs covered',
              Icons.pie_chart,
            ),
            const Divider(height: 32),
            _buildCoverageRow(
              'Annual Maximum',
              '\$${(plan.maxAnnualCoverage / 1000).toStringAsFixed(0)}K',
              'Maximum coverage per year',
              Icons.trending_up,
            ),
            if (plan.coPayPercentage > 0) ...[
              const Divider(height: 32),
              _buildCoverageRow(
                'Co-payment',
                '${plan.coPayPercentage.toInt()}%',
                'Your share of eligible costs',
                Icons.handshake,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesCard(plan) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What\'s Included',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...plan.features.take(8).map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 20,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                )),
            if (plan.features.length > 8)
              TextButton(
                onPressed: () {
                  // Show all features dialog
                },
                child: Text('+ ${plan.features.length - 8} more features'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildCoverageRow(String label, String value, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24, color: Colors.blue.shade700),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMedicalHistoryCard(pet) {
    final hasDetailedHistory = pet.hasDetailedMedicalHistory;
    final hasMedications = pet.hasActiveMedications;
    final conditionCount = pet.numberOfActiveConditions;
    
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medical_services,
                    size: 32,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medical History',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Pre-existing conditions and health details',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            
            // Medical Conditions Section
            if (hasDetailedHistory && pet.medicalConditions != null && pet.medicalConditions!.isNotEmpty) ...[
              _buildSectionHeader('Medical Conditions', Icons.healing),
              const SizedBox(height: 12),
              ...pet.medicalConditions!.map((condition) => 
                _buildConditionItem(condition)
              ).toList(),
              const SizedBox(height: 16),
            ] else if (pet.preExistingConditions.isNotEmpty) ...[
              _buildSectionHeader('Pre-Existing Conditions', Icons.info_outline),
              const SizedBox(height: 12),
              ...pet.preExistingConditions.map((condition) => 
                _buildSimpleConditionItem(condition)
              ).toList(),
              const SizedBox(height: 16),
            ],
            
            // Medications Section
            if (hasMedications && pet.medications != null && pet.medications!.isNotEmpty) ...[
              _buildSectionHeader('Current Medications', Icons.medication),
              const SizedBox(height: 12),
              ...pet.medications!.where((med) => med.isOngoing).map((medication) => 
                _buildMedicationItem(medication)
              ).toList(),
              const SizedBox(height: 16),
            ],
            
            // Allergies Section
            if (pet.allergies != null && pet.allergies!.isNotEmpty) ...[
              _buildSectionHeader('Allergies', Icons.warning_amber),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pet.allergies!.map((allergy) => 
                  _buildAllergyChip(allergy)
                ).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            // Summary Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (hasDetailedHistory) ...[
                    _buildStatItem(
                      conditionCount.toString(),
                      'Active\nConditions',
                      Colors.orange,
                    ),
                    _buildStatItem(
                      pet.medications?.where((m) => m.isOngoing).length.toString() ?? '0',
                      'Active\nMedications',
                      Colors.blue,
                    ),
                  ] else ...[
                    _buildStatItem(
                      pet.preExistingConditions.length.toString(),
                      'Pre-Existing\nConditions',
                      Colors.orange,
                    ),
                  ],
                  if (pet.vetHistory != null && pet.vetHistory!.isNotEmpty)
                    _buildStatItem(
                      pet.vetHistory!.length.toString(),
                      'Vet\nVisits',
                      Colors.green,
                    ),
                ],
              ),
            ),
            
            // Important Notice
            if (hasDetailedHistory) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your plan may include condition-specific exclusions or waiting periods',
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
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildConditionItem(MedicalCondition condition) {
    final statusColor = _getConditionStatusColor(condition.status);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  condition.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (condition.treatment != null)
                  Text(
                    condition.treatment!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              condition.status.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleConditionItem(String condition) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              condition,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationItem(Medication medication) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.medication, size: 18, color: Colors.blue.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${medication.dosage} - ${medication.frequency}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergyChip(String allergy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber, size: 14, color: Colors.red.shade700),
          const SizedBox(width: 4),
          Text(
            allergy,
            style: TextStyle(
              fontSize: 13,
              color: Colors.red.shade900,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getConditionStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.red;
      case 'managed':
      case 'stable':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildContinueButton(BuildContext context, CheckoutProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () {
            provider.nextStep();
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Continue to Owner Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'By continuing, you agree to our Terms of Service and Privacy Policy',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<Color> _getPlanGradient(planType) {
    switch (planType.toString()) {
      case 'PlanType.elite':
        return [Colors.purple.shade700, Colors.blue.shade700];
      case 'PlanType.plus':
        return [Colors.blue.shade700, Colors.green.shade700];
      default:
        return [Colors.blue.shade600, Colors.blue.shade800];
    }
  }

  IconData _getPlanIcon(planType) {
    switch (planType.toString()) {
      case 'PlanType.elite':
        return Icons.workspace_premium;
      case 'PlanType.plus':
        return Icons.shield;
      default:
        return Icons.shield_outlined;
    }
  }
}
