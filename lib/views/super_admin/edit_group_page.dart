import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';

class EditGroupPage extends StatefulWidget {
  final String groupId;
  final String initialName;

  const EditGroupPage({
    super.key,
    required this.groupId,
    required this.initialName,
  });

  @override
  State<EditGroupPage> createState() => _EditGroupPageState();
}

class _EditGroupPageState extends State<EditGroupPage> {
  late TextEditingController _nameController;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  Future<void> _updateGroup() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == widget.initialName) return;

    setState(() => isLoading = true);

    try {
      await Supabase.instance.client
          .from('groups')
          .update({'name': newName})
          .eq('id', widget.groupId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grupo actualizado')),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error al actualizar grupo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar grupo'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nuevo nombre del grupo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar cambios'),
                    onPressed: _updateGroup,
                  ),
          ],
        ),
      ),
    );
  }
}