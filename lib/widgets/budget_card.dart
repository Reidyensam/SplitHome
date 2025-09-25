import 'package:flutter/material.dart';
import 'package:splithome/core/constants.dart';

class BudgetCard extends StatelessWidget {
  final double monthlyBudget;
  final double totalSpent;
  final String? currentUserRole;
  final VoidCallback onEditBudget;

  const BudgetCard({
    super.key,
    required this.monthlyBudget,
    required this.totalSpent,
    required this.currentUserRole,
    required this.onEditBudget,
  });

  @override
  Widget build(BuildContext context) {
    final double usedPercentage = (totalSpent / monthlyBudget * 100).clamp(0.0, 100.0);
    final double remaining = (monthlyBudget - totalSpent).clamp(0.0, monthlyBudget);

    final Color barColor = totalSpent >= monthlyBudget
        ? Colors.red
        : totalSpent >= monthlyBudget * 0.75
            ? Colors.orange
            : Colors.green;

    final IconData statusIcon = totalSpent >= monthlyBudget
        ? Icons.warning
        : totalSpent >= monthlyBudget * 0.75
            ? Icons.info
            : Icons.check_circle;

    final String statusText = totalSpent >= monthlyBudget
        ? '⚠️ ¡Presupuesto mensual excedido!'
        : totalSpent >= monthlyBudget * 0.75
            ? '🔔 Estás alcanzando el presupuesto mensual'
            : 'Presupuesto en curso';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Color.fromARGB(255, 11, 169, 218)),
                const SizedBox(width: 8),
                Text(
                  monthlyBudget > 0
                      ? 'Presupuesto mensual: Bs. ${monthlyBudget.toStringAsFixed(2)}'
                      : 'Presupuesto no establecido',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (currentUserRole == 'admin')
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color.fromARGB(255, 11, 169, 218)),
                    tooltip: monthlyBudget > 0 ? 'Editar presupuesto' : 'Establecer presupuesto',
                    onPressed: onEditBudget,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (monthlyBudget > 0) ...[
              LinearProgressIndicator(
                value: (totalSpent / monthlyBudget).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[300],
                color: barColor,
                minHeight: 10,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(statusIcon, color: barColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: barColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    'Usado: ${usedPercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Disponible: Bs. ${remaining.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ] else ...[
              const Text(
                'Define un presupuesto mensual para activar el seguimiento.',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}