import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionRedirectPage extends StatefulWidget {
  const SessionRedirectPage({super.key});

  @override
  State<SessionRedirectPage> createState() => _SessionRedirectPageState();
}

class _SessionRedirectPageState extends State<SessionRedirectPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarSesion();
    });
  }

  Future<void> _verificarSesion() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      try {
        final userData = await Supabase.instance.client
            .from('users')
            .select('role')
            .eq('id', user.id)
            .single();

        final role = userData['role'];
        final route = role == 'super_admin'
            ? '/super_admin_panel'
            : '/dashboard';

        if (mounted) {
          Future.microtask(() {
            Navigator.pushReplacementNamed(context, route);
          });
        }
      } catch (e) {
        if (mounted) {
          Future.microtask(() {
            Navigator.pushReplacementNamed(context, '/login');
          });
        }
      }
    } else {
      if (mounted) {
        Future.microtask(() {
          Navigator.pushReplacementNamed(context, '/login');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}