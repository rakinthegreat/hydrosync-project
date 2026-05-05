import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_settings.dart';
import '../models/water_intake.dart';

class SyncService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize();
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) return null;

      final authResult = await googleUser.authorizationClient.authorizeScopes([
        'email',
        'profile',
        'openid',
      ]);
      
      final String? accessToken = authResult.accessToken;
      final auth = await googleUser.authentication;
      final String? idToken = auth.idToken;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Google Sign-In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── SETTINGS ─────────────────────────────────────────────────────────────

  Future<void> backupSettings(UserSettings settings) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set(
          {'settings': settings.toMap(), 'lastSync': FieldValue.serverTimestamp()},
          SetOptions(merge: true)
        );
        print('[SYNC] Settings backed up to Cloud');
      } catch (e) {
        print('[SYNC] Settings backup failed: $e');
      }
    }
  }

  Future<UserSettings?> restoreSettings() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('settings')) {
          print('[SYNC] Settings restored from Cloud');
          return UserSettings.fromMap(doc.data()!['settings']);
        }
      } catch (e) {
        print('[SYNC] Settings restore failed: $e');
      }
    }
    return null;
  }

  // ── INTAKES ──────────────────────────────────────────────────────────────

  /// Backs up today's full intake list. Call at most once per day.
  Future<void> backupIntakes(List<WaterIntake> intakes) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final encoded = intakes.map((i) => i.toMap()).toList();
        await _firestore.collection('users').doc(user.uid).set(
          {'intakes': encoded, 'intakesDate': today},
          SetOptions(merge: true)
        );
        print('[SYNC] Intakes backed up to Cloud (date: $today)');
      } catch (e) {
        print('[SYNC] Intakes backup failed: $e');
      }
    }
  }

  Future<List<WaterIntake>?> restoreIntakes() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('intakes')) {
          final List<dynamic> raw = doc.data()!['intakes'];
          final intakes = raw.map((i) => WaterIntake.fromMap(Map<String, dynamic>.from(i))).toList();
          print('[SYNC] Intakes restored from Cloud (${intakes.length} entries)');
          return intakes;
        }
      } catch (e) {
        print('[SYNC] Intakes restore failed: $e');
      }
    }
    return null;
  }

  // ── COMBINED ─────────────────────────────────────────────────────────────

  /// Restore both settings and intakes from cloud. Returns null if not signed in.
  Future<({UserSettings? settings, List<WaterIntake>? intakes})?> restoreAll() async {
    if (!isSignedIn) return null;
    final settings = await restoreSettings();
    final intakes = await restoreIntakes();
    return (settings: settings, intakes: intakes);
  }
}
