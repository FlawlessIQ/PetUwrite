import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const clovaraAdminEmails = {'con.lawless@gmail.com'};

bool isKnownAdminEmail(String? email) {
  final normalized = email?.trim().toLowerCase();
  return normalized != null && clovaraAdminEmails.contains(normalized);
}

bool _isAdminRole(dynamic role) {
  return role == 2 || role == 3 || role == '2' || role == '3';
}

Future<bool> isAdminUser({
  required User? user,
  FirebaseFirestore? firestore,
}) async {
  if (user == null) return false;
  if (isKnownAdminEmail(user.email)) return true;

  try {
    final token = await user.getIdTokenResult(true);
    if (token.claims?['admin'] == true) return true;
  } catch (_) {
    // Fall through to the Firestore role check.
  }

  try {
    final db = firestore ?? FirebaseFirestore.instance;
    final doc = await db.collection('users').doc(user.uid).get();
    return _isAdminRole(doc.data()?['userRole']);
  } catch (_) {
    return false;
  }
}

Future<void> ensureAdminProfile({
  required User user,
  FirebaseFirestore? firestore,
}) async {
  if (!isKnownAdminEmail(user.email)) return;

  final db = firestore ?? FirebaseFirestore.instance;
  await db.collection('users').doc(user.uid).set({
    'uid': user.uid,
    'email': user.email,
    'userRole': 3,
    'role': 'admin',
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
