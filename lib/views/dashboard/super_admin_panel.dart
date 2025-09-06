import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import 'group_detail_page.dart';

class SuperAdminPanel extends StatefulWidget {
  const SuperAdminPanel({super.key});

  @override
  State<SuperAdminPanel> createState() => _SuperAdminPanelState();
}

class _SuperAdminPanelState extends State<SuperAdminPanel> {
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> auditLogs = [];
  List<Map<String, dynamic>> filteredLogs = [];
  String selectedAction = '';
  String selectedUser = '';
  String selectedDate = '';
  bool isLoading = true;
  bool isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
    _loadData();
    _loadAuditLogs();
  }

  void _checkAccess() {
    final user = Supabase.instance.client.auth.currentUser;
    final role = user?.userMetadata?['role'];
    setState(() {
      isSuperAdmin = role == 'super_admin';
    });
  }

  Future<void> _loadData() async {
    final client = Supabase.instance.client;

    try {
      final userResponse = await client
          .from('users')
          .select('id, name, email, role');

      final groupResponse = await client
          .from('groups')
          .select('id, name, type, created_by');

      setState(() {
        users = List<Map<String, dynamic>>.from(userResponse);
        groups = List<Map<String, dynamic>>.from(groupResponse);
        isLoading = false;
      });
    } catch (e) {
      print('Error al cargar datos: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadAuditLogs() async {
    final client = Supabase.instance.client;

    try {
      final response = await client
          .from('audit_logs')
          .select('action, performed_by, timestamp, details, users(name)')
          .order('timestamp', ascending: false);

      setState(() {
        auditLogs = List<Map<String, dynamic>>.from(response);
        _applyFilters();
      });
    } catch (e) {
      print('Error al cargar logs de auditoría: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      filteredLogs = auditLogs.where((log) {
        final matchesAction =
            selectedAction.isEmpty || log['action'] == selectedAction;
        final matchesUser =
            selectedUser.isEmpty || log['users']?['name'] == selectedUser;
        final matchesDate =
            selectedDate.isEmpty ||
            log['timestamp'].toString().startsWith(selectedDate);
        return matchesAction && matchesUser && matchesDate;
      }).toList();
    });
  }

  Future<void> logAudit(String action, {Map<String, dynamic>? details}) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) return;

    await client.from('audit_logs').insert({
      'action': action,
      'performed_by': user.id,
      'timestamp': DateTime.now().toIso8601String(),
      if (details != null) 'details': details,
    });
  }

  Future<void> _changeUserRole(String userId, String newRole) async {
    await Supabase.instance.client
        .from('users')
        .update({'role': newRole})
        .eq('id', userId);

    await logAudit(
      'rol_actualizado',
      details: {'user_id': userId, 'nuevo_rol': newRole},
    );

    await _loadData();
    await _loadAuditLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Super Admin'),
        backgroundColor: AppColors.primary,
      ),
      body: !isSuperAdmin
          ? const Center(
              child: Text(
                '⛔ Acceso denegado.\nEste panel es solo para super administradores.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            )
          : isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '👥 Usuarios registrados',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                ...users.map(
                  (user) => Card(
                    child: ListTile(
                      title: Text(user['name'] ?? 'Sin nombre'),
                      subtitle: Text('${user['email']} • Rol: ${user['role']}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (newRole) =>
                            _changeUserRole(user['id'], newRole),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'user',
                            child: Text('Asignar: user'),
                          ),
                          const PopupMenuItem(
                            value: 'admin',
                            child: Text('Asignar: admin'),
                          ),
                          const PopupMenuItem(
                            value: 'super_admin',
                            child: Text('Asignar: super_admin'),
                          ),
                        ],
                        icon: const Icon(Icons.more_vert),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('🏠 Grupos creados', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                ...groups.map(
                  (group) => Card(
                    child: ListTile(
                      title: Text(group['name']),
                      subtitle: Text('Tipo: ${group['type']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
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
                ),
                const SizedBox(height: 24),
                const Text(
                  '🧾 Auditoría del sistema',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: selectedAction.isEmpty ? null : selectedAction,
                  hint: const Text('Filtrar por acción'),
                  items: auditLogs
                      .map((log) => log['action'])
                      .whereType<String>()
                      .toSet()
                      .map(
                        (action) => DropdownMenuItem<String>(
                          value: action,
                          child: Text(action),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    selectedAction = value ?? '';
                    _applyFilters();
                  },
                ),
                DropdownButton<String>(
                  value: selectedUser.isEmpty ? null : selectedUser,
                  hint: const Text('Filtrar por usuario'),
                  items: auditLogs
                      .map((log) => log['users']?['name'])
                      .whereType<String>()
                      .toSet()
                      .map(
                        (user) =>
                            DropdownMenuItem(value: user, child: Text(user)),
                      )
                      .toList(),
                  onChanged: (value) {
                    selectedUser = value ?? '';
                    _applyFilters();
                  },
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por fecha (YYYY-MM-DD)',
                  ),
                  onChanged: (value) {
                    selectedDate = value;
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 8),
                ...filteredLogs.map(
                  (log) => Card(
                    child: ListTile(
                      title: Text(log['action']),
                      subtitle: Text(
                        'Por: ${log['users']?['name'] ?? 'Desconocido'}',
                      ),
                      trailing: Text(
                        log['timestamp'].toString().split('T')[0],
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Detalles de ${log['action']}'),
                            content: Text(
                              log['details']?.toString() ?? 'Sin detalles',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cerrar'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
