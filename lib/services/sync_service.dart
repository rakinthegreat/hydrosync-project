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

  // ── INTAKES (SCALABLE ARCHITECTURE) ──────────────────────────────────────

  /// Backs up the current day's intakes to a dedicated daily document.
  Future<void> backupIntakes(List<WaterIntake> intakes) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final now = DateTime.now();
        final dateKey = now.toIso8601String().substring(0, 10);
        
        // Filter only today's intakes for the daily document
        final todayEntries = intakes.where((i) => 
          i.timestamp.year == now.year && 
          i.timestamp.month == now.month && 
          i.timestamp.day == now.day
        ).map((i) => i.toMap()).toList();

        // 1. Update the daily high-performance document
        await _firestore.collection('users').doc(user.uid)
            .collection('history').doc(dateKey).set({
          'entries': todayEntries,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // 2. Clear the legacy 'intakes' field from the main doc to keep it light
        await _firestore.collection('users').doc(user.uid).update({
          'intakes': FieldValue.delete(),
        });

        print('[SYNC] Scalable backup complete for $dateKey');
      } catch (e) {
        print('[SYNC] Scalable backup failed: $e');
      }
    }
  }

  /// Restores the entire history by querying the history sub-collection.
  /// Includes a migration bridge for legacy single-document data.
  Future<List<WaterIntake>?> restoreIntakes() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        List<WaterIntake> allIntakes = [];

        // 1. Migration Bridge: Check for legacy data in main document
        final mainDoc = await _firestore.collection('users').doc(user.uid).get();
        if (mainDoc.exists && mainDoc.data()!.containsKey('intakes')) {
          print('[SYNC] Legacy data detected. Migrating to archive...');
          final List<dynamic> legacyRaw = mainDoc.data()!['intakes'];
          allIntakes.addAll(legacyRaw.map((i) => 
            WaterIntake.fromMap(Map<String, dynamic>.from(i))));
          
          // Note: Migration to sub-collection happens on the next backupIntakes call
        }

        // 2. Fetch all daily documents from the scalable archive
        final historySnapshot = await _firestore.collection('users').doc(user.uid)
            .collection('history').orderBy('lastUpdated', descending: true).get();

        for (var doc in historySnapshot.docs) {
          final List<dynamic> entriesRaw = doc.data()['entries'] ?? [];
          final dailyEntries = entriesRaw.map((i) => 
            WaterIntake.fromMap(Map<String, dynamic>.from(i))).toList();
          
          // Prevent duplicates if migration data overlaps with archive
          for (var entry in dailyEntries) {
            if (!allIntakes.any((existing) => 
                existing.timestamp.isAtSameMomentAs(entry.timestamp))) {
              allIntakes.add(entry);
            }
          }
        }

        // Sort by time
        allIntakes.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        print('[SYNC] Scalable restore complete (${allIntakes.length} entries)');
        return allIntakes;
      } catch (e) {
        print('[SYNC] Scalable restore failed: $e');
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
