import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  static String? _userPassword;
  static String? get userPassword => _userPassword;

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

  /// Set premium with expiry date (for promo codes)
  Future<void> setPremiumWithExpiry(int days) async {
    final user = _auth.currentUser;
    final expiryDate = DateTime.now().add(Duration(days: days));
    
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'premium_status': true,
        'premium_expiry': expiryDate.toIso8601String(),
      }, SetOptions(merge: true));
    } else {
      // Save for guest
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('guest_premium_status', true);
      await prefs.setString('guest_premium_expiry', expiryDate.toIso8601String());
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
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(googleProvider);
        await _createUserRecordIfNew(userCredential.user);
        
        // Sync player ID asynchronously
        NotificationService().syncPlayerIdToFirestore();
        
        return userCredential;
      }

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

  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _userPassword = password; // Cache password in-memory for encryption key
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

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _userPassword = password; // Cache password in-memory for encryption key
      
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

  /// Helper to generate a unique referral code
  String _generateReferralCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Credits referral rewards to the inviter
  Future<void> _creditReferralReward(String referralCode, String referredUid) async {
    try {
      final cleanCode = referralCode.trim().toUpperCase();
      final querySnapshot = await _firestore
          .collection('users')
          .where('referral_code', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print("Referral credit: Inviter with code $cleanCode not found.");
        return;
      }

      final inviterDoc = querySnapshot.docs.first;
      final inviterData = inviterDoc.data();
      final inviterUid = inviterDoc.id;

      // Prevent self-referral
      if (inviterUid == referredUid) {
        print("Referral credit: Prevented self-referral.");
        return;
      }

      final referredUsers = List<String>.from(inviterData['referred_users'] ?? []);
      
      if (referredUsers.contains(referredUid)) {
        print("Referral credit: User $referredUid already referred by $inviterUid.");
        return;
      }

      referredUsers.add(referredUid);
      final newReferralCount = referredUsers.length;

      // Calculate premium expiry
      DateTime baseDate = DateTime.now();
      final currentExpiryStr = inviterData['premium_expiry'] as String?;
      if (currentExpiryStr != null) {
        final currentExpiry = DateTime.tryParse(currentExpiryStr);
        if (currentExpiry != null && currentExpiry.isAfter(DateTime.now())) {
          baseDate = currentExpiry;
        }
      }

      // Reward: 3rd referral = +30 days, others = +7 days
      final daysToAdd = (newReferralCount == 3) ? 30 : 7;
      final newExpiry = baseDate.add(Duration(days: daysToAdd));

      await _firestore.collection('users').doc(inviterUid).set({
        'referred_users': referredUsers,
        'referral_count': newReferralCount,
        'premium_status': true,
        'premium_expiry': newExpiry.toIso8601String(),
      }, SetOptions(merge: true));

      print("Referral credit: Success! Inviter $inviterUid rewarded with $daysToAdd days premium. New count: $newReferralCount.");
    } catch (e) {
      print("Error crediting referral reward: $e");
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

        final isGoogle = user.providerData.any((info) => info.providerId == 'google.com');
        final isAnonymous = user.isAnonymous;
        final isGoogleOrAnonymous = isAnonymous || isGoogle;

        final myReferralCode = _generateReferralCode();

        // Read cached pending referral code
        final prefs = await SharedPreferences.getInstance();
        final pendingRef = prefs.getString('pending_referral_code');

        String? referredBy;
        bool referralCredited = false;

        // Only credit immediately if it's a Google sign in (which is verified right away)
        // Anonymous accounts are NOT eligible for referral credits or being referred.
        if (pendingRef != null && pendingRef.isNotEmpty && !isAnonymous) {
          referredBy = pendingRef;
          if (isGoogle) {
            referralCredited = true;
          }
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
          'email_otp_verified': isGoogleOrAnonymous,
          'emotional_preferences': {},
          'referral_code': myReferralCode,
          'referral_count': 0,
          'referred_users': [],
          'referred_by': referredBy,
          'referral_credited': referralCredited,
        });

        // Credit immediately for Google
        if (isGoogle && referredBy != null) {
          await _creditReferralReward(referredBy, user.uid);
          await prefs.remove('pending_referral_code');
        }
      }
    } catch (e) {
      print("Error creating user Firestore record: $e");
    }
  }

  // ─── OTP Email Verification ───────────────────────────────────────────────

  /// Generates a 6-digit OTP, stores it in Firestore with 10-min expiry,
  /// and sends it to the user's email via EmailJS.
  Future<void> generateAndSendOtp(String email) async {
    final code = (100000 + Random.secure().nextInt(900000)).toString();
    final expiry = DateTime.now().add(const Duration(minutes: 10));

    // Store OTP in Firestore keyed by email (lowercase)
    await _firestore
        .collection('email_otps')
        .doc(email.toLowerCase().trim())
        .set({
      'code': code,
      'expiry': expiry.toIso8601String(),
      'created_at': FieldValue.serverTimestamp(),
    });

    // Send email via EmailJS REST API
    // Replace these with your actual EmailJS credentials:
    const serviceId = 'YOUR_EMAILJS_SERVICE_ID';
    const templateId = 'YOUR_EMAILJS_TEMPLATE_ID';
    const userId = 'YOUR_EMAILJS_PUBLIC_KEY';

    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': userId,
        'template_params': {
          'to_email': email,
          'otp_code': code,
          'app_name': 'Chatrix AI',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send verification email. Please try again.');
    }
  }

  /// Verifies a user-entered OTP against the Firestore record.
  /// Returns true if valid, throws an [Exception] with reason if not.
  Future<bool> verifyOtp(String email, String enteredCode) async {
    final doc = await _firestore
        .collection('email_otps')
        .doc(email.toLowerCase().trim())
        .get();

    if (!doc.exists) {
      throw Exception('No verification code found. Please request a new one.');
    }

    final data = doc.data()!;
    final storedCode = data['code'] as String? ?? '';
    final expiryStr = data['expiry'] as String? ?? '';
    final expiry = DateTime.tryParse(expiryStr);

    if (expiry == null || DateTime.now().isAfter(expiry)) {
      throw Exception('Verification code has expired. Please request a new one.');
    }

    if (enteredCode.trim() != storedCode) {
      throw Exception('Incorrect code. Please check your email and try again.');
    }

    // Code is valid — delete it so it cannot be reused
    await _firestore
        .collection('email_otps')
        .doc(email.toLowerCase().trim())
        .delete();

    // Mark the Firebase Auth user as email-verified via a custom claim workaround:
    // We store a verified flag in Firestore on the user's document instead,
    // since we cannot call Admin SDK from client.
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set(
        {'email_otp_verified': true},
        SetOptions(merge: true),
      );

      // Now that they verified, check if they were referred by someone and credit them!
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        final referredBy = userData['referred_by'] as String?;
        final referralCredited = userData['referral_credited'] as bool? ?? false;

        if (referredBy != null && referredBy.isNotEmpty && !referralCredited) {
          await _creditReferralReward(referredBy, user.uid);
          await _firestore.collection('users').doc(user.uid).set(
            {'referral_credited': true},
            SetOptions(merge: true),
          );

          // Clear local cache
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('pending_referral_code');
        }
      }
    }

    return true;
  }

  /// Checks whether the current user has been OTP-verified in Firestore.
  Future<bool> isOtpVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    if (user.isAnonymous) return true;

    // Google Sign-In users are automatically verified
    final isGoogle = user.providerData.any((info) => info.providerId == 'google.com');
    if (isGoogle) return true;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['email_otp_verified'] ?? false;
      }
    } catch (e) {
      print("Error checking OTP status: $e");
    }
    return false;
  }

  // ────────────────────────────────────────────────────────────────────────────

  /// Send a password-reset email to the given address
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _parseAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out all active auth sessions
  Future<void> signOut() async {
    _userPassword = null; // Clear cached password
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
