import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../firebase_options.dart';
import '../../models/app_user.dart';
import '../../services/app_preferences.dart';

class AuthRepository {
  AuthRepository() : _prefsFuture = AppPreferences.instance.prefs {
    _initDefaultUser();
  }

  final Future<SharedPreferences> _prefsFuture;
  final StreamController<AppUser?> _authStateController =
      StreamController<AppUser?>.broadcast();

  static const String _currentUserKey = 'local_auth_current_user';
  static const String _usersKey = 'local_auth_registered_users';

  AppUser? _cachedUser;

  /// Try to initialize Firebase on-demand. Returns true when Firebase is available.
  Future<bool> _ensureFirebaseInitialized() async {
    try {
      if (Firebase.apps.isNotEmpty) return true;
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return Firebase.apps.isNotEmpty;
    } catch (error) {
      // Not available or misconfigured; log and continue with local auth.
      try {
        debugPrint('Firebase initialization failed: $error');
      } catch (_) {}
      return false;
    }
  }

  bool get _firebaseEnabled {
    try {
      // Firebase.apps may throw if Firebase is not configured; handle gracefully.
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<AppUser?> authStateChanges() {
    final localUserFuture = _loadPersistedUser();
    localUserFuture.then(_authStateController.add);

    // Attempt to initialize Firebase in background and subscribe to auth changes if available.
    _ensureFirebaseInitialized().then((available) {
      if (!available) return;
      FirebaseAuth.instance.authStateChanges().listen((firebaseUser) async {
        if (firebaseUser == null) {
          final localUser = await localUserFuture;
          if (localUser != null) {
            _cachedUser = localUser;
            _authStateController.add(localUser);
            return;
          }

          _cachedUser = null;
          _authStateController.add(null);
          final prefs = await _prefsFuture;
          await prefs.remove(_currentUserKey);
          return;
        }

        final user = AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? firebaseUser.email ?? 'Patient',
          phoneNumber: firebaseUser.phoneNumber ?? '',
        );

        final prefs = await _prefsFuture;
        await _persistUser(user, prefs);
      });
    });

    return _authStateController.stream;
  }

  AppUser? get currentUser {
    if (_cachedUser != null) return _cachedUser;
    if (Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
      final firebaseUser = FirebaseAuth.instance.currentUser!;
      return AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? firebaseUser.email ?? 'Patient',
        phoneNumber: firebaseUser.phoneNumber ?? '',
      );
    }
    return null;
  }

  Future<AppUser> _signInLocally(String email, String password) async {
    final prefs = await _prefsFuture;
    final usersJson = prefs.getString(_usersKey);
    final registeredUsers = <String, Map<String, dynamic>>{};

    if (usersJson != null) {
      final decoded = jsonDecode(usersJson) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        registeredUsers[entry.key] = Map<String, dynamic>.from(entry.value as Map);
      }
    }

    final normalizedEmail = email.trim().toLowerCase();
    final storedUser = registeredUsers[normalizedEmail];
    if (storedUser == null || storedUser['password'] != password) {
      throw Exception('Invalid credentials');
    }

    final user = AppUser.fromJson(Map<String, dynamic>.from(storedUser)
      ..remove('password'));
    await _persistUser(user, prefs);
    return user;
  }

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (await _ensureFirebaseInitialized()) {
      try {
        final credentials = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final firebaseUser = credentials.user!;
        final user = AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? firebaseUser.email ?? 'Patient',
          phoneNumber: firebaseUser.phoneNumber ?? '',
        );
        
        final prefs = await _prefsFuture;
        await _persistUser(user, prefs);
        await _saveUserLocally(email, password, user);
        
        return user;
      } on FirebaseAuthException catch (error) {
        debugPrint('Firebase sign-in failed (code: ${error.code})');
        try {
          debugPrint('Trying local auth fallback...');
          return await _signInLocally(email, password);
        } catch (_) {
          throw Exception(error.message ?? 'Firebase login failed');
        }
      } catch (error) {
        debugPrint('Firebase sign-in failed, trying local auth: $error');
        return _signInLocally(email, password);
      }
    }

    return _signInLocally(email, password);
  }

  Future<AppUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    if (await _ensureFirebaseInitialized()) {
      try {
        final credentials = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final firebaseUser = credentials.user!;
        final displayName = name.trim().isEmpty ? 'Patient' : name.trim();
        await firebaseUser.updateDisplayName(displayName);
        await firebaseUser.reload();

        final user = AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? displayName,
          phoneNumber: firebaseUser.phoneNumber ?? '',
        );
        await _persistUser(user, await _prefsFuture);
        return user;
      } on FirebaseAuthException catch (error) {
        throw Exception(error.message ?? 'Firebase registration failed');
      } catch (error) {
        debugPrint('Firebase registration failed, falling back to local register: $error');
      }
    }

    final prefs = await _prefsFuture;
    final usersJson = prefs.getString(_usersKey);
    final registeredUsers = <String, Map<String, dynamic>>{};

    if (usersJson != null) {
      final decoded = jsonDecode(usersJson) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        registeredUsers[entry.key] = Map<String, dynamic>.from(entry.value as Map);
      }
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (registeredUsers.containsKey(normalizedEmail)) {
      throw Exception('An account with this email already exists');
    }

    final user = AppUser(
      uid: DateTime.now().microsecondsSinceEpoch.toString(),
      email: normalizedEmail,
      displayName: name.trim().isEmpty ? 'Patient' : name.trim(),
      phoneNumber: '',
    );

    registeredUsers[normalizedEmail] = {
      ...user.toJson(),
      'password': password,
    };
    await prefs.setString(_usersKey, jsonEncode(registeredUsers));
    await _persistUser(user, prefs);
    return user;
  }

  Future<void> sendPasswordReset({required String email}) async {
    if (_firebaseEnabled) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        return;
      } on FirebaseAuthException catch (error) {
        throw Exception(error.message ?? 'Failed to send password reset email');
      }
    }

    await Future<void>.value();
  }

  Future<AppUser?> signInWithGoogle() async {
    if (await _ensureFirebaseInitialized()) {
      try {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          throw Exception('Google sign-in was cancelled.');
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );

        final signInResult = await FirebaseAuth.instance.signInWithCredential(credential);
        final firebaseUser = signInResult.user!;
        final user = AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? firebaseUser.email ?? 'Google User',
          phoneNumber: firebaseUser.phoneNumber ?? '',
        );
        await _persistUser(user, await _prefsFuture);
        return user;
      } on FirebaseAuthException catch (error) {
        throw Exception(error.message ?? 'Google sign-in failed');
      } catch (error) {
        debugPrint('Google sign-in failed, falling back to local stub: $error');
      }
    }

    final prefs = await _prefsFuture;
    final user = AppUser(
      uid: 'google-${DateTime.now().microsecondsSinceEpoch}',
      email: 'google-user@local.app',
      displayName: 'Google User',
      phoneNumber: '',
    );
    await _persistUser(user, prefs);
    return user;
  }

  Future<void> signOut() async {
    if (_firebaseEnabled) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }

    final prefs = await _prefsFuture;
    await prefs.remove(_currentUserKey);
    _cachedUser = null;
    _authStateController.add(null);
  }

  Future<void> _persistUser(AppUser user, SharedPreferences prefs) async {
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
    _cachedUser = user;
    _authStateController.add(user);
  }

  Future<AppUser?> _loadPersistedUser() async {
    if (_firebaseEnabled && FirebaseAuth.instance.currentUser != null) {
      final firebaseUser = FirebaseAuth.instance.currentUser!;
      final user = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? firebaseUser.email ?? 'Patient',
        phoneNumber: firebaseUser.phoneNumber ?? '',
      );
      _cachedUser = user;
      return user;
    }

    final prefs = await _prefsFuture;
    final storedUser = prefs.getString(_currentUserKey);
    if (storedUser == null || storedUser.isEmpty) {
      _cachedUser = null;
      return null;
    }

    final user = AppUser.fromJson(jsonDecode(storedUser) as Map<String, dynamic>);
    _cachedUser = user;
    return user;
  }

  Future<void> _saveUserLocally(String email, String password, AppUser user) async {
    final prefs = await _prefsFuture;
    final usersJson = prefs.getString(_usersKey);
    final registeredUsers = <String, Map<String, dynamic>>{};
    
    if (usersJson != null) {
      try {
        final decoded = jsonDecode(usersJson) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          registeredUsers[entry.key] = Map<String, dynamic>.from(entry.value as Map);
        }
      } catch (_) {}
    }
    
    final normalizedEmail = email.trim().toLowerCase();
    registeredUsers[normalizedEmail] = {
      ...user.toJson(),
      'password': password,
    };
    await prefs.setString(_usersKey, jsonEncode(registeredUsers));
  }

  Future<void> _initDefaultUser() async {
    final prefs = await _prefsFuture;
    final usersJson = prefs.getString(_usersKey);
    final registeredUsers = <String, Map<String, dynamic>>{};
    
    if (usersJson != null) {
      try {
        final decoded = jsonDecode(usersJson) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          registeredUsers[entry.key] = Map<String, dynamic>.from(entry.value as Map);
        }
      } catch (_) {}
    }
    
    // Ensure default doctor is registered
    if (!registeredUsers.containsKey('drbashir@gct.com')) {
      final defaultDoctor = AppUser(
        uid: 'doctor-bashir',
        email: 'drbashir@gct.com',
        displayName: 'Dr. Bashir Ahmad',
        phoneNumber: '+92 304 6996267',
      );
      registeredUsers['drbashir@gct.com'] = {
        ...defaultDoctor.toJson(),
        'password': 'password123',
      };
    }
    
    // Also ensure bashir@gmail.com is registered locally as fallback
    if (!registeredUsers.containsKey('bashir@gmail.com')) {
      final gmailDoctor = AppUser(
        uid: 'doctor-bashir-gmail',
        email: 'bashir@gmail.com',
        displayName: 'Dr. Bashir Ahmad',
        phoneNumber: '+92 304 6996267',
      );
      registeredUsers['bashir@gmail.com'] = {
        ...gmailDoctor.toJson(),
        'password': 'password123',
      };
    }
    
    // Also ensure khan@gmail.com is registered locally as fallback
    if (!registeredUsers.containsKey('khan@gmail.com')) {
      final khanUser = AppUser(
        uid: 'user-khan',
        email: 'khan@gmail.com',
        displayName: 'Khan',
        phoneNumber: '',
      );
      registeredUsers['khan@gmail.com'] = {
        ...khanUser.toJson(),
        'password': 'password123',
      };
    }

    await prefs.setString(_usersKey, jsonEncode(registeredUsers));
  }

}
