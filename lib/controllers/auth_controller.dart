import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/user_role.dart';
import '../utils/app_exception.dart';
import '../utils/app_logger.dart';
import '../utils/error_handler.dart';

class AuthController extends ChangeNotifier {
  AuthController() {
    _initialize();
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _rolesRef = FirebaseDatabase.instance.ref('roles');

  StreamSubscription<User?>? _authSubscription;
  User? _currentUser;
  UserRole? _currentRole;
  bool _loading = true;
  AppException? _error;

  User? get user => _currentUser;
  UserRole? get role => _currentRole;
  bool get isBusy => _loading;
  AppException? get error => _error;
  String? get errorMessage => _error?.userFriendlyMessage;
  bool get isAuthenticated => _currentUser != null;

  void _initialize() {
    _authSubscription = _auth.authStateChanges().listen(
      _onAuthChanged,
      onError: (error, stackTrace) {
        logger.error('Auth state change error', error, stackTrace);
        _error = ErrorHandler.handleError(error, stackTrace);
        _setLoading(false);
      },
    );
  }

  Future<void> signInOrRegister({
    required String email,
    required String password,
    required UserRole role,
    required bool isRegistering,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      logger.info(
        '${isRegistering ? 'Registering' : 'Signing in'} user with role: ${role.key}',
      );

      late UserCredential credential;
      if (isRegistering) {
        credential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        logger.info('User registered successfully: ${credential.user?.uid}');
        await _rolesRef.child(credential.user!.uid).set(role.key);
      } else {
        credential = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        logger.info('User signed in successfully: ${credential.user?.uid}');
      }

      await _verifyRole(credential.user!, role, isRegistering: isRegistering);
    } on FirebaseAuthException catch (error, stackTrace) {
      logger.error('Firebase auth error', error, stackTrace);
      _error = ErrorHandler.handleError(error, stackTrace) as AuthException;
    } on FirebaseException catch (error, stackTrace) {
      logger.error('Firebase error', error, stackTrace);
      _error = ErrorHandler.handleError(error, stackTrace);
    } catch (error, stackTrace) {
      logger.error('Unexpected auth error', error, stackTrace);
      _error = ErrorHandler.handleError(error, stackTrace);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      logger.info('Signing out user');
      await _auth.signOut();
      _error = null;
    } catch (error, stackTrace) {
      logger.error('Sign out error', error, stackTrace);
      _error = ErrorHandler.handleError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      logger.info('Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error, stackTrace) {
      logger.error('Password reset error', error, stackTrace);
      throw ErrorHandler.handleError(error, stackTrace);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  Future<void> _verifyRole(
    User user,
    UserRole requestedRole, {
    required bool isRegistering,
  }) async {
    try {
      final snapshot = await _rolesRef.child(user.uid).get();
      if (!snapshot.exists) {
        // If the user signed in before roles were stored, attach the requested role during this flow.
        logger.warning(
          'No role found for user ${user.uid}, setting to ${requestedRole.key}',
        );
        await _rolesRef.child(user.uid).set(requestedRole.key);
        return;
      }

      final storedRole = roleFromKey(snapshot.value.toString());
      if (storedRole != requestedRole) {
        if (isRegistering) {
          logger.info(
            'Updating role for user ${user.uid} to ${requestedRole.key}',
          );
          await _rolesRef.child(user.uid).set(requestedRole.key);
        } else {
          logger.warning(
            'Role mismatch for user ${user.uid}: stored=${storedRole.key}, requested=${requestedRole.key}',
          );
        }
      }
    } on FirebaseException catch (error, stackTrace) {
      logger.error('Role verification error', error, stackTrace);
      throw ErrorHandler.handleError(error, stackTrace);
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    try {
      _currentUser = user;
      if (user == null) {
        logger.info('User signed out');
        _currentRole = null;
        _setLoading(false);
        return;
      }

      logger.info('Auth state changed for user: ${user.uid}');
      final snapshot = await _rolesRef.child(user.uid).get();
      if (snapshot.exists) {
        _currentRole = roleFromKey(snapshot.value.toString());
        logger.info('User role loaded: ${_currentRole?.key}');
      } else {
        logger.warning('No role found for user: ${user.uid}');
        _currentRole = null;
      }
      _setLoading(false);
    } on FirebaseException catch (error, stackTrace) {
      logger.error('Failed to load user role', error, stackTrace);
      _error = ErrorHandler.handleError(error, stackTrace);
      _setLoading(false);
    }
  }
}
