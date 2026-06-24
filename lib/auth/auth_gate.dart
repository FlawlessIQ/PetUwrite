import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'customer_home_screen.dart';
import '../screens/admin_console_screen.dart';
import '../services/app_analytics_service.dart';
import '../utils/marketing_site_redirect.dart';

const _adminEmails = {'con.lawless@gmail.com'};

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
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Treat anonymous sessions as unauthenticated for routing purposes.
        // We use anonymous auth to secure Storage/Firestore writes during
        // underwriting, but we don't want to force a full account/profile.
        // When unauthenticated, keep users inside the authenticated app mount
        // and show sign-in. Marketing links handle the public site separately.
        if (!snapshot.hasData || snapshot.data?.isAnonymous == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.go('/sign-in');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is logged in - check their role
        return RoleBasedRouter(user: snapshot.data!);
      },
    );
  }
}

/// Fetches user role from Firestore and routes to appropriate screen
class RoleBasedRouter extends StatefulWidget {
  final User user;

  const RoleBasedRouter({super.key, required this.user});

  @override
  State<RoleBasedRouter> createState() => _RoleBasedRouterState();
}

class _RoleBasedRouterState extends State<RoleBasedRouter> {
  bool _trackedRoute = false;

  bool get _isKnownAdminEmail {
    final email = widget.user.email?.trim().toLowerCase();
    return email != null && _adminEmails.contains(email);
  }

  void _trackRouteResolved(int userRole, String destination) {
    if (_trackedRoute) return;
    _trackedRoute = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppAnalyticsService.instance.track(
        'auth_route_resolved',
        properties: {'userRole': userRole, 'destination': destination},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
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
          if (_isKnownAdminEmail) {
            _trackRouteResolved(3, 'admin_console_email_fallback');
            return const AdminConsoleScreen();
          }

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
                      if (context.mounted &&
                          !redirectToMarketingSite(path: '/')) {
                        context.go('/sign-in');
                      }
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
          if (_isKnownAdminEmail) {
            _trackRouteResolved(3, 'admin_console_email_fallback');
            return const AdminConsoleScreen();
          }

          unawaited(
            FirebaseFirestore.instance
                .collection('users')
                .doc(widget.user.uid)
                .set({
                  'uid': widget.user.uid,
                  'email': widget.user.email,
                  'userRole': 0,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true))
                .catchError((_) {}),
          );
          _trackRouteResolved(0, 'customer_home_profile_bootstrap');
          return const CustomerHomeScreen(isPremium: false);
        }

        // Get user role (default to 0 if not set)
        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final userRole = userData?['userRole'] ?? 0;

        // Route based on role
        if (_isKnownAdminEmail) {
          _trackRouteResolved(3, 'admin_console_email_fallback');
          return const AdminConsoleScreen();
        }

        // Route based on role
        switch (userRole) {
          case 2: // Underwriter
          case 3: // Super Admin
            _trackRouteResolved(userRole, 'admin_console');
            return const AdminConsoleScreen();

          case 1: // Premium Customer
            // Could route to premium features screen
            _trackRouteResolved(userRole, 'customer_home_premium');
            return const CustomerHomeScreen(isPremium: true);

          case 0: // Regular Customer
          default:
            _trackRouteResolved(userRole, 'customer_home');
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
              Text(message!, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }
}
