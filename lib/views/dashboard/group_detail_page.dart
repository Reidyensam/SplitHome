import 'package:flutter/material.dart';
import 'package:splithome/views/expenses/expense_form.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import 'user_expense_page.dart';

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
  List<Map<String, dynamic>> members = [];
  List<Map<String, dynamic>> expenses = [];
  Map<String, double> balances = {};
  bool isLoading = true;
  bool showStatsDetails = false;

  DateTime? startDate;
  DateTime? endDate;
  String? selectedCategory;

  final double threshold = 500.0;

  final TextEditingController emailController = TextEditingController();
  String selectedRole = 'user';
  String? currentUserRole;

  @override
  void initState() {
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
          .select(
            'id, title, amount, date, user_id, users!expenses_user_id_fkey(name), categories(name, icon, color)',
          )
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
                  const SizedBox(height: 16),
                  _buildFilterSection(),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _exportGroupData,
                    icon: const Icon(Icons.share),
                    label: const Text('Exportar gastos'),
                  ),
                  const SizedBox(height: 24),
                  _buildMemberList(),
                  const SizedBox(height: 24),
                  _buildExpenseList(),
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
            Text('Total: Bs. ${total.toStringAsFixed(2)}'),
            Text('Prom. por miembro: Bs. ${average.toStringAsFixed(2)}'),
          ],
        ),

        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (highestSpender != null) ...[
                  const Text(
                    'Mayor gasto',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(highestSpender['name']),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              highestSpender['amount'].toStringAsFixed(2),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                if (lowestSpenderData != null) ...[
                  const Text(
                    'Menor gasto',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(lowestSpenderData['name']),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              lowestSpenderData['amount'].toStringAsFixed(2),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                if (noSpenders.isNotEmpty) ...[
                  const Text(
                    'Sin consumo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...noSpenders.map((m) => Text('- ${m['name']}')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    final uniqueCategories = expenses
        .map((e) => e['categories']?['name'])
        .whereType<String>()
        .toSet()
        .toList();

    uniqueCategories.insert(0, 'Todas'); // Agrega opción "Todas" al inicio

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filtrar gastos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      startDate = picked.start;
                      endDate = picked.end;
                    });
                  }
                },
                icon: const Icon(Icons.date_range),
                label: const Text('Por fecha'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: selectedCategory ?? 'Todas',
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items: uniqueCategories
                    .map(
                      (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  selectedCategory = value == 'Todas' ? null : value;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (startDate != null && endDate != null)
          Text(
            'Rango seleccionado: ${startDate!.day}/${startDate!.month}/${startDate!.year} - ${endDate!.day}/${endDate!.month}/${endDate!.year}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }

  List<Map<String, dynamic>> get filteredExpenses {
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
      return matchesDate && matchesCategory;
    }).toList();
  }

  void _exportGroupData() async {
    final exportText = filteredExpenses
        .map((e) {
          final name = e['users']?['name'] ?? 'Sin nombre';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.group, color: AppColors.accent, size: 22),
            const SizedBox(width: 6),
            const Text(
              'Miembros del grupo',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (currentUserRole == 'admin' || currentUserRole == 'super_admin')
              IconButton(
                icon: const Icon(Icons.person_add, color: AppColors.primary),
                tooltip: 'Agregar miembro',
                onPressed: _showAddMemberDialog,
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (members.isEmpty)
          const Text(
            'No hay miembros registrados.',
            style: TextStyle(color: Colors.grey),
          )
        else
          ...members.map((m) {
            final user = m['users'] ?? {};
            final name = user['name'] ?? 'Sin nombre';
            final email = user['email'] ?? 'Sin correo';
            final role = m['role'] ?? 'Sin rol';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 20),
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
                      icon: const Icon(Icons.receipt_long, size: 18),
                      tooltip: 'Ver gastos',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserExpensePage(
                              userId: m['user_id'],
                              userName: name,
                              groupId: widget.groupId,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildExpenseList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.accent, size: 22),
            const SizedBox(width: 6),
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
        const SizedBox(height: 10),
        if (filteredExpenses.isEmpty)
          const Text(
            'No hay gastos registrados.',
            style: TextStyle(color: Colors.grey),
          ),
        ...filteredExpenses.map((e) {
          final amount = (e['amount'] as num).toDouble();
          final name = e['users']?['name'] ?? 'Sin nombre';
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
                          Navigator.pop(context);
                          await Supabase.instance.client
                              .from('expenses')
                              .delete()
                              .eq('id', e['id']);
                          _loadGroupDetails();
                        },
                      ),
                    ],
                  ),
                );
              }
            },
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              color: amount > threshold ? Colors.red[100] : AppColors.card,
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
                            Icon(getIconFromName(e['categories']?['icon']),
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
                        Text(
                          'Bs. ${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$hour:${rawDate.minute.toString().padLeft(2, '0')} $period',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
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
