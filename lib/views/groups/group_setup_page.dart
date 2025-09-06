import 'package:flutter/material.dart'; import 'package:supabase_flutter/supabase_flutter.dart'; import '../../core/constants.dart';

class GroupSetupPage extends StatefulWidget { const GroupSetupPage({super.key});

@override State<GroupSetupPage> createState() => _GroupSetupPageState(); }

class _GroupSetupPageState extends State<GroupSetupPage> { final _formKey = GlobalKey<FormState>(); String groupName = ''; String selectedType = ''; bool isAdmin = false; bool isLoading = true; bool isSubmitting = false; List<String> groupTypes = [];

@override void initState() { super.initState(); _checkAdminStatus(); _loadGroupTypes(); }

Future<void> _loadUserGroups() async { final userId = Supabase.instance.client.auth.currentUser?.id; if (userId == null) return;

final response = await Supabase.instance.client
    .from('group_members')
    .select('group_id, groups(name)')
    .eq('user_id', userId);

print('Grupos actualizados: $response');

}

Future<void> _checkAdminStatus() async { final userId = Supabase.instance.client.auth.currentUser?.id; if (userId == null) return;

final response = await Supabase.instance.client
    .from('users')
    .select('role')
    .eq('id', userId)
    .single();

setState(() {
  isAdmin =
      response['role'] == 'admin' || response['role'] == 'super_admin';
  isLoading = false;
});

}

Future<void> _loadGroupTypes() async { final response = await Supabase.instance.client .from('group_types') .select('name') .order('name', ascending: true);

if (mounted && response != null) {
  setState(() {
    groupTypes = List<String>.from(response.map((item) => item['name']));
    selectedType = groupTypes.isNotEmpty ? groupTypes.first : '';
  });
}

}

Future<void> _createGroup() async { if (_formKey.currentState!.validate()) { setState(() => isSubmitting = true);

  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  try {
    final response = await Supabase.instance.client.from('groups').insert({
      'name': groupName,
      'type': selectedType,
      'created_by': userId,
    }).select();

    if (response == null || response.isEmpty) {
      throw Exception('No se pudo crear el grupo');
    }

    final groupId = response.first['id'];
    bool memberInsertOk = false;

    final existing = await Supabase.instance.client
        .from('group_members')
        .select()
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing == null) {
      final insertResponse = await Supabase.instance.client
          .from('group_members')
          .insert({'group_id': groupId, 'user_id': userId, 'role': 'admin'})
          .select();

      memberInsertOk = insertResponse != null && insertResponse.isNotEmpty;
    } else {
      memberInsertOk = true;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          memberInsertOk
              ? 'Grupo creado exitosamente'
              : 'Grupo creado, pero no se pudo agregar como miembro',
        ),
        backgroundColor:
            memberInsertOk ? AppColors.success : AppColors.warning,
      ),
    );

    if (memberInsertOk) {
      await _loadUserGroups();
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/group_detail_page',
          arguments: {'groupId': groupId, 'groupName': groupName},
        );
      }
    }
  } catch (error) {
    print('❌ Error en _createGroup: $error');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear grupo'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  if (mounted) setState(() => isSubmitting = false);
}

}

@override Widget build(BuildContext context) { if (isLoading) { return const Scaffold(body: Center(child: CircularProgressIndicator())); }

if (!isAdmin) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Crear Grupo'),
      backgroundColor: AppColors.primary,
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Acceso restringido: solo administradores pueden crear grupos',
            style: TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/dashboard');
            },
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            label: const Text(
              'Volver al menú principal',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

return Scaffold(
  appBar: AppBar(
    title: const Text('Crear Grupo'),
    backgroundColor: AppColors.primary,
  ),
  body: Padding(
    padding: const EdgeInsets.all(24.0),
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Nombre del grupo',
            ),
            validator: (value) =>
                value!.isEmpty ? 'Ingresa un nombre' : null,
            onChanged: (value) => groupName = value,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: groupTypes.contains(selectedType) ? selectedType : null,
            decoration: const InputDecoration(labelText: 'Tipo de grupo'),
            items: groupTypes
                .map((type) =>
                    DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) => selectedType = value ?? '',
            validator: (value) =>
                value == null || value.isEmpty ? 'Selecciona un tipo' : null,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: isSubmitting ? null : _createGroup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: 48,
                vertical: 12,
              ),
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Crear grupo',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
    ),
  ),
);

} }