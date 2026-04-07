import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/checkout_state.dart';
import '../models/medical_history.dart';
import '../ui/components/max_width.dart';

/// Step 1: Review pet and quote information
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _exclusionsAcknowledged = false;
  String _exclusionsKey = '';

  String _formatAnnualLimit(plan) {
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

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return MaxWidth(
              maxWidth: 980,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: isDesktop ? 32 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pet.name}\'s coverage summary',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Everything looks great — let\'s lock this in.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Step 1 of 4',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w700,
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

                      // Exclusions Card (if any)
                      if (provider.exclusions.isNotEmpty)
                        _buildExclusionsCard(provider.exclusions),
                      if (provider.exclusions.isNotEmpty)
                        const SizedBox(height: 16),

                      // Exclusions acknowledgement (required)
                      if (provider.exclusions.isNotEmpty)
                        _buildExclusionsAcknowledgement(provider),
                      if (provider.exclusions.isNotEmpty)
                        const SizedBox(height: 16),

                      // Features Card (Coverage Details card removed — info already in plan banner)
                      _buildFeaturesCard(plan),
                      const SizedBox(height: 24),

                      // Continue Button
                      _buildContinueButton(
                        context,
                        provider,
                        isEnabled:
                            provider.exclusions.isEmpty ||
                            _exclusionsAcknowledged,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
            provider.recordExclusionsAcknowledgement(source: 'review');
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

  Widget _buildPetInfoCard(pet) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.pets,
                    size: 28,
                    color: const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${pet.breed} \u2022 ${pet.species}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
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
            _buildInfoRow(
              'Age',
              '${pet.ageInYears} years old',
              Icons.calendar_today,
            ),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0B3D2E),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getPlanIcon(plan.type), size: 24, color: Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '\$${plan.monthlyPremium.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              Text(
                '/mo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
          if (plan.multiPetDiscount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.shade400.withOpacity(0.25),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Multi-pet discount: -\$${plan.discountAmount.toStringAsFixed(2)}/mo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('${plan.reimbursementPercent}% reimbursement'),
              _pill('\$${plan.annualDeductible.toStringAsFixed(0)} deductible'),
              _pill('${_formatAnnualLimit(plan)} annual limit'),
              if ((plan.selectedAddOns as List).isNotEmpty)
                _pill('Add-ons: ${(plan.selectedAddOns as List).join(', ')}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildExclusionsCard(List exclusions) {
    final exclusionNames =
        exclusions
            .map((e) {
              if (e is String) return e;
              try {
                // PolicyExclusion shape
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.gpp_maybe,
                    size: 24,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Coverage exclusions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'This policy will not cover treatment related to these conditions:',
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

  Widget _buildFeaturesCard(plan) {
    final features = (plan.features as List<dynamic>).cast<String>();
    // Supplementary trust-building benefits
    const supplementary = [
      'No breed exclusions',
      'Coverage starts in 14 days',
      '24/7 online claims submission',
      'Direct deposit reimbursement',
      'No annual vet exam required',
      'Cancel anytime, no penalties',
    ];
    final extra = supplementary
        .where((s) => !features.any((f) => f.toLowerCase().contains(s.split(' ').first.toLowerCase())))
        .toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What\'s included',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ...features
                .take(8)
                .map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle, size: 18, color: const Color(0xFF16A34A)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ...extra.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, size: 18, color: Colors.grey.shade400),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
              ),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
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
                        style: TextStyle(fontSize: 14, color: Colors.grey),
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
            if (hasDetailedHistory &&
                pet.medicalConditions != null &&
                pet.medicalConditions!.isNotEmpty) ...[
              _buildSectionHeader('Medical Conditions', Icons.healing),
              const SizedBox(height: 12),
              ...pet.medicalConditions!
                  .map((condition) => _buildConditionItem(condition))
                  .toList(),
              const SizedBox(height: 16),
            ] else if (pet.preExistingConditions.isNotEmpty) ...[
              _buildSectionHeader(
                'Pre-Existing Conditions',
                Icons.info_outline,
              ),
              const SizedBox(height: 12),
              ...pet.preExistingConditions
                  .map((condition) => _buildSimpleConditionItem(condition))
                  .toList(),
              const SizedBox(height: 16),
            ],

            // Medications Section
            if (hasMedications &&
                pet.medications != null &&
                pet.medications!.isNotEmpty) ...[
              _buildSectionHeader('Current Medications', Icons.medication),
              const SizedBox(height: 12),
              ...pet.medications!
                  .where((med) => med.isOngoing)
                  .map((medication) => _buildMedicationItem(medication))
                  .toList(),
              const SizedBox(height: 16),
            ],

            // Allergies Section
            if (pet.allergies != null && pet.allergies!.isNotEmpty) ...[
              _buildSectionHeader('Allergies', Icons.warning_amber),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pet.allergies!
                    .map((allergy) => _buildAllergyChip(allergy))
                    .toList(),
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
                      pet.medications
                              ?.where((m) => m.isOngoing)
                              .length
                              .toString() ??
                          '0',
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
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
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
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
            child: Text(condition, style: const TextStyle(fontSize: 15)),
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
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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

  Widget _buildContinueButton(
    BuildContext context,
    CheckoutProvider provider, {
    required bool isEnabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isEnabled)
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
        ElevatedButton(
          onPressed: isEnabled
              ? () {
                  provider.nextStep();
                }
              : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Continue for ${provider.pet?.name ?? 'your pet'}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 13, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text('Cancel anytime', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
            const SizedBox(width: 14),
            Icon(Icons.verified_user_outlined, size: 13, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text('No hidden fees', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'By continuing, you agree to our Terms of Service and Privacy Policy',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  IconData _getPlanIcon(planType) {
    switch (planType.toString()) {
      case 'PlanType.unlimited':
        return Icons.all_inclusive;
      case 'PlanType.premium':
        return Icons.workspace_premium;
      case 'PlanType.plus':
        return Icons.shield;
      case 'PlanType.standard':
        return Icons.verified_user_outlined;
      default:
        return Icons.shield_outlined;
    }
  }
}
