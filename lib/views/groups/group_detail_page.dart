import 'package:flutter/material.dart';
import 'package:splithome/views/expenses/expense_form.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../dashboard/user_expense_page.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage>
    with TickerProviderStateMixin {
  bool showMembersExpanded = false;

  List<Map<String, dynamic>> members = [];
  List<Map<String, dynamic>> expenses = [];
  Map<String, double> balances = {};
  bool isLoading = true;
  bool showStatsDetails = false;

  DateTime? startDate;
  DateTime? endDate;
  String? selectedCategory;

  final double threshold = 1000.0;

  final TextEditingController emailController = TextEditingController();
  String selectedRole = 'user';
  String? currentUserRole;
  String selectedMonth = '';

  final List<String> meses = [
    'Todos',
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  List<Map<String, dynamic>> get filteredExpenses {
    final selectedMonthIndex = meses.indexOf(selectedMonth);

    return expenses.where((e) {
      final date = DateTime.parse(e['date']);
      final category = e['categories']?['name']?.trim().toLowerCase() ?? '';

      final matchesDate =
          startDate == null ||
          endDate == null ||
          (date.isAfter(startDate!) && date.isBefore(endDate!));
      final matchesCategory =
          selectedCategory == null ||
          category == selectedCategory!.toLowerCase();

      final matchesMonth = selectedMonth == 'Todos'
          ? true
          : date.month == selectedMonthIndex;

      return matchesDate && matchesCategory && matchesMonth;
    }).toList();
  }

  @override
  void initState() {
    selectedMonth = meses[DateTime.now().month];
    super.initState();

    final channel = Supabase.instance.client.channel('group_members_channel');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'group_members',
      callback: (payload) {
        final newRecord = payload.newRecord;
        print('Cambio detectado en canal: $newRecord');
        if (newRecord != null && newRecord['group_id'] == widget.groupId) {
          _loadGroupDetails();
        }
      },
    );

    channel.subscribe();
    _loadGroupDetails();
  }

  Future<void> _loadGroupDetails() async {
    final client = Supabase.instance.client;
    print('🔍 groupId recibido: ${widget.groupId}');
    print(
      '🧑 Usuario actual: ${Supabase.instance.client.auth.currentUser?.id}',
    );
    print('Cargando miembros para group_id=${widget.groupId}');

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null) {
      await Supabase.instance.client.rpc(
        'set_request_user',
        params: {'user_id': currentUserId},
      );
    }

    try {
      final memberResponse = await client
          .from('group_members')
          .select('user_id, role')
          .eq('group_id', widget.groupId);

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      String? roleInGroup;

      final currentMember = memberResponse.firstWhere(
        (m) => m['user_id'] == currentUserId,
        orElse: () => <String, dynamic>{},
      );

      if (currentMember != null && currentMember['role'] != null) {
        roleInGroup = currentMember['role'].toString();
      }

      final userIds = memberResponse
          .map((m) => m['user_id'].toString().trim())
          .toList();

      final userResponseList = await client
          .from('users')
          .select('id, name, email')
          .filter('id', 'in', userIds);

      print('IDs solicitados: $userIds');
      print('Usuarios recuperados:');
      print(userResponseList);

      final userMap = {for (var u in userResponseList) u['id']: u};

      final enrichedMembers = memberResponse.map((m) {
        final user = userMap[m['user_id']];
        return {...m, 'users': user ?? {}};
      }).toList();

      final expenseResponse = await client
          .from('expenses')
          .select('''
    id, title, amount, date, user_id,
    users!expenses_user_id_fkey(name),
    editor:updated_by(name),
    categories(name, icon, color)
    ''')
          .eq('group_id', widget.groupId)
          .order('date', ascending: false);
      print('📦 Miembros recibidos: $memberResponse');
      print('📦 Gastos recibidos: $expenseResponse');
      final expenseData = List<Map<String, dynamic>>.from(expenseResponse);

      final Map<String, double> tempBalances = {};
      for (var e in expenseData) {
        final userId = e['user_id'];
        final amount = (e['amount'] as num).toDouble();
        tempBalances[userId] = (tempBalances[userId] ?? 0) + amount;
      }

      if (!mounted) return;
      print(
        '✅ Preparando visualización: miembros=${enrichedMembers.length}, gastos=${expenseData.length}',
      );
      setState(() {
        members = enrichedMembers;
        expenses = expenseData;
        balances = tempBalances;
        currentUserRole = roleInGroup;
        isLoading = false;
      });
    } catch (e, stack) {
      print('❌ Error en _loadGroupDetails: $e');
      print('🧵 Stack trace: $stack');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _addMemberByEmail(String email, String role) async {
    final client = Supabase.instance.client;

    try {
      final userResponse = await client
          .from('users')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (userResponse == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Usuario no encontrado')));
        return;
      }

      final userId = userResponse['id'];

      final existing = await client
          .from('group_members')
          .select()
          .eq('group_id', widget.groupId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El usuario ya es miembro')),
        );
        return;
      }
      print(
        'Insertando en group_members: group_id=${widget.groupId}, user_id=$userId, role=$role',
      );

      await client.from('group_members').insert({
        'group_id': widget.groupId,
        'user_id': userId,
        'role': role,
      });

      await Future.delayed(const Duration(milliseconds: 300));

      await _loadGroupDetails();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Miembro agregado exitosamente')),
      );

      _loadGroupDetails();
    } catch (e) {
      print('Error al agregar miembro: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error al agregar miembro')));
    }
  }

  void _showAddMemberDialog() {
    emailController.clear();
    selectedRole = 'user';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar miembro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Correo del usuario',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(
                labelText: 'Rol',
                border: OutlineInputBorder(),
              ),
              items: ['user', 'admin']
                  .map(
                    (role) => DropdownMenuItem(value: role, child: Text(role)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) selectedRole = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Agregar'),
            onPressed: () async {
              final email = emailController.text.trim();
              await _addMemberByEmail(email, selectedRole);
              Navigator.pop(context, true);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Grupo: ${widget.groupName}'),
        backgroundColor: AppColors.primary,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadGroupDetails,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsSection(),

                  const SizedBox(height: 1),
                  _buildMemberList(),
                  const SizedBox(height: 5),
                  _buildExpenseList(),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _exportGroupData,
                    icon: const Icon(Icons.share),
                    label: const Text('Exportar gastos'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsSection() {
    final total = expenses.fold<double>(
      0,
      (sum, e) => sum + (e['amount'] as num).toDouble(),
    );
    final average = members.isNotEmpty ? total / members.length : 0;

    final sorted = balances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topSpender = sorted.isNotEmpty ? sorted.first : null;
    final lowestSpender = sorted.length > 1 ? sorted.last : null;

    final memberStats = members.map((m) {
      final userId = m['user_id'];
      final userName = m['users']?['name'] ?? 'Sin nombre';
      final userTotal = balances[userId] ?? 0.0;
      final percent = total > 0 ? (userTotal / total * 100) : 0;
      return {'name': userName, 'amount': userTotal, 'percentage': percent};
    }).toList();

    final highestSpender = topSpender != null
        ? {
            'name': members.firstWhere(
              (m) => m['user_id'] == topSpender.key,
            )['users']['name'],
            'amount': topSpender.value,
          }
        : null;

    final lowestSpenderData = lowestSpender != null
        ? {
            'name': members.firstWhere(
              (m) => m['user_id'] == lowestSpender.key,
            )['users']['name'],
            'amount': lowestSpender.value,
          }
        : null;

    final noSpenders = memberStats.where((m) => m['amount'] == 0).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        initiallyExpanded: showStatsDetails,
        onExpansionChanged: (expanded) {
          setState(() => showStatsDetails = expanded);
        },
        leading: const Icon(Icons.bar_chart, color: AppColors.accent),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Total: Bs. ${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.group, color: Colors.blue),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Promedio: Bs. ${average.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 24),
                const Text(
                  '📌 Contribuciones individuales',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                  },
                  children: [
                    const TableRow(
                      children: [
                        Text(
                          'Nombre',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Bs.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '%',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    ...memberStats.map(
                      (member) => TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(member['name']),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(member['amount'].toStringAsFixed(2)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${member['percentage'].toStringAsFixed(1)}%',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.trending_up, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      'Mayor gasto:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    if (highestSpender != null)
                      Flexible(
                        child: Text(
                          '${highestSpender['name']} - Bs. ${highestSpender['amount'].toStringAsFixed(2)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.trending_down, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    const Text(
                      'Menor gasto:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    if (lowestSpenderData != null)
                      Flexible(
                        child: Text(
                          '${lowestSpenderData['name']} - Bs. ${lowestSpenderData['amount'].toStringAsFixed(2)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (noSpenders.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.block, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text(
                        'Sin consumo:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          noSpenders.map((m) => m['name']).join(', '),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get filteredExpensesByMonth {
    final selectedMonthIndex = meses.indexOf(selectedMonth);

    return expenses.where((e) {
      final date = DateTime.parse(e['date']);
      final category = e['categories']?['name']?.trim().toLowerCase() ?? '';

      final matchesDate =
          startDate == null ||
          endDate == null ||
          (date.isAfter(startDate!) && date.isBefore(endDate!));
      final matchesCategory =
          selectedCategory == null ||
          category == selectedCategory!.toLowerCase();

      final matchesMonth = selectedMonth == 'Todos'
          ? true
          : date.month == selectedMonthIndex;

      return matchesDate && matchesCategory && matchesMonth;
    }).toList();
  }

  void _exportGroupData() async {
    final exportText = filteredExpenses
        .map((e) {
          final name = e['users']?['name'] ?? 'Sin nombre';
          final editorName = e['editor']?['name'];
          final wasEdited = editorName != null && editorName != name;
          final title = e['title'];
          final amount = e['amount'];
          final date = e['date'].toString().split(' ')[0];
          return '$name: $title - Bs. $amount ($date)';
        })
        .join(' ');

    if (exportText.trim().isNotEmpty) {
      await Share.share(exportText, subject: 'Exportación de gastos del grupo');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay gastos para exportar')),
      );
    }
  }

  Widget _buildMemberList() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: (expanded) {
          setState(() => showMembersExpanded = expanded);
        },
        leading: const Icon(Icons.group_outlined, color: AppColors.primary),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Miembros del grupo (${members.length})',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentUserRole == 'admin' || currentUserRole == 'super_admin')
              IconButton(
                icon: const Icon(Icons.person_add, color: AppColors.primary),
                tooltip: 'Agregar miembro',
                onPressed: _showAddMemberDialog,
              ),
            Icon(
              showMembersExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white,
            ),
          ],
        ),
        children: [
          const SizedBox(height: 10),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No hay miembros registrados.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...members.map((m) {
              final user = m['users'] ?? {};
              final name = user['name'] ?? 'Sin nombre';
              final email = user['email'] ?? 'Sin correo';
              final role = m['role'] ?? 'Sin rol';
              final memberId = m['user_id'];

              final isAdmin =
                  currentUserRole == 'admin' ||
                  currentUserRole == 'super_admin';
              final isSelf = currentUserId != null && memberId == currentUserId;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 25),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 15)),
                            Text(
                              '$email • Rol: $role',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.receipt_long, size: 23),
                        tooltip: 'Ver gastos',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserExpensePage(
                                userId: memberId,
                                userName: name,
                                groupId: widget.groupId,
                              ),
                            ),
                          );
                        },
                      ),
                      if (isAdmin && !isSelf)
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 23,
                            color: Colors.redAccent,
                          ),
                          tooltip: 'Eliminar miembro',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('¿Eliminar miembro?'),
                                content: const Text(
                                  'Esta acción no se puede deshacer. ¿Estás seguro de que deseas eliminar este miembro?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed != true) return;

                            final targetUserId = m['user_id']?.toString();
                            final groupId = widget.groupId?.toString();

                            if (groupId == null ||
                                groupId.isEmpty ||
                                targetUserId == null ||
                                targetUserId.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '⚠️ No se puede eliminar: datos inválidos.',
                                  ),
                                ),
                              );
                              return;
                            }

                            print(
                              '🧾 Eliminando user_id=$targetUserId del grupo=$groupId',
                            );

                            try {
                              await Supabase.instance.client
                                  .from('group_members')
                                  .delete()
                                  .match({
                                    'group_id': groupId,
                                    'user_id': targetUserId,
                                  });

                              final check = await Supabase.instance.client
                                  .from('group_members')
                                  .select()
                                  .eq('group_id', groupId)
                                  .eq('user_id', targetUserId);

                              if (check.isEmpty) {
                                setState(() {
                                  members.removeWhere(
                                    (m) =>
                                        m['user_id']?.toString() ==
                                        targetUserId,
                                  );
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Miembro eliminado'),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '⚠️ No tienes permiso para eliminar este miembro.',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('❌ Error al eliminar: $e'),
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.accent, size: 22),
            const SizedBox(width: 13),
            const Text(
              'Gastos registrados',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_card, color: AppColors.primary),
              tooltip: 'Agregar gasto',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExpenseForm(groupId: widget.groupId),
                  ),
                );
                if (result == true) {
                  _loadGroupDetails();
                }
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              const Text('Filtrar por mes:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: selectedMonth,
                items: meses.map((mes) {
                  return DropdownMenuItem(value: mes, child: Text(mes));
                }).toList(),
                onChanged: (nuevoMes) {
                  setState(() {
                    selectedMonth = nuevoMes!;
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        if (filteredExpensesByMonth.isEmpty)
          const Text(
            'No hay gastos registrados.',
            style: TextStyle(color: Colors.grey),
          ),

        ...filteredExpenses.map((e) {
          final amount = (e['amount'] as num).toDouble();
          final name = e['users']?['name'] ?? 'Sin nombre';
          final editorName = e['editor']?['name'];
          final wasEdited = editorName != null && editorName != name;
          final rawDate = DateTime.parse(e['date']);
          final hour = rawDate.hour % 12 == 0 ? 12 : rawDate.hour % 12;
          final period = rawDate.hour < 12 ? 'am' : 'pm';

          return GestureDetector(
            onTap: () {
              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id;
              final expenseUserId = e['user_id'];
              final isOwner =
                  currentUserId != null &&
                  expenseUserId != null &&
                  expenseUserId == currentUserId;
              final isPrivileged =
                  currentUserRole == 'admin' ||
                  currentUserRole == 'super_admin';

              if (isOwner || isPrivileged) {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Editar Gasto'),
                        onTap: () async {
                          Navigator.pop(context);
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExpenseForm(
                                groupId: widget.groupId,
                                expense: e,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadGroupDetails();
                          }
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete),
                        title: const Text('Eliminar gasto'),
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('¿Eliminar gasto?'),
                              content: const Text(
                                'Esta acción no se puede deshacer. ¿Estás seguro de que deseas eliminar este gasto?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            final expenseId = e['id'];

                            final isValidUuid =
                                expenseId is String &&
                                expenseId.isNotEmpty &&
                                RegExp(
                                  r'^[0-9a-fA-F\-]{36}$',
                                ).hasMatch(expenseId);

                            if (!isValidUuid) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '❌ No se pudo eliminar: ID inválido',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                              return;
                            }

                            try {
                              await Supabase.instance.client
                                  .from('expenses')
                                  .delete()
                                  .eq('id', expenseId);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            '✅ "${e['title']}" fue eliminado exitosamente',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color.fromARGB(
                                      255,
                                      64,
                                      148,
                                      67,
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    duration: const Duration(seconds: 3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }

                              _loadGroupDetails();
                              await Future.delayed(
                                const Duration(milliseconds: 300),
                              );
                              if (context.mounted) Navigator.pop(context);
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '❌ Error al eliminar: $error',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              }
            },
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              color: AppColors.card,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          e['title'],
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              getIconFromName(e['categories']?['icon']),
                              size: 18,
                              color: hexToColor(e['categories']?['color']),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              e['categories']?['name'] ?? 'Sin categoría',
                              style: TextStyle(
                                fontSize: 15,
                                color: hexToColor(e['categories']?['color']),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Bs. ${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (amount > threshold) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.report_problem_outlined,
                                color: Color.fromARGB(255, 230, 0, 0),
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '$hour:${rawDate.minute.toString().padLeft(2, '0')} $period',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (wasEdited) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.edit,
                                size: 15,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Modificado por: $editorName',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${rawDate.day.toString().padLeft(2, '0')}-${rawDate.month.toString().padLeft(2, '0')}-${rawDate.year}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
