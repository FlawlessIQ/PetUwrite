import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../admin_console/components/admin_section_card.dart';
import '../admin_console/components/admin_status_chip.dart';
import '../config/pricing_config.dart';
import '../theme/clovara_theme.dart';
import '../services/underwriting_rules_engine.dart';

/// Admin Rules Editor Page
///
/// Allows admin users (userRole == 2) to update underwriting rules
/// stored in Firestore: admin_settings/underwriting_rules
///
/// Features:
/// - Real-time rule loading
/// - Intuitive expansion tiles for each rule category
/// - Add/remove chips for breeds and conditions
/// - Validation on numeric inputs
/// - Last updated timestamp display
/// - Role-based access control
class AdminRulesEditorPage extends StatefulWidget {
  const AdminRulesEditorPage({super.key});

  @override
  State<AdminRulesEditorPage> createState() => _AdminRulesEditorPageState();
}

class _AdminRulesEditorPageState extends State<AdminRulesEditorPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final UnderwritingRulesEngine _rulesEngine = UnderwritingRulesEngine(
    enablePublicCallable: false,
  );

  // Form controllers
  final _maxRiskScoreController = TextEditingController();
  final _minAgeMonthsController = TextEditingController();
  final _maxAgeYearsController = TextEditingController();
  final _newBreedController = TextEditingController();
  final _newConditionController = TextEditingController();

  // State
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasAccess = false;
  bool _enabled = true;
  bool _overrideEditingEnabled = false;
  double _maxRiskScoreSlider = 85.0;
  List<String> _excludedBreeds = [];
  List<String> _criticalConditions = [];
  List<String> _excludableConditions = [];
  DateTime? _lastUpdated;
  String? _lastUpdatedBy;

  int? _rulesVersion;
  String? _effectiveDate;
  DateTime? _publishedAt;
  String? _publishedBy;
  String? _changeNotes;
  String? _canonicalPath;

  // Pricing versions state
  String? _activePricingVersionId;
  Map<String, dynamic>? _activePricingConfig;
  bool _isSavingPricing = false;

  // Theme colors

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoadRules();
  }

  @override
  void dispose() {
    _maxRiskScoreController.dispose();
    _minAgeMonthsController.dispose();
    _maxAgeYearsController.dispose();
    _newBreedController.dispose();
    _newConditionController.dispose();
    super.dispose();
  }

  /// Check if user has admin access (userRole == 2)
  Future<void> _checkAccessAndLoadRules() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
        return;
      }

      // Prefer custom claim.
      bool claimAdmin = false;
      try {
        final token = await user.getIdTokenResult(true);
        claimAdmin = token.claims?['admin'] == true;
      } catch (_) {
        // Ignore and fall back to Firestore role.
      }

      // Check user role in users collection
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final userRole = userData?['userRole'] ?? 0;

      final roleAdmin = userRole == 2 || userRole == 3;
      if (!claimAdmin && !roleAdmin) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
        return;
      }

      // User has access, load rules
      setState(() => _hasAccess = true);
      await _loadRules();

      // Load pricing meta (best-effort).
      await _loadActivePricingMeta();
    } catch (e) {
      print('Error checking access: $e');
      setState(() {
        _hasAccess = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadActivePricingMeta() async {
    try {
      final snap = await _firestore
          .collection('pricing_meta')
          .doc('active')
          .get();
      final id = (snap.data()?['activeVersionId'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() => _activePricingVersionId = id.isEmpty ? null : id);

      if (id.isEmpty) {
        setState(() => _activePricingConfig = null);
        return;
      }

      final versionSnap = await _firestore
          .collection('pricing_versions')
          .doc(id)
          .get();
      final raw = versionSnap.data();
      final cfg = (raw?['config'] is Map)
          ? (raw?['config'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() => _activePricingConfig = cfg.isEmpty ? null : cfg);
    } catch (_) {
      // Best-effort: pricing UI will still render.
    }
  }

  Map<String, dynamic> _defaultPricingConfigMap() {
    final annualLimitFactors = <String, dynamic>{
      for (final entry in PricingConfig.annualLimitFactors.entries)
        (entry.key == null ? 'unlimited' : entry.key.toString()): entry.value,
    };

    final multiPetDiscounts = <String, dynamic>{
      for (final entry in PricingConfig.multiPetDiscounts.entries)
        entry.key.toString(): entry.value,
    };

    return {
      'version': PricingConfig.version,
      'effectiveDateIso': PricingConfig.effectiveDateIso,
      'notes': PricingConfig.notes,
      'baseRiskRate': PricingConfig.baseRiskRate,
      'regionalAdjustments': PricingConfig.regionalAdjustments,
      'multiPetDiscounts': multiPetDiscounts,
      'riskBandMultipliers': {
        for (final entry in PricingConfig.riskBandMultipliers.entries)
          entry.key.name: entry.value,
      },
      'reimbursementFactors': {
        for (final entry in PricingConfig.reimbursementFactors.entries)
          entry.key.toString(): entry.value,
      },
      'deductibleFactors': {
        for (final entry in PricingConfig.deductibleFactors.entries)
          entry.key.toString(): entry.value,
      },
      'annualLimitFactors': annualLimitFactors,
      'addOnMonthlyLoads': {
        for (final entry in PricingConfig.addOnMonthlyLoads.entries)
          entry.key.name: entry.value,
      },
      'minMonthlyPremium': PricingConfig.minMonthlyPremium,
    };
  }

  /// Ensures values are JSON-encodable (notably: Map keys must be strings).
  dynamic _jsonify(dynamic value) {
    if (value == null) return null;
    if (value is num || value is bool || value is String) return value;

    if (value is Map) {
      final out = <String, dynamic>{};
      for (final entry in value.entries) {
        out[entry.key.toString()] = _jsonify(entry.value);
      }
      return out;
    }

    if (value is Iterable) {
      return value.map(_jsonify).toList(growable: false);
    }

    return value.toString();
  }

  String _prettyJson(Map<String, dynamic> value) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(_jsonify(value));
  }

  Future<void> _upsertPricingVersion({
    required String versionId,
    required Map<String, dynamic> config,
    String status = 'draft',
  }) async {
    setState(() => _isSavingPricing = true);
    try {
      final sanitized = _jsonify(config);
      final Map<String, dynamic> safeConfig = sanitized is Map
          ? sanitized.cast<String, dynamic>()
          : <String, dynamic>{};

      final callable = _functions.httpsCallable('upsertPricingVersionAdmin');
      await callable.call({
        'versionId': versionId,
        'status': status,
        'config': safeConfig,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Saved pricing version: $versionId'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to save pricing version: $e');
    } finally {
      if (mounted) setState(() => _isSavingPricing = false);
    }
  }

  Future<void> _setActivePricingVersion(String versionId) async {
    setState(() => _isSavingPricing = true);
    try {
      final callable = _functions.httpsCallable('setActivePricingVersionAdmin');
      await callable.call({'versionId': versionId});

      await _loadActivePricingMeta();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Active pricing set to: $versionId'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to set active pricing: $e');
    } finally {
      if (mounted) setState(() => _isSavingPricing = false);
    }
  }

  Future<void> _showPricingEditorDialog({
    required String versionId,
    required Map<String, dynamic> initialConfig,
    String initialStatus = 'draft',
  }) async {
    final controller = TextEditingController(text: _prettyJson(initialConfig));
    String status = initialStatus;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.price_change_outlined, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('Edit pricing: $versionId')),
            ],
          ),
          content: SizedBox(
            width: 720,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: status,
                      onChanged: (v) => status = v ?? status,
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('draft')),
                        DropdownMenuItem(
                          value: 'published',
                          child: Text('published'),
                        ),
                        DropdownMenuItem(
                          value: 'retired',
                          child: Text('retired'),
                        ),
                      ],
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        controller.text = _prettyJson(
                          _defaultPricingConfigMap(),
                        );
                      },
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('Reset to defaults'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                    color: scheme.surface,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: controller,
                    maxLines: 18,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.3,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: '{\n  "baseRiskRate": 45.0,\n  ...\n}',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                try {
                  final parsed = jsonDecode(controller.text);
                  if (parsed is! Map) {
                    throw const FormatException('Root JSON must be an object');
                  }
                  final config = parsed.cast<String, dynamic>();
                  Navigator.pop(context);
                  await _upsertPricingVersion(
                    versionId: versionId,
                    config: config,
                    status: status,
                  );
                } catch (e) {
                  _showError('Invalid JSON: $e');
                }
              },
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Load rules from Firestore
  Future<void> _loadRules() async {
    try {
      final doc = await _firestore
          .collection('admin_settings')
          .doc('underwriting_rules')
          .get();

      if (!doc.exists) {
        throw StateError(
          'Underwriting rules are not published yet. Publish from config/underwriting_rules.v1.yaml using tools/underwriting_rules/publish_underwriting_rules.js',
        );
      }

      final rules = doc.data() ?? <String, dynamic>{};

      final maxRiskScore = rules['maxRiskScore'];
      final minAgeMonths = rules['minAgeMonths'];
      final maxAgeYears = rules['maxAgeYears'];
      if (maxRiskScore is! int || minAgeMonths is! int || maxAgeYears is! int) {
        throw StateError(
          'Underwriting rules are missing required numeric fields.',
        );
      }

      final excludedBreedsRaw = rules['excludedBreeds'];
      final criticalConditionsRaw = rules['criticalConditions'];
      if (excludedBreedsRaw is! List || criticalConditionsRaw is! List) {
        throw StateError(
          'Underwriting rules are missing required list fields.',
        );
      }

      setState(() {
        _enabled = rules['enabled'] as bool? ?? true;
        _maxRiskScoreSlider = maxRiskScore.toDouble();
        _maxRiskScoreController.text = _maxRiskScoreSlider.toInt().toString();
        _minAgeMonthsController.text = minAgeMonths.toString();
        _maxAgeYearsController.text = maxAgeYears.toString();
        _excludedBreeds = List<String>.from(excludedBreedsRaw);
        _criticalConditions = List<String>.from(criticalConditionsRaw);
        _excludableConditions = List<String>.from(
          rules['excludableConditions'] as List? ?? [],
        );

        // Parse timestamp
        if (rules['lastUpdated'] != null) {
          if (rules['lastUpdated'] is Timestamp) {
            _lastUpdated = (rules['lastUpdated'] as Timestamp).toDate();
          } else if (rules['lastUpdated'] is String) {
            _lastUpdated = DateTime.tryParse(rules['lastUpdated'] as String);
          }
        }
        _lastUpdatedBy = rules['updatedBy'] as String?;

        _rulesVersion = rules['rulesVersion'] is int
            ? rules['rulesVersion'] as int
            : null;
        _effectiveDate = rules['effectiveDate'] as String?;
        _changeNotes = rules['changeNotes'] as String?;
        _canonicalPath = rules['canonicalPath'] as String?;

        if (rules['publishedAt'] is Timestamp) {
          _publishedAt = (rules['publishedAt'] as Timestamp).toDate();
        } else if (rules['publishedAt'] is String) {
          _publishedAt = DateTime.tryParse(rules['publishedAt'] as String);
        }
        _publishedBy = rules['publishedBy'] as String?;

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading rules: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading rules: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  /// Save rules to Firestore
  Future<void> _saveRules() async {
    if (!_overrideEditingEnabled) {
      _showError(
        'Editing is locked. Enable Emergency Override to save changes.',
      );
      return;
    }

    // Validate inputs
    final maxRiskScore = int.tryParse(_maxRiskScoreController.text);
    final minAgeMonths = int.tryParse(_minAgeMonthsController.text);
    final maxAgeYears = int.tryParse(_maxAgeYearsController.text);

    if (maxRiskScore == null || maxRiskScore < 50 || maxRiskScore > 100) {
      _showError('Max Risk Score must be between 50 and 100');
      return;
    }

    if (minAgeMonths == null || minAgeMonths < 0 || minAgeMonths > 24) {
      _showError('Min Age must be between 0 and 24 months');
      return;
    }

    if (maxAgeYears == null || maxAgeYears < 1 || maxAgeYears > 25) {
      _showError('Max Age must be between 1 and 25 years');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;

      // Preserve fields not editable in the UI (ex: excludableConditions).
      final existing = await _firestore
          .collection('admin_settings')
          .doc('underwriting_rules')
          .get();
      final existingData = existing.data() ?? <String, dynamic>{};
      final preservedExcludable = List<String>.from(
        existingData['excludableConditions'] as List? ?? _excludableConditions,
      );
      final preservedCanonicalPath = existingData['canonicalPath'] as String?;

      // Governance / versioning: write immutable history before updating current.
      final currentVersion =
          (existingData['rulesVersion'] is int
              ? existingData['rulesVersion'] as int
              : null) ??
          (_rulesVersion ?? 0);
      int versionToUse = currentVersion + 1;
      while (true) {
        final probe = await _firestore
            .collection('underwriting_rules_history')
            .doc(versionToUse.toString())
            .get();
        if (!probe.exists) break;
        versionToUse++;
      }

      final effectiveDate = DateTime.now().toUtc().toIso8601String().substring(
        0,
        10,
      );
      final changeNotes = 'Updated via Admin UI';

      final updateData = {
        'enabled': _enabled,
        'maxRiskScore': maxRiskScore,
        'minAgeMonths': minAgeMonths,
        'maxAgeYears': maxAgeYears,
        'excludedBreeds': _excludedBreeds,
        'criticalConditions': _criticalConditions,
        'excludableConditions': preservedExcludable,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': user?.email ?? 'Unknown',

        // Governance metadata (kept in the published artifact)
        'rulesVersion': versionToUse,
        'effectiveDate': effectiveDate,
        'changeNotes': changeNotes,
        'publishedAt': FieldValue.serverTimestamp(),
        'publishedBy': user?.email ?? 'Unknown',
        if (preservedCanonicalPath != null)
          'canonicalPath': preservedCanonicalPath,
      };

      await _firestore
          .collection('underwriting_rules_history')
          .doc(versionToUse.toString())
          .set({
            ...updateData,
            'historyCreatedAt': FieldValue.serverTimestamp(),
          });

      await _firestore
          .collection('admin_settings')
          .doc('underwriting_rules')
          .set(updateData, SetOptions(merge: true));

      // Clear cache to force reload
      _rulesEngine.clearCache();

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Rules updated successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Reload rules to show updated timestamp
      await _loadRules();
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Failed to save rules: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _promptEnableOverride() async {
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enable Emergency Override?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Underwriting rules should be published from the canonical YAML. Enabling override allows direct edits in Firestore and can cause drift.',
              ),
              const SizedBox(height: 12),
              const Text('Type OVERRIDE to continue:'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'OVERRIDE',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(context, text.toUpperCase() == 'OVERRIDE');
              },
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (ok == true) {
      setState(() => _overrideEditingEnabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Emergency override enabled. Changes will write to Firestore.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      _showError('Emergency override not enabled.');
    }
  }

  /// Add a breed to excluded list
  void _addBreed() {
    final breed = _newBreedController.text.trim();
    if (breed.isEmpty) return;

    if (_excludedBreeds.contains(breed)) {
      _showError('Breed already in list');
      return;
    }

    setState(() {
      _excludedBreeds.add(breed);
      _newBreedController.clear();
    });
  }

  /// Remove a breed from excluded list
  void _removeBreed(String breed) {
    setState(() {
      _excludedBreeds.remove(breed);
    });
  }

  /// Add a condition to critical list
  void _addCondition() {
    final condition = _newConditionController.text.trim();
    if (condition.isEmpty) return;

    if (_criticalConditions.contains(condition.toLowerCase())) {
      _showError('Condition already in list');
      return;
    }

    setState(() {
      _criticalConditions.add(condition.toLowerCase());
      _newConditionController.clear();
    });
  }

  /// Remove a condition from critical list
  void _removeCondition(String condition) {
    setState(() {
      _criticalConditions.remove(condition);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasAccess) {
      return AdminSectionCard(
        title: 'Access Denied',
        icon: Icons.lock_outline,
        actions: [
          AdminStatusChip(
            label: 'Required: userRole = 2',
            color: ClovaraColors.kError,
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You do not have permission to access underwriting rules editing.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'If you believe this is an error, verify your user role in Firestore: users/{uid}.userRole.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Main content
        SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Last Updated Info
              _buildLastUpdatedCard(),
              const SizedBox(height: 12),
              _buildGovernanceCard(),
              const SizedBox(height: 16),

              // Master Enable/Disable Switch
              _buildEnableSwitch(),
              const SizedBox(height: 16),

              // Rules Editor
              _buildRiskScoreSection(),
              const SizedBox(height: 12),
              _buildAgeRangeSection(),
              const SizedBox(height: 12),
              _buildExcludedBreedsSection(),
              const SizedBox(height: 12),
              _buildCriticalConditionsSection(),
              const SizedBox(height: 12),
              _buildExcludableConditionsSection(),
              const SizedBox(height: 12),
              _buildPricingVersionsSection(),
              const SizedBox(height: 24),

              // Save Button
              _buildSaveButton(),
              const SizedBox(height: 80), // Extra space for FAB
            ],
          ),
        ),

        // Loading overlay
        if (_isSaving || _isSavingPricing)
          Container(
            color: Colors.black26,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Saving...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPricingVersionsSection() {
    final activeId = _activePricingVersionId;
    final baselineConfig = _activePricingConfig ?? _defaultPricingConfigMap();

    return AdminSectionCard(
      title: 'Pricing Versions',
      icon: Icons.price_change_outlined,
      actions: [
        if (activeId != null)
          AdminStatusChip(
            label: 'Active: $activeId',
            color: ClovaraColors.forest,
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: () async {
                  final now = DateTime.now().toUtc();
                  final suggestedId =
                      'v_admin_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';

                  try {
                    // Make the click visibly do something even before opening the editor.
                    await _upsertPricingVersion(
                      versionId: suggestedId,
                      config: baselineConfig,
                      status: 'draft',
                    );
                    await _showPricingEditorDialog(
                      versionId: suggestedId,
                      initialConfig: baselineConfig,
                      initialStatus: 'draft',
                    );
                  } catch (e) {
                    if (!mounted) return;
                    _showError('Failed to start new pricing version: $e');
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New version'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _loadActivePricingMeta,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
              const Spacer(),
              Text(
                'Clients use callable pricing; this table is admin-only.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPricingBaselinePanel(baselineConfig: baselineConfig),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('pricing_versions')
                .orderBy('updatedAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Text(
                  'Failed to load pricing versions: ${snapshot.error}',
                  style: TextStyle(color: ClovaraColors.kWarmCoral),
                );
              }

              final docs = snapshot.data?.docs ?? const [];
              if (docs.isEmpty) {
                return Text(
                  'No pricing versions yet. Create one to begin.',
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              }

              return Column(
                children: [
                  for (final doc in docs)
                    _PricingVersionTile(
                      id: doc.id,
                      data: doc.data(),
                      activeId: activeId,
                      onActivate: () => _setActivePricingVersion(doc.id),
                      onEdit: () {
                        final raw = doc.data();
                        final config = (raw['config'] is Map)
                            ? (raw['config'] as Map).cast<String, dynamic>()
                            : <String, dynamic>{};
                        final status = (raw['status'] ?? 'draft').toString();

                        _showPricingEditorDialog(
                          versionId: doc.id,
                          initialConfig: config.isEmpty
                              ? _defaultPricingConfigMap()
                              : config,
                          initialStatus: status,
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPricingBaselinePanel({
    required Map<String, dynamic> baselineConfig,
  }) {
    final activeId = _activePricingVersionId;
    final hasActive = _activePricingConfig != null && activeId != null;
    final title = hasActive
        ? 'Current pricing (active)'
        : 'Current pricing (app defaults)';

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 10),
      title: Row(
        children: [
          const Icon(Icons.data_object_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: ClovaraColors.forest,
              ),
            ),
          ),
          if (hasActive)
            AdminStatusChip(label: activeId, color: Colors.blueGrey.shade700),
        ],
      ),
      subtitle: Text(
        'Use this as a baseline when editing versions.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final text = _prettyJson(baselineConfig);
                await Clipboard.setData(ClipboardData(text: text));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied pricing JSON to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy JSON'),
            ),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: () {
                final id = _activePricingVersionId;
                if (id == null || _activePricingConfig == null) {
                  _showPricingEditorDialog(
                    versionId:
                        'v_baseline_${DateTime.now().toUtc().toIso8601String().substring(0, 10)}',
                    initialConfig: _defaultPricingConfigMap(),
                    initialStatus: 'draft',
                  );
                  return;
                }

                _showPricingEditorDialog(
                  versionId:
                      'v_from_${id}_${DateTime.now().toUtc().toIso8601String().substring(0, 10)}',
                  initialConfig: baselineConfig,
                  initialStatus: 'draft',
                );
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open baseline in editor'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surface,
          ),
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            _prettyJson(baselineConfig),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLastUpdatedCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: ClovaraColors.clover.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ClovaraColors.clover.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.update, color: ClovaraColors.clover, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Updated',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lastUpdated != null
                        ? _formatDateTime(_lastUpdated!)
                        : 'Never',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ClovaraColors.forest,
                    ),
                  ),
                  if (_lastUpdatedBy != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'by $_lastUpdatedBy',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGovernanceCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Governance',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                AdminStatusChip(
                  label: _rulesVersion != null
                      ? 'Version: $_rulesVersion'
                      : 'Version: (none)',
                  color: ClovaraColors.forest,
                ),
                if (_effectiveDate != null)
                  AdminStatusChip(
                    label: 'Effective: $_effectiveDate',
                    color: ClovaraColors.clover,
                  ),
                if (_publishedAt != null)
                  AdminStatusChip(
                    label: 'Published: ${_formatDateTime(_publishedAt!)}',
                    color: ClovaraColors.clover,
                  ),
                if (_publishedBy != null)
                  AdminStatusChip(
                    label: 'By: $_publishedBy',
                    color: ClovaraColors.clover,
                  ),
              ],
            ),
            if (_changeNotes != null && _changeNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Change notes: ${_changeNotes!}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.75),
                ),
              ),
            ],
            if (_canonicalPath != null &&
                _canonicalPath!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Canonical source: ${_canonicalPath!}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.75),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Editing is locked by default to prevent drift. Publish updates from canonical YAML whenever possible.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_overrideEditingEnabled)
                  AdminStatusChip(
                    label: 'Emergency override: ON',
                    color: Colors.orange.shade800,
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _promptEnableOverride,
                    icon: const Icon(Icons.lock_open_outlined, size: 18),
                    label: const Text('Enable emergency override'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExcludableConditionsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.rule_folder_outlined, color: Colors.blue),
        ),
        title: const Text(
          'Excludable Conditions (Read-only)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_excludableConditions.length} condition(s)',
          style: const TextStyle(fontSize: 13),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'These conditions result in conditional approval (excluded from coverage). Managed via canonical YAML publish pipeline.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                if (_excludableConditions.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No excludable conditions',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _excludableConditions
                        .map(
                          (condition) => Chip(
                            label: Text(condition),
                            backgroundColor: Colors.blue.shade50,
                            side: BorderSide(color: Colors.blue.shade200),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnableSwitch() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        value: _enabled,
        onChanged: _overrideEditingEnabled
            ? (value) => setState(() => _enabled = value)
            : null,
        title: Text(
          'Rules Engine Enabled',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ClovaraColors.forest,
          ),
        ),
        subtitle: Text(
          _enabled
              ? 'Rules are actively enforced on all quotes'
              : 'Rules are disabled - all quotes will be approved',
          style: TextStyle(
            fontSize: 13,
            color: _enabled ? ClovaraColors.clover : ClovaraColors.kWarmCoral,
          ),
        ),
        activeColor: ClovaraColors.clover,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _enabled
                ? ClovaraColors.clover.withOpacity(0.1)
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _enabled ? Icons.check_circle : Icons.block,
            color: _enabled ? ClovaraColors.clover : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskScoreSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ClovaraColors.sunset.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.analytics, color: ClovaraColors.sunset),
        ),
        title: const Text(
          'Maximum Risk Score',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Current: ${_maxRiskScoreSlider.toInt()}/100',
          style: const TextStyle(fontSize: 13),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pets with risk scores above this threshold will be automatically declined.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _maxRiskScoreSlider,
                        min: 50,
                        max: 100,
                        divisions: 50,
                        label: _maxRiskScoreSlider.toInt().toString(),
                        activeColor: ClovaraColors.clover,
                        onChanged: _overrideEditingEnabled
                            ? (value) {
                                setState(() {
                                  _maxRiskScoreSlider = value;
                                  _maxRiskScoreController.text = value
                                      .toInt()
                                      .toString();
                                });
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _maxRiskScoreController,
                        enabled: _overrideEditingEnabled,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          suffixText: '/100',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: _overrideEditingEnabled
                            ? (value) {
                                final score = int.tryParse(value);
                                if (score != null &&
                                    score >= 50 &&
                                    score <= 100) {
                                  setState(
                                    () =>
                                        _maxRiskScoreSlider = score.toDouble(),
                                  );
                                }
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '50 (Low)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      '100 (High)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeRangeSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ClovaraColors.clover.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.cake, color: ClovaraColors.clover),
        ),
        title: const Text(
          'Age Limits',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_minAgeMonthsController.text} months - ${_maxAgeYearsController.text} years',
          style: const TextStyle(fontSize: 13),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _minAgeMonthsController,
                  enabled: _overrideEditingEnabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Minimum Age (months)',
                    helperText: 'Pets younger than this will be declined',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.arrow_downward),
                    suffixText: 'months',
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: ClovaraColors.clover,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _maxAgeYearsController,
                  enabled: _overrideEditingEnabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Maximum Age (years)',
                    helperText: 'Pets older than this will be declined',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.arrow_upward),
                    suffixText: 'years',
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: ClovaraColors.clover,
                        width: 2,
                      ),
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

  Widget _buildExcludedBreedsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ClovaraColors.kWarmCoral.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.pets, color: Colors.red),
        ),
        title: const Text(
          'Excluded Breeds',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_excludedBreeds.length} breed(s)',
          style: const TextStyle(fontSize: 13),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'These breeds will be automatically declined.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                // Add breed input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newBreedController,
                        enabled: _overrideEditingEnabled,
                        decoration: InputDecoration(
                          labelText: 'Add Breed',
                          hintText: 'e.g., Pit Bull Terrier',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.add),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: ClovaraColors.clover,
                              width: 2,
                            ),
                          ),
                        ),
                        onSubmitted: _overrideEditingEnabled
                            ? (_) => _addBreed()
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _overrideEditingEnabled ? _addBreed : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ClovaraColors.clover,
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Breed chips
                if (_excludedBreeds.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No excluded breeds',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _excludedBreeds.map((breed) {
                      return Chip(
                        label: Text(breed),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: _overrideEditingEnabled
                            ? () => _removeBreed(breed)
                            : null,
                        backgroundColor: Colors.red.shade50,
                        deleteIconColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade200),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalConditionsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.medical_services, color: Colors.purple),
        ),
        title: const Text(
          'Critical Conditions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_criticalConditions.length} condition(s)',
          style: const TextStyle(fontSize: 13),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pets with these pre-existing conditions will be declined.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                // Add condition input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newConditionController,
                        enabled: _overrideEditingEnabled,
                        decoration: InputDecoration(
                          labelText: 'Add Condition',
                          hintText: 'e.g., terminal cancer',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.add),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: ClovaraColors.clover,
                              width: 2,
                            ),
                          ),
                        ),
                        onSubmitted: _overrideEditingEnabled
                            ? (_) => _addCondition()
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _overrideEditingEnabled ? _addCondition : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ClovaraColors.clover,
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Condition chips
                if (_criticalConditions.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No critical conditions',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _criticalConditions.map((condition) {
                      return Chip(
                        label: Text(condition),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: _overrideEditingEnabled
                            ? () => _removeCondition(condition)
                            : null,
                        backgroundColor: Colors.purple.shade50,
                        deleteIconColor: Colors.purple,
                        side: BorderSide(color: Colors.purple.shade200),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_isSaving || !_overrideEditingEnabled) ? null : _saveRules,
        icon: const Icon(Icons.save, size: 24),
        label: const Text(
          'Save Changes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: ClovaraColors.forest,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      }
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _PricingVersionTile extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final String? activeId;
  final VoidCallback onActivate;
  final VoidCallback onEdit;

  const _PricingVersionTile({
    required this.id,
    required this.data,
    required this.activeId,
    required this.onActivate,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final config = (data['config'] is Map)
        ? (data['config'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final version = (config['version'] ?? '').toString();
    final effective = (config['effectiveDateIso'] ?? '').toString();
    final baseRiskRate = config['baseRiskRate'];
    final status = (data['status'] ?? 'draft').toString();
    final isActive = activeId != null && activeId == id;

    Color statusColor() {
      if (isActive) return ClovaraColors.forest;
      if (status == 'published') return Colors.blueGrey.shade700;
      if (status == 'retired') return Colors.grey.shade600;
      return Colors.orange.shade800;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            AdminStatusChip(
              label: isActive ? 'ACTIVE' : status.toUpperCase(),
              color: statusColor(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      if (version.isNotEmpty)
                        Text(
                          'version: $version',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (effective.isNotEmpty)
                        Text(
                          'effective: $effective',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (baseRiskRate != null)
                        Text(
                          'baseRiskRate: $baseRiskRate',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: isActive ? null : onActivate,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Activate'),
            ),
          ],
        ),
      ),
    );
  }
}
