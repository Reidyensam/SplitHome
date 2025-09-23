import 'package:flutter/material.dart';
import 'package:splithome/services/dashboard_service.dart';
import 'package:splithome/widgets/dialogs.dart';
import 'package:splithome/widgets/group_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import 'package:splithome/widgets/dashboard_widgets.dart';
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
          title: buildUserHeader(name, role),
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
                  future: DashboardService.calculateGroupMemberAverageSum(
                    userGroups,
                  ),
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
                buildRecentExpensesSection(),
                const SizedBox(height: 16),
                buildBalanceButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupList() {
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
              if (role == 'admin')
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
            return GroupCard(
              group: group,
              isCreator: isCreator,
              onEdit: () {
                Navigator.pushNamed(
                  context,
                  '/edit_group_page',
                  arguments: {
                    'groupId': group['groupId'],
                    'groupName': group['groupName'],
                  },
                );
              },
              onDelete: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => buildDeleteDialog(context),
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
            );
          }).toList(),
        ],
      ),
    );
  }

  
}
