import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AuthResponse?> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      print('Error al iniciar sesión: $e');
      return null;
    }
  }

  Future<AuthResponse?> signUp(
    String email,
    String password, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: data, // ← esta línea es clave
      );
      return response;
    } catch (e) {
      print('Error al registrar usuario: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      print('Error al cerrar sesión: $e');
    }
  }

  bool isLoggedIn() {
    return _client.auth.currentSession != null;
  }
}
