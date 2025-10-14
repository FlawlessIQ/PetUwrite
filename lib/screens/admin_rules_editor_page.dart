import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final UnderwritingRulesEngine _rulesEngine = UnderwritingRulesEngine();
  
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
  double _maxRiskScoreSlider = 85.0;
  List<String> _excludedBreeds = [];
  List<String> _criticalConditions = [];
  DateTime? _lastUpdated;
  String? _lastUpdatedBy;
  
  // Theme colors
  static const Color _navyBlue = Color(0xFF0A2647);
  static const Color _teal = Color(0xFF00C2CB);

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

      // Check user role in users collection
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final userRole = userData?['userRole'] ?? 0;

      if (userRole != 2) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
        return;
      }

      // User has access, load rules
      setState(() => _hasAccess = true);
      await _loadRules();
    } catch (e) {
      print('Error checking access: $e');
      setState(() {
        _hasAccess = false;
        _isLoading = false;
      });
    }
  }

  /// Load rules from Firestore
  Future<void> _loadRules() async {
    try {
      final rules = await _rulesEngine.getRules();
      
      setState(() {
        _enabled = rules['enabled'] as bool? ?? true;
        _maxRiskScoreSlider = (rules['maxRiskScore'] as int? ?? 85).toDouble();
        _maxRiskScoreController.text = _maxRiskScoreSlider.toInt().toString();
        _minAgeMonthsController.text = (rules['minAgeMonths'] as int? ?? 2).toString();
        _maxAgeYearsController.text = (rules['maxAgeYears'] as int? ?? 14).toString();
        _excludedBreeds = List<String>.from(rules['excludedBreeds'] as List? ?? []);
        _criticalConditions = List<String>.from(rules['criticalConditions'] as List? ?? []);
        
        // Parse timestamp
        if (rules['lastUpdated'] != null) {
          if (rules['lastUpdated'] is Timestamp) {
            _lastUpdated = (rules['lastUpdated'] as Timestamp).toDate();
          } else if (rules['lastUpdated'] is String) {
            _lastUpdated = DateTime.tryParse(rules['lastUpdated'] as String);
          }
        }
        _lastUpdatedBy = rules['updatedBy'] as String?;
        
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
      final updateData = {
        'enabled': _enabled,
        'maxRiskScore': maxRiskScore,
        'minAgeMonths': minAgeMonths,
        'maxAgeYears': maxAgeYears,
        'excludedBreeds': _excludedBreeds,
        'criticalConditions': _criticalConditions,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': user?.email ?? 'Unknown',
      };

      await _firestore
          .collection('admin_settings')
          .doc('underwriting_rules')
          .set(updateData);

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
      return Scaffold(
        appBar: AppBar(
          title: const Text('Underwriting Rules'),
          backgroundColor: _navyBlue,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Underwriting Rules'),
          backgroundColor: _navyBlue,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _navyBlue,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You do not have permission to access this page.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Required role: Admin (userRole = 2)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Underwriting Rules Editor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _navyBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() => _isLoading = true);
              await _loadRules();
            },
            tooltip: 'Reload Rules',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Last Updated Info
                _buildLastUpdatedCard(),
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
                const SizedBox(height: 24),

                // Save Button
                _buildSaveButton(),
                const SizedBox(height: 80), // Extra space for FAB
              ],
            ),
          ),

          // Loading overlay
          if (_isSaving)
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
                        Text(
                          'Saving changes...',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLastUpdatedCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _teal.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.update, color: _teal, size: 28),
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
                      color: _navyBlue,
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

  Widget _buildEnableSwitch() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        value: _enabled,
        onChanged: (value) => setState(() => _enabled = value),
        title: Text(
          'Rules Engine Enabled',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _navyBlue,
          ),
        ),
        subtitle: Text(
          _enabled
              ? 'Rules are actively enforced on all quotes'
              : 'Rules are disabled - all quotes will be approved',
          style: TextStyle(
            fontSize: 13,
            color: _enabled ? Colors.green[700] : Colors.red[700],
          ),
        ),
        activeColor: _teal,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _enabled ? _teal.withOpacity(0.1) : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _enabled ? Icons.check_circle : Icons.block,
            color: _enabled ? _teal : Colors.grey[600],
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
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.analytics, color: Colors.orange),
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
                        activeColor: _teal,
                        onChanged: (value) {
                          setState(() {
                            _maxRiskScoreSlider = value;
                            _maxRiskScoreController.text = value.toInt().toString();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _maxRiskScoreController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          suffixText: '/100',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (value) {
                          final score = int.tryParse(value);
                          if (score != null && score >= 50 && score <= 100) {
                            setState(() => _maxRiskScoreSlider = score.toDouble());
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('50 (Low)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text('100 (High)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.cake, color: Colors.blue),
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
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Minimum Age (months)',
                    helperText: 'Pets younger than this will be declined',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.arrow_downward),
                    suffixText: 'months',
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _teal, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _maxAgeYearsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Maximum Age (years)',
                    helperText: 'Pets older than this will be declined',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.arrow_upward),
                    suffixText: 'years',
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _teal, width: 2),
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
            color: Colors.red.withOpacity(0.1),
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
                        decoration: InputDecoration(
                          labelText: 'Add Breed',
                          hintText: 'e.g., Pit Bull Terrier',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.add),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: _teal, width: 2),
                          ),
                        ),
                        onSubmitted: (_) => _addBreed(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addBreed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
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
                        onDeleted: () => _removeBreed(breed),
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
                        decoration: InputDecoration(
                          labelText: 'Add Condition',
                          hintText: 'e.g., terminal cancer',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.add),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: _teal, width: 2),
                          ),
                        ),
                        onSubmitted: (_) => _addCondition(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addCondition,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
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
                        onDeleted: () => _removeCondition(condition),
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
        onPressed: _isSaving ? null : _saveRules,
        icon: const Icon(Icons.save, size: 24),
        label: const Text(
          'Save Changes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _navyBlue,
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
