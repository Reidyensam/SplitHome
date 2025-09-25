import 'package:flutter/material.dart';
import 'package:splithome/views/expenses/expense_form.dart';
import 'package:splithome/views/groups/group_comments_section.dart';
import 'package:splithome/widgets/budget_card.dart';
import 'package:splithome/widgets/member_list.dart';
import 'package:splithome/widgets/stats_section.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  double monthlyBudget = 0.0;
  DateTime? startDate;
  DateTime? endDate;
  String? selectedCategory;
  int selectedMonthIndex = DateTime.now().month; // 1–12
  int selectedYear = DateTime.now().year;
  void _showEditBudgetDialog() {
    final TextEditingController budgetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar presupuesto mensual'),
        content: TextField(
          controller: budgetController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nuevo presupuesto (Bs.)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
            onPressed: () async {
              final input = budgetController.text.trim();
              final newBudget = double.tryParse(input);
              if (newBudget != null) {
                await _updateMonthlyBudget(newBudget);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingrese un número válido')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

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
id, title, amount, date, user_id, receipt_url,
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
      final budgetResponse = await client
          .from('groups')
          .select('monthly_budget')
          .eq('id', widget.groupId)
          .maybeSingle();

      final budgetValue = budgetResponse?['monthly_budget'];
      print('📥 Presupuesto recibido: $budgetValue');

      monthlyBudget = budgetValue is num ? budgetValue.toDouble() : 0.0;
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

  Future<void> _updateMonthlyBudget(double newBudget) async {
    final client = Supabase.instance.client;

    try {
      final response = await client
          .from('groups')
          .update({'monthly_budget': newBudget})
          .eq('id', widget.groupId)
          .select(); // 👈 Esto devuelve la fila actualizada

      print('✅ Supabase update response: $response');

      setState(() {
        monthlyBudget = newBudget;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Presupuesto actualizado')));
    } catch (e) {
      print('❌ Error al actualizar presupuesto: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar el presupuesto')),
      );
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

  void _mostrarComprobanteZoomable(String fileName) {
    final url = Supabase.instance.client.storage
        .from('receipts')
        .getPublicUrl(fileName);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Comprobante',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 300,
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 1,
                maxScale: 4,
                child: Image.network(url),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
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
    final double total = expenses.fold<double>(
      0,
      (sum, e) => sum + (e['amount'] as num).toDouble(),
    );

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
                  StatsSection(
                    expenses: expenses,
                    members: members,
                    balances: balances,
                    showStatsDetails: showStatsDetails,
                    onToggle: (expanded) =>
                        setState(() => showStatsDetails = expanded),
                  ),
                  const SizedBox(height: 1),

                  MemberList(
                    members: members,
                    currentUserRole: currentUserRole,
                    groupId: widget.groupId,
                    onAddMember: _showAddMemberDialog,
                    onViewExpenses: (memberId, name) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserExpensePage(
                          userId: memberId,
                          userName: name,
                          groupId: widget.groupId,
                        ),
                      ),
                    ),
                    onDeleteMember: _loadGroupDetails,
                  ),

                  BudgetCard(
                    monthlyBudget: monthlyBudget,
                    currentUserRole: currentUserRole,
                    totalSpent: expenses.fold<double>(
                      0,
                      (sum, e) => sum + (e['amount'] as num).toDouble(),
                    ),
                    onEditBudget: _showEditBudgetDialog,
                  ),

                  const SizedBox(height: 5),
                  _buildExpenseList(),
                  const SizedBox(height: 15),

                  GroupCommentsSection(
                    groupId: widget.groupId,
                    month: selectedMonthIndex,
                    year: selectedYear,
                  ),
                ],
              ),
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
                    selectedMonthIndex = meses.indexOf(
                      nuevoMes,
                    ); // ← esto es clave
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        if (filteredExpensesByMonth.isEmpty)
          const Text(
            'No hay gastos registrados en este mes.',
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
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: e['receipt_url'] != null
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                              onPressed: e['receipt_url'] != null
                                  ? () => _mostrarComprobanteZoomable(
                                      e['receipt_url'],
                                    )
                                  : null,
                              tooltip: e['receipt_url'] != null
                                  ? 'Ver comprobante'
                                  : 'Sin comprobante',
                            ),
                            const SizedBox(width: 4),
                            Text(
                              e['title'],
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
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
