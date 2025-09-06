import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';

class EditGroupPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const EditGroupPage({
    Key? key,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  State<EditGroupPage> createState() => _EditGroupPageState();
}

class _EditGroupPageState extends State<EditGroupPage> {
  final _formKey = GlobalKey<FormState>();
  late String groupName;
  String groupType = '';
  List<String> groupTypes = [];

  @override
  void initState() {
    super.initState();
    groupName = widget.groupName;
    _loadGroupType();
    _loadGroupTypes();
  }

  Future<void> _loadGroupType() async {
    final response = await Supabase.instance.client
        .from('groups')
        .select('type')
        .eq('id', widget.groupId)
        .single();

    if (mounted && response['type'] != null) {
      setState(() {
        groupType = response['type'];
      });
    }
  }

  Future<void> _loadGroupTypes() async {
    final response = await Supabase.instance.client
        .from('group_types')
        .select('name')
        .order('name', ascending: true);

    if (mounted && response != null) {
      setState(() {
        groupTypes = List<String>.from(response.map((item) => item['name']));
      });
    }
  }

  Future<void> _addGroupType(String newType) async {
    if (newType.trim().isEmpty) return;
    await Supabase.instance.client.from('group_types').insert({
      'name': newType.trim(),
    });
    await _loadGroupTypes();
  }

  void _showAddTypeDialog() {
    String newType = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar nuevo tipo de grupo'),
        content: TextField(
          decoration: const InputDecoration(hintText: 'Nuevo tipo'),
          onChanged: (value) => newType = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _addGroupType(newType);
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateGroup() async {
    await Supabase.instance.client
        .from('groups')
        .update({'name': groupName, 'type': groupType})
        .eq('id', widget.groupId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grupo actualizado correctamente')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar grupo'),
        backgroundColor: AppColors.card,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: groupName,
                decoration: const InputDecoration(
                  labelText: 'Nombre del grupo',
                ),
                onChanged: (value) => groupName = value,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: groupTypes.contains(groupType) ? groupType : null,
                decoration: const InputDecoration(labelText: 'Tipo de grupo'),
                items: groupTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) => groupType = value ?? '',
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showAddTypeDialog,
                  child: const Text('Agregar nuevo tipo'),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Guardar cambios'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor:
                      AppColors.textPrimary,
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _updateGroup();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
