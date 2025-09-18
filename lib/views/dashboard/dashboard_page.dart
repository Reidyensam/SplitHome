import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String name = '';
  String role = '';
  bool isLoading = true;
  int unreadCount = 0;
  String? groupId;
  String? groupName;
  List<Map<String, dynamic>> recentNotifications = [];
  List<Map<String, dynamic>> userGroups = [];
  String? selectedGroupId;
  bool showGroupsExpanded = false;
  bool groupWasCreatedByCurrentUser(String groupId) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final group = userGroups.firstWhere(
      (g) => g['groupId'] == groupId,
      orElse: () => {},
    );
    return group['creator_id'] == userId;
  }

  Future<double> _calculateGroupMemberAverageSum() async {
    double totalPromedios = 0.0;

    for (final group in userGroups) {
      final groupId = group['groupId'];

      // Obtener todos los gastos del grupo
      final gastos = await Supabase.instance.client
          .from('expenses')
          .select(
            'id, title, amount, date, category_id, categories(name, icon, color)',
          )
          .eq('group_id', groupId);

      // Obtener todos los miembros del grupo
      final miembros = await Supabase.instance.client
          .from('group_members')
          .select('user_id')
          .eq('group_id', groupId);

      // Calcular el total de gastos
      final totalGasto = gastos.fold<double>(
        0.0,
        (sum, item) => sum + (item['amount'] as num).toDouble(),
      );

      // Calcular el promedio por miembro
      final cantidadMiembros = miembros.isNotEmpty ? miembros.length : 1;
      final promedioPorMiembro = totalGasto / cantidadMiembros;

      // Sumar ese promedio al total
      totalPromedios += promedioPorMiembro;
    }

    return totalPromedios;
  }

  @override
  void initState() {
    super.initState();

    _loadUserData();
    _loadNotificationSummary();
    _loadUserGroups();

    final channel = Supabase.instance.client.channel('group_members_channel');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'group_members',
      callback: (payload) {
        final newRecord = payload.newRecord;
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (newRecord != null && newRecord['user_id'] == userId) {
          _loadUserGroups();
        }
      },
    );

    channel.subscribe();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserGroups();
  }

  Future<List<Map<String, dynamic>>> getRecentExpensesForUser() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    final groupResponse = await Supabase.instance.client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);

    final groupIds = groupResponse
        .map((g) => g['group_id'].toString())
        .toList();

    final orCondition = groupIds.map((id) => 'group_id.eq.$id').join(',');

    final expenses = await Supabase.instance.client
        .from('expenses')
        .select('title, amount, date, group_id, user_id, groups(name)')
        .or(orCondition)
        .order('date', ascending: false)
        .limit(10);

    return List<Map<String, dynamic>>.from(expenses);
  }

  Future<void> _loadUserData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final response = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    if (!mounted) return;
    setState(() {
      name = response['name'] ?? '';
      role = response['role'] ?? 'user';
      isLoading = false;
    });
  }

  Future<void> _loadNotificationSummary() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final unread = await Supabase.instance.client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .eq('read', false);

    final recent = await Supabase.instance.client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(3);

    if (!mounted) return;
    setState(() {
      unreadCount = unread.length;
      recentNotifications = List<Map<String, dynamic>>.from(recent);
    });
  }

  Future<void> _loadUserGroups() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('group_members')
        .select('group_id, groups(name, created_by)')
        .eq('user_id', userId);

    if (!mounted) return;

    setState(() {
      userGroups = response
          .where((g) => g['groups'] != null)
          .map(
            (g) => {
              'groupId': g['group_id'],
              'groupName': g['groups']['name'],
              'creator_id': g['groups']['created_by'],
            },
          )
          .toList();

      selectedGroupId = userGroups.isNotEmpty
          ? userGroups.first['groupId']
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('¿Salir de la aplicación?'),
              content: const Text(
                '¿Estás seguro que deseas cerrar esta pantalla?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Salir'),
                ),
              ],
            ),
          );
          if (shouldExit ?? false) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _buildUserHeader(),
          backgroundColor: AppColors.card,
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  tooltip: 'Notificaciones',
                  onPressed: () {
                    Navigator.pushNamed(context, '/notificaciones');
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              tooltip: 'Cerrar sesión',
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadUserData();
              await _loadNotificationSummary();
              await _loadUserGroups();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              children: [
                FutureBuilder<double>(
                  future: _calculateGroupMemberAverageSum(),
                  builder: (context, snapshot) {
                    final value = snapshot.data ?? 0.0;
                    return Card(
                      color: AppColors.card,
                      child: ListTile(
                        title: const Text(
                          'Suma de promedios por miembro en tus grupos',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          'Bs. ${value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.bar_chart,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildGroupList(),
                const SizedBox(height: 16),
                _buildRecentExpensesAcrossGroups(),
                const SizedBox(height: 16),
                if (role == 'admin') _buildAdminActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader() {
    return Card(
      color: AppColors.card,
      child: ListTile(
        leading: const Icon(Icons.person, color: AppColors.primary),
        title: Text(
          'Hola, $name',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          'Rol: $role',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildGroupList() {
    if (userGroups.isEmpty) {
      return Card(
        color: AppColors.card,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'No estás en ningún grupo aún.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.group_add),
                label: const Text('Unirme a un grupo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/invitaciones');
                },
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: (expanded) {
          setState(() => showGroupsExpanded = expanded);
        },
        leading: const Icon(
          Icons.group_outlined,
          color: Color.fromARGB(255, 255, 255, 255),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grupos Agregados (${userGroups.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color.fromARGB(255, 255, 255, 255),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.group_add, size: 24),
                tooltip: 'Crear grupo',
                color: AppColors.primary,
                onPressed: () {
                  Navigator.pushNamed(context, '/crearGrupo');
                },
              ),
            ],
          ),
        ),
        children: [
          const SizedBox(height: 8),
          ...userGroups.map((group) {
            final isCreator = groupWasCreatedByCurrentUser(group['groupId']);
            return Card(
              color: AppColors.card,
              child: ListTile(
                leading: const Icon(Icons.group, color: AppColors.primary),
                title: Text(group['groupName']),
                trailing: isCreator
                    ? SizedBox(
                        width: 96,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: AppColors.primary,
                              ),
                              tooltip: 'Editar grupo',
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/edit_group_page',
                                  arguments: {
                                    'groupId': group['groupId'],
                                    'groupName': group['groupName'],
                                  },
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              tooltip: 'Eliminar grupo',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    int secondsLeft = 7;
                                    bool enabled = false;
                                    late Timer timer;

                                    return StatefulBuilder(
                                      builder: (context, setState) {
                                        if (secondsLeft == 7) {
                                          timer = Timer.periodic(
                                            const Duration(seconds: 1),
                                            (t) {
                                              if (secondsLeft > 1) {
                                                setState(() => secondsLeft--);
                                              } else {
                                                t.cancel();
                                                setState(() {
                                                  secondsLeft = 0;
                                                  enabled = true;
                                                });
                                              }
                                            },
                                          );
                                        }

                                        return AlertDialog(
                                          title: const Text('¿Eliminar grupo?'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Text(
                                                'Esta acción no se puede deshacer.',
                                              ),
                                              SizedBox(height: 12),
                                              Text(
                                                'El botón eliminar se habilitará en 7 segundos...',
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                timer.cancel();
                                                Navigator.pop(context, false);
                                              },
                                              child: const Text('Cancelar'),
                                            ),
                                            ElevatedButton(
                                              onPressed: enabled
                                                  ? () {
                                                      timer.cancel();
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      );
                                                    }
                                                  : null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent,
                                              ),
                                              child: Text(
                                                enabled
                                                    ? 'Eliminar definitivamente'
                                                    : 'Eliminar (${secondsLeft})',
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );

                                if (confirm == true) {
                                  await Supabase.instance.client
                                      .from('group_members')
                                      .delete()
                                      .eq('group_id', group['groupId']);

                                  await Supabase.instance.client
                                      .from('groups')
                                      .delete()
                                      .eq('id', group['groupId']);

                                  await _loadUserGroups();
                                }
                              },
                            ),
                          ],
                        ),
                      )
                    : null,
                onTap: () {
                  setState(() {
                    selectedGroupId = group['groupId'];
                  });
                  Navigator.pushNamed(
                    context,
                    '/group_detail_page',
                    arguments: {
                      'groupId': group['groupId'],
                      'groupName': group['groupName'],
                    },
                  );
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRecentExpensesAcrossGroups() {
    final ScrollController _expenseScrollController = ScrollController();

    return Card(
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: const Text(
              'Gastos recientes',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            trailing: const Icon(Icons.receipt_long, color: AppColors.primary),
          ),
          const Divider(color: Colors.grey),
          SizedBox(
            height: 400,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: getRecentExpensesForUser(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'No se pudieron cargar los gastos.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }
                final data = snapshot.data;
                if (data == null || data.isEmpty) {
                  return const Center(
                    child: Text('No hay gastos registrados.'),
                  );
                }

                return Scrollbar(
                  controller: _expenseScrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _expenseScrollController,
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final expense = data[index];
                      final title = expense['title'] ?? 'Sin título';
                      final amount = expense['amount'] ?? 0;
                      final groupName =
                          expense['groups']?['name'] ?? 'Grupo desconocido';
                      final createdAt = expense['date'];
                      final formattedDate = createdAt != null
                          ? DateFormat(
                              'dd/MM/yyyy – HH:mm',
                            ).format(DateTime.parse(createdAt))
                          : 'Sin fecha';

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4.0,
                          horizontal: 8.0,
                        ),
                        child: Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(
                            vertical: 1,
                            horizontal: 4,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color.fromARGB(
                                            221,
                                            236,
                                            236,
                                            236,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formattedDate,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color.fromARGB(
                                            255,
                                            194,
                                            194,
                                            194,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Bs. $amount',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: const Color.fromARGB(
                                            255,
                                            86,
                                            171,
                                            211,
                                          ), // solo el monto resaltado
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Grupo: $groupName',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color.fromARGB(
                                            255,
                                            233,
                                            233,
                                            233,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActions() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 24,
        runSpacing: 16,
        children: [
           Column(
            children: [
              IconButton(
                icon: const Icon(Icons.account_balance, size: 32),
                tooltip: 'Ver balances',
                color: AppColors.primary,
                onPressed: () {
                  Navigator.pushNamed(context, '/balances');
                },
              ),
              const Text('Ver balances'),
            ],
          ),
        ],
      ),
    );
  }
}
