import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_exception.dart';
import '../../core/app_modules.dart';
import '../../repositories/profile_repository.dart';
import '../../services/auth_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({AuthService? authService, ProfileRepository? profiles})
      : _authService = authService ?? AuthService(),
        _profiles = profiles ?? ProfileRepository(),
        super(const AuthState());

  final AuthService _authService;
  final ProfileRepository _profiles;

  Future<void> signIn(String email, String password) async {
    emit(const AuthState(status: AuthStatus.loading));
    try {
      final user = await _authService.signIn(email, password);
      final profile = await _profiles.resolve(user.id, user.email ?? email.trim());
      if (!profile.isActive || profile.role == AppRole.blocked) {
        await _signOutQuietly();
        emit(const AuthState(
          status: AuthStatus.blocked,
          message: 'حسابك غير مفعّل، تواصل مع الإدارة',
        ));
        return;
      }
      emit(AuthState(status: AuthStatus.roleResolved, profile: profile));
    } catch (error) {
      await _signOutQuietly();
      final message = mapError(error);
      final status = message == 'حسابك غير مفعّل، تواصل مع الإدارة'
          ? AuthStatus.blocked
          : AuthStatus.error;
      emit(AuthState(status: status, message: message));
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    emit(const AuthState());
  }

  Future<void> _signOutQuietly() async {
    try {
      await _authService.signOut();
    } catch (_) {}
  }
}
