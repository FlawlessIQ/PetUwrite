import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_home_screen.dart';
import '../screens/admin_dashboard.dart';
import '../screens/homepage.dart';

/// AuthGate handles routing users based on authentication status and role
/// 
/// User roles:
/// - 0: Customer (regular user)
/// - 1: Premium Customer
/// - 2: Underwriter (admin dashboard access)
/// - 3: Super Admin
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User not logged in - show homepage (unauthenticated access)
        if (!snapshot.hasData) {
          return const Homepage();
        }

        // User is logged in - check their role
        return RoleBasedRouter(userId: snapshot.data!.uid);
      },
    );
  }
}

/// Fetches user role from Firestore and routes to appropriate screen
class RoleBasedRouter extends StatelessWidget {
  final String userId;

  const RoleBasedRouter({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(),
      builder: (context, userSnapshot) {
        // Show loading while fetching user data
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your profile...'),
                ],
              ),
            ),
          );
        }

        // Handle error fetching user data
        if (userSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading profile: ${userSnapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          );
        }

        // User document doesn't exist
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'User profile not found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please contact support or sign out and try again.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          );
        }

        // Get user role (default to 0 if not set)
        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final userRole = userData?['userRole'] ?? 0;

        // Route based on role
        switch (userRole) {
          case 2: // Underwriter
          case 3: // Super Admin
            return const AdminDashboard();

          case 1: // Premium Customer
            // Could route to premium features screen
            return const CustomerHomeScreen(isPremium: true);

          case 0: // Regular Customer
          default:
            return const CustomerHomeScreen(isPremium: false);
        }
      },
    );
  }
}

/// Helper widget to show loading state with custom message
class LoadingScreen extends StatelessWidget {
  final String? message;

  const LoadingScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
