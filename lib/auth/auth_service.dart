import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '47600970379-rjs51bu94e287q0qggrrp3tr2sr0paol.apps.googleusercontent.com',
  );

  String? get currentUserId => _auth.currentUser?.uid;
  User? get currentUser => _auth.currentUser;

  /// Check if the current user has premium status in Firestore
  Future<bool> isPremium() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return doc.data()?['premium_status'] ?? false;
        }
      } catch (e) {
        print("Error checking premium status: $e");
      }
    }
    // Fallback for guests
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('guest_premium_status') ?? false;
  }

  /// Update premium status
  Future<void> setPremium(bool val) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({'premium_status': val}, SetOptions(merge: true));
    } else {
      // Save for guest
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('guest_premium_status', val);
    }
  }

  /// Check if the current user has used their promotional call
  Future<bool> hasUsedPromoCall() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return doc.data()?['has_used_promo_call'] ?? false;
        }
      } catch (e) {
        print("Error checking promo call status: $e");
      }
    }
    // Fallback for guests
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('guest_has_used_promo_call') ?? false;
  }

  /// Mark the promotional call as used
  Future<void> markPromoCallUsed() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'has_used_promo_call': true,
        }, SetOptions(merge: true));
      } catch (e) {
        print("Error saving promo call status to Firestore: $e");
      }
    }
    // Save for guest
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('guest_has_used_promo_call', true);
  }

  /// Sign in with Google with robust ApiException 10 error detection
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("Google Sign In: Canceled by user.");
        return null;
      }

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        throw Exception("Missing authentication tokens from Google.");
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _createUserRecordIfNew(userCredential.user);
      
      // Sync player ID asynchronously
      NotificationService().syncPlayerIdToFirestore();
      
      return userCredential;
    } on PlatformException catch (e) {
      print("Google Sign In PlatformException: ${e.code} - ${e.message}");
      if (e.code == '10' || e.message?.contains('DEVELOPER_ERROR') == true || e.code.contains('10')) {
        throw Exception(
          "Google Sign-In (Developer Error 10):\n"
          "This typically means your SHA-1 fingerprint is missing or mismatched in the Firebase Console.\n"
          "Please verify that the keystore SHA-1 is correctly added to project settings."
        );
      }
      throw Exception("Google Sign-In failed: ${e.message ?? e.code}");
    } catch (e) {
      print("Google Sign In Error: $e");
      rethrow;
    }
  }

  /// Sign up with Email and Password
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _createUserRecordIfNew(userCredential.user);
      
      // Sync player ID asynchronously
      NotificationService().syncPlayerIdToFirestore();
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException Sign Up: ${e.code} - ${e.message}");
      throw _parseAuthException(e);
    } catch (e) {
      print("Email Sign Up Error: $e");
      rethrow;
    }
  }

  /// Sign in with Email and Password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Sync player ID asynchronously for existing user
      NotificationService().syncPlayerIdToFirestore();
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException Sign In: ${e.code} - ${e.message}");
      throw _parseAuthException(e);
    } catch (e) {
      print("Email Sign In Error: $e");
      rethrow;
    }
  }

  /// Guest/Wanderer Anonymous login
  Future<UserCredential?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      await _createUserRecordIfNew(userCredential.user);
      
      // Sync player ID asynchronously
      NotificationService().syncPlayerIdToFirestore();
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException Anonymous Sign In: ${e.code} - ${e.message}");
      throw _parseAuthException(e);
    } catch (e) {
      print("Anonymous Sign In Error: $e");
      rethrow;
    }
  }

  /// Create a sleek and robust record in Firestore for new users
  Future<void> _createUserRecordIfNew(User? user) async {
    if (user == null) return;
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        String defaultName = "Wanderer";
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          defaultName = user.displayName!;
        } else if (user.email != null && user.email!.isNotEmpty) {
          defaultName = user.email!.split('@')[0];
        }

        await docRef.set({
          'uid': user.uid,
          'userId': user.uid,
          'email': user.email,
          'username': defaultName,
          'premium_status': false,
          'created_at': FieldValue.serverTimestamp(),
          'selected_ai': 'default',
          'selected_scene': 'default',
          'daily_messages': 0,
          'theme': 'dark',
          'is_anonymous': user.isAnonymous,
          'emotional_preferences': {}
        });
      }
    } catch (e) {
      print("Error creating user Firestore record: $e");
    }
  }

  /// Sign out all active auth sessions
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print("Google SignOut Error: $e");
    }
    await _auth.signOut();
  }

  /// Helper to convert Firebase Auth error codes to user-friendly messages
  Exception _parseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception("No connected identity found for this email.");
      case 'wrong-password':
        return Exception("Incorrect security cipher (password).");
      case 'email-already-in-use':
        return Exception("This identity email is already anchored to another soul.");
      case 'invalid-email':
        return Exception("The email format is invalid.");
      case 'weak-password':
        return Exception("The security cipher is too weak. Try a stronger password.");
      case 'operation-not-allowed':
        return Exception("This connection method is currently disabled.");
      case 'user-disabled':
        return Exception("This identity has been deactivated by administrators.");
      default:
        return Exception(e.message ?? "An unexpected connection error occurred.");
    }
  }
}
