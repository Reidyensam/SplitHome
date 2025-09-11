import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import 'promote_user_page.dart';
import 'group_manager_admin_page.dart';

class SuperAdminPanel extends StatefulWidget {
  const SuperAdminPanel({super.key});

  @override
  State<SuperAdminPanel> createState() => _SuperAdminPanelState();
}

class _SuperAdminPanelState extends State<SuperAdminPanel> {
  bool isLoading = true;
  bool isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final response = await Supabase.instance.client
        .from('users')
        .select('role')
        .eq('id', user.id)
        .single();

    final role = response['role'];
    setState(() {
      isSuperAdmin = role == 'super_admin';
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!isSuperAdmin) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No tenés permisos para ver esta página.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Super Admin'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: RefreshIndicator(
          onRefresh: _checkAccess,
          child: ListView(
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.manage_accounts,
                    color: Colors.blue,
                  ),
                  title: const Text('Gestionar roles de usuario'),
                  subtitle: const Text(
                    'Promover, degradar y visualizar usuarios',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PromoteUserPage(),
                      ),
                    );
                  },
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.group, color: Colors.green),
                  title: const Text('Ver grupos'),
                  subtitle: const Text('Explorar grupos creados por usuarios'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GroupManagerAdminPage(),
                      ),
                    );
                  },
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.bar_chart, color: Colors.orange),
                  title: const Text('Métricas generales'),
                  subtitle: const Text(
                    'Usuarios activos, grupos creados, etc.',
                  ),
                  onTap: () {
                    // TODO: Implementar MetricsPage
                  },
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.settings, color: Colors.grey),
                  title: const Text('Configuración avanzada'),
                  subtitle: const Text('Opciones del sistema y permisos'),
                  onTap: () {
                    // TODO: Implementar SettingsPage
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
