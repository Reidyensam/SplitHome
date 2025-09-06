import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';

class ManageMembersPage extends StatefulWidget {
  final String groupId;

  const ManageMembersPage({super.key, required this.groupId});

  @override
  State<ManageMembersPage> createState() => _ManageMembersPageState();
}

class _ManageMembersPageState extends State<ManageMembersPage> {
  final emailController = TextEditingController();
  String selectedRole = 'miembro';
  List<Map<String, dynamic>> members = [];
  bool isAdmin = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Verifica si el usuario actual es el creador del grupo
    final group = await Supabase.instance.client
        .from('groups')
        .select('created_by')
        .eq('id', widget.groupId)
        .single();

    isAdmin = group['created_by'] == userId;

    // Carga los miembros del grupo
    final response = await Supabase.instance.client
        .from('group_members')
        .select('user_id, role, users(name, email)')
        .eq('group_id', widget.groupId);

    setState(() {
      members = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  Future<void> _addMember() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;

    // Busca el usuario por email
    final user = await Supabase.instance.client
        .from('users')
        .select('id')
        .eq('email', email)
        .single();

    if (user == null || user['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuario no encontrado'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final userId = user['id'];

    // Inserta en group_members
    await Supabase.instance.client.from('group_members').insert({
      'group_id': widget.groupId,
      'user_id': userId,
      'role': selectedRole,
    });

    emailController.clear();
    await _loadMembers();
  }

  Future<void> _removeMember(String userId) async {
    await Supabase.instance.client
        .from('group_members')
        .delete()
        .match({'group_id': widget.groupId, 'user_id': userId});

    await _loadMembers();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!isAdmin) {
      return Scaffold(
        body: Center(
          child: Text(
            'Acceso restringido: solo el creador del grupo puede gestionar miembros',
            style: TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar miembros'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Correo del usuario'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(labelText: 'Rol en el grupo'),
              items: ['miembro', 'editor']
                  .map((role) => DropdownMenuItem(
                        value: role,
                        child: Text(role),
                      ))
                  .toList(),
              onChanged: (value) => selectedRole = value!,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addMember,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Agregar miembro'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final name = member['users']['name'] ?? 'Sin nombre';
                  final email = member['users']['email'];
                  final role = member['role'];
                  final userId = member['user_id'];

                  return Card(
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text('$email • Rol: $role'),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeMember(userId),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}