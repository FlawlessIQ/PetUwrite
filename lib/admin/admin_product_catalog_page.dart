import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/product_catalog.dart';
import '../theme/clovara_theme.dart';

/// Admin: enable/disable products (tiers) and riders (add-ons).
/// Writes to Firestore: `admin_settings/product_catalog`.
class AdminProductCatalogPage extends StatefulWidget {
  const AdminProductCatalogPage({super.key});

  @override
  State<AdminProductCatalogPage> createState() => _AdminProductCatalogPageState();
}

class _AdminProductCatalogPageState extends State<AdminProductCatalogPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasAccess = false;
  bool _enabled = true;

  final Map<String, bool> _enabledTiers = {
    'basic': true,
    'standard': true,
    'plus': true,
    'premium': true,
    'unlimited': true,
  };

  late final Map<String, bool> _enabledAddOns = {
    for (final a in AddOnType.values) a.name: true,
  };

  DateTime? _lastUpdated;
  String? _updatedBy;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final role = userDoc.data()?['userRole'] as int? ?? 0;
      if (role != 2) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
        return;
      }

      setState(() => _hasAccess = true);
      await _load();
    } catch (e) {
      setState(() {
        _hasAccess = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _load() async {
    try {
      final doc = await _firestore.collection('admin_settings').doc('product_catalog').get();

      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        final enabled = data['enabled'];
        final tiers = data['enabledTiers'];
        final addOns = data['enabledAddOns'];

        setState(() {
          _enabled = enabled is bool ? enabled : true;

          if (tiers is Map) {
            for (final k in _enabledTiers.keys) {
              final v = tiers[k];
              _enabledTiers[k] = v is bool ? v : true;
            }
          }

          if (addOns is Map) {
            for (final k in _enabledAddOns.keys) {
              final v = addOns[k];
              _enabledAddOns[k] = v is bool ? v : true;
            }
          }

          final lastUpdated = data['lastUpdated'];
          if (lastUpdated is Timestamp) {
            _lastUpdated = lastUpdated.toDate();
          }
          _updatedBy = data['updatedBy'] as String?;

          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading product catalog config: $e'),
            backgroundColor: ClovaraColors.kWarmCoral,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;

      final payload = {
        'enabled': _enabled,
        'enabledTiers': _enabledTiers,
        'enabledAddOns': _enabledAddOns,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': user?.email ?? 'Unknown',
      };

      await _firestore
          .collection('admin_settings')
          .doc('product_catalog')
          .set(payload, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Product catalog updated'),
            backgroundColor: ClovaraColors.kSuccessMint,
          ),
        );
      }

      setState(() {
        _isSaving = false;
        _lastUpdated = DateTime.now();
        _updatedBy = user?.email;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product catalog config: $e'),
            backgroundColor: ClovaraColors.kWarmCoral,
          ),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: ClovaraColors.forest,
        appBar: AppBar(
          backgroundColor: ClovaraColors.forest,
          foregroundColor: Colors.white,
          title: const Text('Products & Riders'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        backgroundColor: ClovaraColors.forest,
        appBar: AppBar(
          backgroundColor: ClovaraColors.forest,
          foregroundColor: Colors.white,
          title: const Text('Products & Riders'),
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 520),
            child: const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('You do not have access to this page.'),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: ClovaraColors.forest,
        foregroundColor: Colors.white,
        title: const Text('Products & Riders'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune),
                      const SizedBox(width: 8),
                      const Text(
                        'Catalog Switches',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Switch(
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                        activeColor: ClovaraColors.clover,
                      ),
                    ],
                  ),
                  if (_lastUpdated != null || _updatedBy != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: ${_lastUpdated?.toLocal().toString().split(".").first ?? "—"}  •  ${_updatedBy ?? ""}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Disabling the catalog hides products/riders in the quote UI (unauth included via callable).',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildTiersCard(),
          const SizedBox(height: 12),
          _buildAddOnsCard(),
        ],
      ),
    );
  }

  Widget _buildTiersCard() {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.layers),
        title: const Text('Products (Tiers)', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Enable/disable Basic, Standard, Plus, Premium, Unlimited'),
        children: [
          for (final entry in _enabledTiers.entries)
            SwitchListTile(
              title: Text(entry.key[0].toUpperCase() + entry.key.substring(1)),
              value: entry.value,
              activeColor: ClovaraColors.clover,
              onChanged: (v) => setState(() => _enabledTiers[entry.key] = v),
            ),
        ],
      ),
    );
  }

  Widget _buildAddOnsCard() {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.add_box_outlined),
        title: const Text('Riders (Add-ons)', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Enable/disable optional riders shown in plan customization'),
        children: [
          for (final addOn in AddOn.all)
            SwitchListTile(
              title: Text(addOn.name),
              subtitle: Text(addOn.description),
              value: _enabledAddOns[addOn.type.name] ?? true,
              activeColor: ClovaraColors.clover,
              onChanged: (v) => setState(() => _enabledAddOns[addOn.type.name] = v),
            ),
        ],
      ),
    );
  }
}
