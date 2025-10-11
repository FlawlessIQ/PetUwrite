import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/petuwrite_theme.dart';

/// Admin Risk Controls Page - Manage underwriting parameters
/// Only accessible to users with userRole == 2
class AdminRiskControlsPage extends StatefulWidget {
  const AdminRiskControlsPage({super.key});

  @override
  State<AdminRiskControlsPage> createState() => _AdminRiskControlsPageState();
}

class _AdminRiskControlsPageState extends State<AdminRiskControlsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Loading and auth state
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _isAuthorized = false;
  DateTime? _lastUpdated;
  
  // Risk Appetite
  double _maxRiskScore = 80.0;
  
  // Breed Exclusions
  final List<String> _availableBreeds = [
    'Pit Bull',
    'Rottweiler',
    'Doberman',
    'German Shepherd',
    'Chow Chow',
    'Akita',
    'Wolf Hybrid',
    'Bulldog',
    'Mastiff',
    'Great Dane',
  ];
  List<String> _excludedBreeds = [];
  
  // Medical Conditions
  final Map<String, bool> _excludedConditions = {
    'Allergies': false,
    'Hip Dysplasia': false,
    'Heart Murmur': false,
    'Diabetes': false,
    'Cancer': false,
    'Kidney Disease': false,
    'Liver Disease': false,
    'Epilepsy': false,
  };
  
  // Pricing Multipliers
  final TextEditingController _basePremiumController = TextEditingController(text: '35.00');
  final TextEditingController _riskMultiplierController = TextEditingController(text: '1.5');
  final TextEditingController _breedAddonController = TextEditingController(text: '0.15');
  final TextEditingController _regionalModifierController = TextEditingController(text: '1.0');
  
  // AI Prompt
  final TextEditingController _aiPromptController = TextEditingController(
    text: 'Analyze pet insurance risk focusing on age, breed health history, and regional factors.',
  );
  
  // UI Flags
  bool _showExplainability = true;
  bool _allowManualOverride = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadSettings();
  }

  @override
  void dispose() {
    _basePremiumController.dispose();
    _riskMultiplierController.dispose();
    _breedAddonController.dispose();
    _regionalModifierController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  /// Check if user has admin role (userRole == 2)
  Future<void> _checkAuthAndLoadSettings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isAuthorized = false;
          _isLoading = false;
        });
        return;
      }

      // Check user role
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userRole = userDoc.data()?['userRole'] as int? ?? 0;

      if (userRole != 2) {
        setState(() {
          _isAuthorized = false;
          _isLoading = false;
        });
        return;
      }

      setState(() => _isAuthorized = true);
      await _loadSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking authorization: $e'),
            backgroundColor: PetUwriteColors.kWarmCoral,
          ),
        );
      }
      setState(() {
        _isAuthorized = false;
        _isLoading = false;
      });
    }
  }

  /// Load settings from Firestore
  Future<void> _loadSettings() async {
    try {
      final doc = await _firestore
          .collection('admin_settings')
          .doc('global_config')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        
        setState(() {
          // Risk Appetite
          _maxRiskScore = (data['risk_max_score'] as num?)?.toDouble() ?? 80.0;
          
          // Breed Exclusions
          _excludedBreeds = List<String>.from(data['excluded_breeds'] ?? []);
          
          // Medical Conditions
          final conditions = data['excluded_conditions'] as Map<String, dynamic>? ?? {};
          conditions.forEach((key, value) {
            if (_excludedConditions.containsKey(key)) {
              _excludedConditions[key] = value as bool;
            }
          });
          
          // Pricing
          final pricing = data['pricing_config'] as Map<String, dynamic>? ?? {};
          _basePremiumController.text = (pricing['base_premium'] ?? 35.0).toString();
          _riskMultiplierController.text = (pricing['risk_multiplier'] ?? 1.5).toString();
          _breedAddonController.text = (pricing['breed_addon'] ?? 0.15).toString();
          _regionalModifierController.text = (pricing['regional_modifier'] ?? 1.0).toString();
          
          // AI Prompt
          _aiPromptController.text = data['ai_prompt_override'] as String? ?? 
              'Analyze pet insurance risk focusing on age, breed health history, and regional factors.';
          
          // UI Flags
          final uiFlags = data['ui_flags'] as Map<String, dynamic>? ?? {};
          _showExplainability = uiFlags['show_explainability'] ?? true;
          _allowManualOverride = uiFlags['allow_manual_override'] ?? false;
          
          // Last Updated
          _lastUpdated = (data['last_updated'] as Timestamp?)?.toDate();
          
          _isLoading = false;
          _hasChanges = false;
        });
      } else {
        // No existing config, use defaults
        setState(() {
          _isLoading = false;
          _hasChanges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: PetUwriteColors.kWarmCoral,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  /// Save all settings to Firestore
  Future<void> _saveSettings() async {
    try {
      final settings = {
        'risk_max_score': _maxRiskScore,
        'excluded_breeds': _excludedBreeds,
        'excluded_conditions': _excludedConditions,
        'pricing_config': {
          'base_premium': double.tryParse(_basePremiumController.text) ?? 35.0,
          'risk_multiplier': double.tryParse(_riskMultiplierController.text) ?? 1.5,
          'breed_addon': double.tryParse(_breedAddonController.text) ?? 0.15,
          'regional_modifier': double.tryParse(_regionalModifierController.text) ?? 1.0,
        },
        'ai_prompt_override': _aiPromptController.text,
        'ui_flags': {
          'show_explainability': _showExplainability,
          'allow_manual_override': _allowManualOverride,
        },
        'last_updated': FieldValue.serverTimestamp(),
        'updated_by': _auth.currentUser?.email ?? 'unknown',
      };

      await _firestore
          .collection('admin_settings')
          .doc('global_config')
          .set(settings, SetOptions(merge: true));

      setState(() {
        _hasChanges = false;
        _lastUpdated = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings updated successfully!'),
            backgroundColor: PetUwriteColors.kSuccessMint,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: PetUwriteColors.kWarmCoral,
          ),
        );
      }
    }
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: PetUwriteColors.kPrimaryNavy,
        appBar: AppBar(
          backgroundColor: PetUwriteColors.kPrimaryNavy,
          title: Text(
            'Admin Risk Controls',
            style: PetUwriteTypography.h3.copyWith(color: Colors.white),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(PetUwriteColors.kSecondaryTeal),
          ),
        ),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: PetUwriteColors.kPrimaryNavy,
        appBar: AppBar(
          backgroundColor: PetUwriteColors.kPrimaryNavy,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: PetUwriteColors.brandGradientSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.block,
                  size: 64,
                  color: PetUwriteColors.kWarmCoral,
                ),
                const SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: PetUwriteTypography.h2.copyWith(
                    color: PetUwriteColors.kPrimaryNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You do not have permission to access this page.\nAdmin role (Level 2) required.',
                  textAlign: TextAlign.center,
                  style: PetUwriteTypography.body.copyWith(
                    color: PetUwriteColors.kPrimaryNavy.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: PetUwriteColors.kPrimaryNavy,
      appBar: AppBar(
        backgroundColor: PetUwriteColors.kPrimaryNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Admin Risk Controls',
          style: PetUwriteTypography.h3.copyWith(color: Colors.white),
        ),
        actions: [
          if (_hasChanges)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: PetUwriteColors.kWarning,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Unsaved',
                    style: PetUwriteTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Last Updated Header
          if (_lastUpdated != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: PetUwriteColors.brandGradientSoft,
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: PetUwriteColors.kPrimaryNavy, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Last Updated: ${_formatDateTime(_lastUpdated!)}',
                    style: PetUwriteTypography.bodySmall.copyWith(
                      color: PetUwriteColors.kPrimaryNavy,
                    ),
                  ),
                ],
              ),
            ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildRiskAppetiteSection(),
                  const SizedBox(height: 16),
                  _buildBreedExclusionSection(),
                  const SizedBox(height: 16),
                  _buildMedicalConditionsSection(),
                  const SizedBox(height: 16),
                  _buildPricingMultipliersSection(),
                  const SizedBox(height: 16),
                  _buildAIPromptSection(),
                  const SizedBox(height: 16),
                  _buildUIFlagsSection(),
                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveSettings,
        backgroundColor: PetUwriteColors.kSecondaryTeal,
        icon: const Icon(Icons.save),
        label: Text(
          'Save Settings',
          style: PetUwriteTypography.button.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildRiskAppetiteSection() {
    return _buildExpansionCard(
      title: 'Risk Appetite',
      icon: Icons.speed,
      children: [
        Text(
          'Maximum Acceptable Risk Score',
          style: PetUwriteTypography.h4.copyWith(
            color: PetUwriteColors.kPrimaryNavy,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Quotes with risk scores above this threshold will be flagged for manual review.',
          style: PetUwriteTypography.bodySmall.copyWith(
            color: PetUwriteColors.kPrimaryNavy.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _maxRiskScore,
                min: 0,
                max: 100,
                divisions: 100,
                activeColor: PetUwriteColors.kSecondaryTeal,
                inactiveColor: PetUwriteColors.kPrimaryNavy.withOpacity(0.2),
                onChanged: (value) {
                  setState(() => _maxRiskScore = value);
                  _markChanged();
                },
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getScoreColor(_maxRiskScore),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_maxRiskScore.toInt()}',
                style: PetUwriteTypography.h3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBreedExclusionSection() {
    return _buildExpansionCard(
      title: 'Breed Exclusion List',
      icon: Icons.pets,
      children: [
        Text(
          'Select breeds that are not eligible for coverage',
          style: PetUwriteTypography.bodySmall.copyWith(
            color: PetUwriteColors.kPrimaryNavy.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableBreeds.map((breed) {
            final isExcluded = _excludedBreeds.contains(breed);
            return FilterChip(
              label: Text(breed),
              selected: isExcluded,
              selectedColor: PetUwriteColors.kWarmCoral,
              checkmarkColor: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.5),
              labelStyle: PetUwriteTypography.bodySmall.copyWith(
                color: isExcluded ? Colors.white : PetUwriteColors.kPrimaryNavy,
                fontWeight: isExcluded ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _excludedBreeds.add(breed);
                  } else {
                    _excludedBreeds.remove(breed);
                  }
                });
                _markChanged();
              },
            );
          }).toList(),
        ),
        if (_excludedBreeds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PetUwriteColors.kWarmCoral.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PetUwriteColors.kWarmCoral),
            ),
            child: Row(
              children: [
                Icon(Icons.block, color: PetUwriteColors.kWarmCoral, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_excludedBreeds.length} breed(s) excluded',
                    style: PetUwriteTypography.bodySmall.copyWith(
                      color: PetUwriteColors.kPrimaryNavy,
                      fontWeight: FontWeight.bold,
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

  Widget _buildMedicalConditionsSection() {
    return _buildExpansionCard(
      title: 'Medical Condition Flags',
      icon: Icons.medical_services,
      children: [
        Text(
          'Toggle pre-existing conditions that trigger automatic exclusions or higher premiums',
          style: PetUwriteTypography.bodySmall.copyWith(
            color: PetUwriteColors.kPrimaryNavy.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        ..._excludedConditions.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SwitchListTile(
              title: Text(
                entry.key,
                style: PetUwriteTypography.body.copyWith(
                  color: PetUwriteColors.kPrimaryNavy,
                ),
              ),
              value: entry.value,
              activeColor: PetUwriteColors.kSecondaryTeal,
              onChanged: (value) {
                setState(() => _excludedConditions[entry.key] = value);
                _markChanged();
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPricingMultipliersSection() {
    return _buildExpansionCard(
      title: 'Pricing Multipliers',
      icon: Icons.attach_money,
      children: [
        Text(
          'Configure base pricing and risk adjustment factors',
          style: PetUwriteTypography.bodySmall.copyWith(
            color: PetUwriteColors.kPrimaryNavy.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          label: 'Base Premium (\$)',
          controller: _basePremiumController,
          helper: 'Starting monthly premium before adjustments',
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          label: 'Risk Multiplier',
          controller: _riskMultiplierController,
          helper: 'Multiplier applied per risk score (e.g., 1.5 = 50% increase at max risk)',
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          label: 'Breed Risk Add-on',
          controller: _breedAddonController,
          helper: 'Additional percentage for high-risk breeds (0.15 = 15%)',
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          label: 'Regional Modifier',
          controller: _regionalModifierController,
          helper: 'Regional cost adjustment (1.0 = baseline, 1.1 = 10% higher)',
        ),
      ],
    );
  }

  Widget _buildAIPromptSection() {
    return _buildExpansionCard(
      title: 'AI Prompt Tweaks',
      icon: Icons.auto_awesome,
      children: [
        Text(
          'Customize the system prompt sent to GPT-4o for risk analysis',
          style: PetUwriteTypography.bodySmall.copyWith(
            color: PetUwriteColors.kPrimaryNavy.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _aiPromptController,
          maxLines: 5,
          style: PetUwriteTypography.body.copyWith(
            color: PetUwriteColors.kPrimaryNavy,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: PetUwriteColors.kSecondaryTeal),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: PetUwriteColors.kPrimaryNavy.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: PetUwriteColors.kSecondaryTeal, width: 2),
            ),
            hintText: 'Enter custom AI prompt instructions...',
            hintStyle: PetUwriteTypography.body.copyWith(
              color: PetUwriteColors.kPrimaryNavy.withOpacity(0.4),
            ),
          ),
          onChanged: (_) => _markChanged(),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PetUwriteColors.kSecondaryTeal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: PetUwriteColors.kSecondaryTeal.withOpacity(0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: PetUwriteColors.kSecondaryTeal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This prompt is prepended to all AI risk analysis requests. Changes affect all new quotes.',
                  style: PetUwriteTypography.bodySmall.copyWith(
                    color: PetUwriteColors.kPrimaryNavy.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUIFlagsSection() {
    return _buildExpansionCard(
      title: 'Quote Display Settings',
      icon: Icons.settings_display,
      children: [
        Text(
          'Control what information is shown to users and admins',
          style: PetUwriteTypography.bodySmall.copyWith(
            color: PetUwriteColors.kPrimaryNavy.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SwitchListTile(
            title: Text(
              'Show Explainability Factors',
              style: PetUwriteTypography.body.copyWith(
                color: PetUwriteColors.kPrimaryNavy,
              ),
            ),
            subtitle: Text(
              'Display detailed risk breakdown to customers',
              style: PetUwriteTypography.bodySmall.copyWith(
                color: PetUwriteColors.kPrimaryNavy.withOpacity(0.6),
              ),
            ),
            value: _showExplainability,
            activeColor: PetUwriteColors.kSecondaryTeal,
            onChanged: (value) {
              setState(() => _showExplainability = value);
              _markChanged();
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SwitchListTile(
            title: Text(
              'Allow Manual Override by Underwriter',
              style: PetUwriteTypography.body.copyWith(
                color: PetUwriteColors.kPrimaryNavy,
              ),
            ),
            subtitle: Text(
              'Permit admin users to manually adjust quotes',
              style: PetUwriteTypography.bodySmall.copyWith(
                color: PetUwriteColors.kPrimaryNavy.withOpacity(0.6),
              ),
            ),
            value: _allowManualOverride,
            activeColor: PetUwriteColors.kSecondaryTeal,
            onChanged: (value) {
              setState(() => _allowManualOverride = value);
              _markChanged();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpansionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: PetUwriteColors.brandGradientSoft,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: PetUwriteColors.kSecondaryTeal.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PetUwriteColors.kSecondaryTeal,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          title: Text(
            title,
            style: PetUwriteTypography.h4.copyWith(
              color: PetUwriteColors.kPrimaryNavy,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconColor: PetUwriteColors.kSecondaryTeal,
          collapsedIconColor: PetUwriteColors.kPrimaryNavy,
          children: children,
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required String helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: PetUwriteTypography.h4.copyWith(
            color: PetUwriteColors.kPrimaryNavy,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: PetUwriteTypography.body.copyWith(
            color: PetUwriteColors.kPrimaryNavy,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: PetUwriteColors.kPrimaryNavy.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: PetUwriteColors.kSecondaryTeal, width: 2),
            ),
            hintText: '0.00',
            hintStyle: PetUwriteTypography.body.copyWith(
              color: PetUwriteColors.kPrimaryNavy.withOpacity(0.4),
            ),
          ),
          onChanged: (_) => _markChanged(),
        ),
        const SizedBox(height: 4),
        Text(
          helper,
          style: PetUwriteTypography.bodySmall.copyWith(
            color: PetUwriteColors.kPrimaryNavy.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score < 30) return PetUwriteColors.kSuccessMint;
    if (score < 60) return PetUwriteColors.kSecondaryTeal;
    if (score < 80) return PetUwriteColors.kWarning;
    return PetUwriteColors.kWarmCoral;
  }

  String _formatDateTime(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$month $day, $year at $hour:$minute';
  }
}
