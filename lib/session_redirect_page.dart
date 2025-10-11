import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionRedirectPage extends StatelessWidget {
  const SessionRedirectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    Future.microtask(() async {
      if (session != null) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;

        final userData = await Supabase.instance.client
            .from('users')
            .select('role')
            .eq('id', user.id)
            .single();

        final role = userData['role'];
        final route = role == 'super_admin' ? '/super_admin_panel' : '/dashboard';

        if (context.mounted) {
          Navigator.pushReplacementNamed(context, route);
        }
      } else {
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}