import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/quote_flow_screen.dart';
import '../theme/petuwrite_theme.dart';
import '../screens/conversational_quote_flow.dart';

/// Customer home screen - main navigation hub for customers
/// 
/// Shows different features based on whether user is premium or regular
class CustomerHomeScreen extends StatelessWidget {
  final bool isPremium;

  const CustomerHomeScreen({
    super.key,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: PetUwriteColors.kPrimaryNavy,
      appBar: AppBar(
        backgroundColor: PetUwriteColors.kPrimaryNavy,
        elevation: 0,
        title: Text(
          'PetUwrite',
          style: PetUwriteTypography.h3.copyWith(color: Colors.white),
        ),
        actions: [
          if (isPremium)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber[400]!, Colors.amber[700]!],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'PREMIUM',
                      style: PetUwriteTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () => _showProfileDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('pets')
            .snapshots(),
        builder: (context, snapshot) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    gradient: PetUwriteColors.brandGradient,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.pets,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back!',
                                  style: PetUwriteTypography.h2.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.email ?? 'Customer',
                                  style: PetUwriteTypography.body.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Actions
                      Text(
                        'Quick Actions',
                        style: PetUwriteTypography.h3.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Cards
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          _ActionCard(
                            icon: Icons.add_circle_outline,
                            title: 'Get Quote',
                            subtitle: 'New insurance quote',
                            color: PetUwriteColors.kSecondaryTeal,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ConversationalQuoteFlow(),
                                ),
                              );
                            },
                          ),
                          _ActionCard(
                            icon: Icons.pets,
                            title: 'My Pets',
                            subtitle: '${snapshot.data?.docs.length ?? 0} pets',
                            color: PetUwriteColors.kSuccessMint,
                            onTap: () {
                              _showPetsDialog(context, snapshot.data?.docs ?? []);
                            },
                          ),
                          _ActionCard(
                            icon: Icons.description_outlined,
                            title: 'My Policies',
                            subtitle: 'View coverage',
                            color: PetUwriteColors.kAccentSky,
                            onTap: () {
                              _showPoliciesScreen(context);
                            },
                          ),
                          _ActionCard(
                            icon: Icons.medical_services_outlined,
                            title: 'Claims',
                            subtitle: 'File a claim',
                            color: PetUwriteColors.kWarmCoral,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Claims feature coming soon!'),
                                  backgroundColor: PetUwriteColors.kSecondaryTeal,
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Premium Features (if premium user)
                      if (isPremium) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.amber[400]!, Colors.amber[700]!],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.white, size: 32),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Premium Member',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Enjoy exclusive benefits',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Info Section
                      Text(
                        'Need Help?',
                        style: PetUwriteTypography.h3.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          gradient: PetUwriteColors.brandGradientSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.help_outline, color: PetUwriteColors.kSecondaryTeal),
                          title: Text('FAQs', style: PetUwriteTypography.h4.copyWith(
                            color: PetUwriteColors.kPrimaryNavy,
                          )),
                          subtitle: Text('Common questions answered', style: PetUwriteTypography.bodySmall.copyWith(
                            color: PetUwriteColors.kPrimaryNavy.withOpacity(0.7),
                          )),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: PetUwriteColors.kSecondaryTeal),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Help center coming soon!'),
                                backgroundColor: PetUwriteColors.kSecondaryTeal,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: PetUwriteColors.brandGradientSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.support_agent, color: PetUwriteColors.kSecondaryTeal),
                          title: Text('Contact Support', style: PetUwriteTypography.h4.copyWith(
                            color: PetUwriteColors.kPrimaryNavy,
                          )),
                          subtitle: Text('We\'re here to help', style: PetUwriteTypography.bodySmall.copyWith(
                            color: PetUwriteColors.kPrimaryNavy.withOpacity(0.7),
                          )),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: PetUwriteColors.kSecondaryTeal),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Support chat coming soon!'),
                                backgroundColor: PetUwriteColors.kSecondaryTeal,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              subtitle: Text(user?.email ?? 'Not available'),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.badge),
              title: const Text('Account Type'),
              subtitle: Text(isPremium ? 'Premium' : 'Regular'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showPetsDialog(BuildContext context, List<QueryDocumentSnapshot> pets) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Pets'),
        content: SizedBox(
          width: double.maxFinite,
          child: pets.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No pets added yet.'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: pets.length,
                  itemBuilder: (context, index) {
                    final pet = pets[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.pets),
                      title: Text(pet['name'] ?? 'Unknown'),
                      subtitle: Text('${pet['species'] ?? 'Pet'} • ${pet['breed'] ?? 'Mixed'}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPoliciesScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const _PoliciesListScreen(),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: PetUwriteColors.brandGradientSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: PetUwriteTypography.h4.copyWith(
                    color: PetUwriteColors.kPrimaryNavy,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: PetUwriteTypography.bodySmall.copyWith(
                    color: PetUwriteColors.kPrimaryNavy.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PoliciesListScreen extends StatelessWidget {
  const _PoliciesListScreen();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Policies'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('policies')
            .where('userId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No policies yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Get a quote to start your first policy'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QuoteFlowScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Get Quote'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final policy = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final status = policy['status'] ?? 'unknown';
              final policyNumber = policy['policyNumber'] ?? 'N/A';
              final premium = policy['premiumAmount'] ?? 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(status),
                    child: const Icon(Icons.description, color: Colors.white),
                  ),
                  title: Text('Policy #$policyNumber'),
                  subtitle: Text(
                    'Status: ${_formatStatus(status)}\n\$${premium.toStringAsFixed(2)}/month',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Show policy details
                    _showPolicyDetails(context, policy);
                  },
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  void _showPolicyDetails(BuildContext context, Map<String, dynamic> policy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Policy #${policy['policyNumber']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Status', _formatStatus(policy['status'] ?? 'unknown')),
              _DetailRow('Premium', '\$${(policy['premiumAmount'] ?? 0.0).toStringAsFixed(2)}/month'),
              _DetailRow('Start Date', policy['startDate']?.toDate()?.toString() ?? 'N/A'),
              _DetailRow('End Date', policy['endDate']?.toDate()?.toString() ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
