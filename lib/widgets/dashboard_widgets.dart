import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import 'package:splithome/widgets/expense_card.dart';
import 'package:splithome/services/dashboard_service.dart';

Widget buildCompactHeader(String name, String role) {
  Color iconColor;

  switch (role.toLowerCase()) {
    case 'admin':
      iconColor = const Color.fromARGB(255, 0, 140, 255);
      break;
    case 'user':
      iconColor = const Color.fromARGB(255, 255, 255, 255);
      break;
    default:
      iconColor = AppColors.primary;
  }

  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 16.0,
    ), // Alineado con el ListView
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.person,
          size: 36,
          color: iconColor,
        ), // Ícono más grande y con color dinámico
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola, $name',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Rol: $role',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget buildAppBarActions(BuildContext context, int unreadCount) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
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
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      IconButton(
        icon: const Icon(Icons.logout, color: Colors.redAccent),
        tooltip: 'Cerrar sesión',
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('¿Cerrar sesión?'),
              content: const Text(
                '¿Estás seguro que deseas salir de tu cuenta?',
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

          if (confirm == true) {
            await Supabase.instance.client.auth.signOut();
            if (!context.mounted) return;
            Navigator.pushReplacementNamed(context, '/login');
          }
        },
      ),
    ],
  );
}

Widget buildBalanceButton(BuildContext context) {
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

Widget buildRecentExpensesSection() {
  final ScrollController _expenseScrollController = ScrollController();

  return Card(
    color: AppColors.card,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: const Text(
            'Gastos Recientes del Mes',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Divider(color: Colors.grey),
        SizedBox(
          height: 400,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: DashboardService.getRecentExpensesForUser(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data;

if (data == null || data.isEmpty) {
  return const Center(
    child: Text(
      'Aún no has registrado ningún gasto.',
      style: TextStyle(color: AppColors.textSecondary),
    ),
  );
}

final now = DateTime.now();
final startOfMonth = DateTime(now.year, now.month, 1);

final filteredData = data.where((expense) {
  final date = DateTime.tryParse(expense['date'] ?? '') ?? DateTime(2000);
  return date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
         date.isBefore(now.add(const Duration(days: 1)));
}).toList();

if (filteredData.isEmpty) {
  return const Center(
    child: Text(
      'No hay gastos registrados este mes.',
      style: TextStyle(color: AppColors.textSecondary),
    ),
  );
}

              return Scrollbar(
                controller: _expenseScrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _expenseScrollController,
                  itemCount: filteredData.length,
                  itemBuilder: (context, index) {
                    final expense = filteredData[index];
                    final title = expense['title'] ?? '';
                    final rawDate =
                        DateTime.tryParse(expense['date'] ?? '') ??
                        DateTime.now();
                    final hour = rawDate.hour % 12 == 0
                        ? 12
                        : rawDate.hour % 12;
                    final period = rawDate.hour < 12 ? 'am' : 'pm';
                    final formattedTime =
                        '${hour}:${rawDate.minute.toString().padLeft(2, '0')} $period';
                    final formattedDate =
                        '${rawDate.day.toString().padLeft(2, '0')}-${rawDate.month.toString().padLeft(2, '0')}-${rawDate.year}';
                    final amount =
                        (expense['amount'] as num?)?.toDouble() ?? 0.0;
                    final groupName = expense['groups']?['name'] ?? 'Grupo';
                    final addedBy =
                        expense['user_id']?['name'] ?? 'Desconocido';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Columna 1
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formattedTime,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Columna 2
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Bs. ${amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Color.fromARGB(255, 0, 153, 255),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      groupName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        const Icon(
                                          Icons.person,
                                          size: 14,
                                          color: Color.fromARGB(
                                            255,
                                            47,
                                            212,
                                            5,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          addedBy,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color.fromARGB(
                                              255,
                                              47,
                                              212,
                                              5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16, thickness: 0.5),
                        ],
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
