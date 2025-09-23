import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'package:splithome/widgets/expense_card.dart';
import 'package:splithome/services/dashboard_service.dart';

/// Muestra el saludo y rol del usuario en el AppBar
Widget buildUserHeader(String name, String role) {
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

/// Botón para ver balances
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
  'Gastos Recientes',
  style: TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
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

              return Scrollbar(
                controller: _expenseScrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _expenseScrollController,
                  itemCount: data.length,
                  itemBuilder: (context, index) =>
                      ExpenseCard(expense: data[index]),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}