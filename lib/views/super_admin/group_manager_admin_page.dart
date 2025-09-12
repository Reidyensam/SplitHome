import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:splithome/views/groups/group_detail_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import 'create_group_page.dart';

class GroupManagerAdminPage extends StatefulWidget {
  const GroupManagerAdminPage({super.key});

  @override
  State<GroupManagerAdminPage> createState() => _GroupManagerAdminPageState();
}

class _GroupManagerAdminPageState extends State<GroupManagerAdminPage> {
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> filteredGroups = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _searchController.addListener(_applyFilter);
  }

  Future<void> _loadGroups() async {
    setState(() => isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('groups')
          .select(
            'id, name, created_by, type, created_at, users!fk_created_by(name)',
          )
          .order('id', ascending: false);
      groups = List<Map<String, dynamic>>.from(response);
      print('Grupos cargados: $groups'); // ← Aquí ves qué llega realmente
      filteredGroups = groups;
    } catch (e) {
      print('Error al cargar grupos: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> _refreshGroups() async {
    await _loadGroups();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Grupos actualizados'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredGroups = groups.where((group) {
        final name = group['name']?.toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de grupos'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshGroups,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar grupo por nombre',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (filteredGroups.isEmpty)
              const Center(child: Text('No hay grupos disponibles.'))
            else
              ...filteredGroups.map(
                (group) => Card(
                  child: ListTile(
                    title: Text(
                      "${group['name']} — ${group['type'] ?? 'Sin tipo'}",
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Creado por: ${group['users']?['name'] ?? 'Desconocido'}',
                        ),
                        Text(
                          group['created_at'] != null
                              ? 'Creado el: ${DateFormat('dd/MM/yyyy - HH:mm').format(DateTime.parse(group['created_at']))}'
                              : 'Fecha desconocida',
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GroupDetailPage(
                            groupId: group['id'],
                            groupName: group['name'],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateGroupPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Crear grupo'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
