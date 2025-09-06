import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';

class PromoteUserPage extends StatefulWidget {
  const PromoteUserPage({Key? key}) : super(key: key);

  @override
  _PromoteUserPageState createState() => _PromoteUserPageState();
}

class _PromoteUserPageState extends State<PromoteUserPage> {
  List<Map<String, dynamic>> superAdmins = [];
  List<Map<String, dynamic>> admins = [];
  List<Map<String, dynamic>> usuarios = [];
  bool isSuperAdmin = false;
  bool isLoading = true;
  Map<String, String> pendingRoleChanges = {};

  @override
  void initState() {
    super.initState();
    verificarMiRol();
    _loadUsers();
  }

  Future<void> verificarMiRol() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();

      final role = response['role'];
      setState(() {
        isSuperAdmin = role == 'super_admin';
      });
    } catch (e) {
      print('Error al verificar rol: $e');
    }
  }

  Future<void> _loadUsers() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, name, email, role');

      superAdmins.clear();
      admins.clear();
      usuarios.clear();

      for (final user in response) {
        final r = user['role'];
        if (r == 'super_admin') {
          superAdmins.add(user);
        } else if (r == 'admin') {
          admins.add(user);
        } else {
          usuarios.add(user);
        }
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error al cargar usuarios: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _changeRole(String userId, String newRole) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == userId || !isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tenés permiso para cambiar este rol')),
      );
      return;
    }

    try {
      await Supabase.instance.client
          .from('users')
          .update({'role': newRole})
          .eq('id', userId);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rol actualizado a "$newRole"')));

      await _loadUsers();
    } catch (e) {
      print('Error al cambiar rol: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cambiar rol: ${e.toString()}')),
      );
    }
  }

  Widget buildUserCard(Map<String, dynamic> user) {
    final userId = user['id'];
    final name = user['name'] ?? 'Sin nombre';
    final email = user['email'] ?? 'Sin correo';
    final role = user['role'];

    final validRoles = ['usuario', 'admin', 'super_admin'];
    final safeRole = validRoles.contains(role) ? role : null;
    final selectedRole = pendingRoleChanges[userId] ?? safeRole;

    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(name),
            subtitle: Text('$email • Rol actual: $role'),
            trailing: isSuperAdmin
                ? DropdownButton<String>(
                    value: selectedRole,
                    items: validRoles
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (newRole) {
                      setState(() {
                        if (newRole != null && newRole != role) {
                          pendingRoleChanges[userId] = newRole;
                        } else {
                          pendingRoleChanges.remove(userId);
                        }
                      });
                    },
                  )
                : null,
          ),
          if (isSuperAdmin &&
              pendingRoleChanges.containsKey(userId) &&
              pendingRoleChanges[userId] != role)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Aceptar cambio'),
                onPressed: () async {
                  final newRole = pendingRoleChanges[userId];
                  if (newRole != null) {
                    await _changeRole(userId, newRole);
                    setState(() {
                      pendingRoleChanges.remove(userId);
                    });
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _refreshUsers() async {
    await _loadUsers();
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
        title: const Text('Gestionar roles de usuario'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshUsers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '👑 Super Admins (${superAdmins.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...superAdmins.map(buildUserCard).toList(),

              const SizedBox(height: 24),
              Text(
                '🛠️ Admins (${admins.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...admins.map(buildUserCard).toList(),

              const SizedBox(height: 24),
              Text(
                '👤 Usuarios (${usuarios.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...usuarios.map(buildUserCard).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
