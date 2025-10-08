import 'package:flutter/material.dart';
import 'package:splithome/views/expenses/expense_form.dart';
import 'package:splithome/views/expenses/group_expense_list.dart';
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

        if (userId is String && userId.isNotEmpty) {
          tempBalances[userId] = (tempBalances[userId] ?? 0) + amount;
        } else {
          print('⚠️ Gasto sin user_id válido: ${e['title']}');
        }
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

  void _mostrarComprobanteZoomable(String? fileName) {
    if (fileName == null || fileName.isEmpty) {
      debugPrint('Comprobante no disponible');
      return;
    }

    final url = Supabase.instance.client.storage
        .from('receipts')
        .getPublicUrl(fileName);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            return SizedBox(
              width: maxWidth * 0.95, // usa el 95% del ancho disponible
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
                  AspectRatio(
                    aspectRatio: 4 / 5,
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 1,
                      maxScale: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Text('No se pudo cargar el comprobante'),
                              ),
                        ),
                      ),
                    ),
                  ),
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
    final double totalDelMes = expenses
        .where((e) {
          final fecha = DateTime.tryParse(e['date']);
          return fecha != null &&
              (selectedMonthIndex == 0 || fecha.month == selectedMonthIndex);
        })
        .fold<double>(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.groupName}'),
        backgroundColor: AppColors.primary,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedMonth,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                dropdownColor: AppColors.primary,
                style: const TextStyle(color: Colors.white),
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
            ),
          ),
        ],
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
                    selectedMonthIndex: selectedMonthIndex,
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
                    totalSpent: totalDelMes, // ← filtrado por mes
                    onEditBudget: _showEditBudgetDialog,
                  ),

                  const SizedBox(height: 5),
                  GroupExpenseList(
                    expenses: expenses,
                    groupId: widget.groupId,
                    currentUserRole: currentUserRole,
                    selectedMonthIndex: selectedMonthIndex,
                    threshold: threshold,
                    onShowReceipt: _mostrarComprobanteZoomable,
                    onRefreshGroup: _loadGroupDetails,
                    onShowSuccess: (msg) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
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
}
