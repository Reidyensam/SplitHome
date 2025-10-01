import 'package:flutter/material.dart';
import '../../core/constants.dart';

class StatsSection extends StatelessWidget {
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> members;
  final Map<String, double> balances;
  final bool showStatsDetails;
  final void Function(bool expanded) onToggle;
  final int selectedMonthIndex;

  const StatsSection({
    super.key,
    required this.expenses,
    required this.members,
    required this.balances,
    required this.showStatsDetails,
    required this.onToggle,
    required this.selectedMonthIndex,
  });

  @override
  Widget build(BuildContext context) {
    final gastosDelMes = expenses.where((e) {
      final fecha = DateTime.tryParse(e['date']);
      return fecha != null &&
          (selectedMonthIndex == 0 || fecha.month == selectedMonthIndex);
    }).toList();

    final double total = gastosDelMes.fold<double>(
      0,
      (sum, e) => sum + (e['amount'] as num).toDouble(),
    );
    final average = members.isNotEmpty ? total / members.length : 0;

    final validUserIds = members.map((m) => m['user_id']).toSet();
    final filteredBalances = Map.fromEntries(
      balances.entries.where((e) => validUserIds.contains(e.key)),
    );

    final Map<String, double> monthlyBalances = {};
    for (var e in gastosDelMes) {
      final userId = e['user_id'];
      final amount = (e['amount'] as num).toDouble();

      if (userId is String && userId.isNotEmpty) {
        monthlyBalances[userId] = (monthlyBalances[userId] ?? 0) + amount;
      }
    }

    final memberStats = members.map((m) {
      final userId = m['user_id'];
      final userName = m['users']?['name'] ?? 'Sin nombre';
      final userTotal = monthlyBalances[userId] ?? 0.0;
      final percent = total > 0 ? (userTotal / total * 100) : 0;
      return {'name': userName, 'amount': userTotal, 'percentage': percent};
    }).toList();
    final sorted = monthlyBalances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topSpender = sorted.isNotEmpty ? sorted.first : null;
    final lowestSpender = sorted.length > 1 ? sorted.last : null;
    final highestSpenderData = topSpender != null
        ? {
            'name': members.firstWhere(
              (m) => m['user_id'] == topSpender.key,
              orElse: () => {
                'users': {'name': 'Desconocido'},
              },
            )['users']['name'],
            'amount': topSpender.value,
          }
        : null;

    final lowestSpenderData = lowestSpender != null
        ? {
            'name': members.firstWhere(
              (m) => m['user_id'] == lowestSpender.key,
              orElse: () => {
                'users': {'name': 'Desconocido'},
              },
            )['users']['name'],
            'amount': lowestSpender.value,
          }
        : null;

    final noSpenders = memberStats.where((m) => m['amount'] == 0).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        initiallyExpanded: showStatsDetails,
        onExpansionChanged: onToggle,
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
                if (highestSpenderData != null)
                  Row(
                    children: [
                      const Icon(Icons.trending_up, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text(
                        'Mayor gasto:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${highestSpenderData['name']} - Bs. ${highestSpenderData['amount'].toStringAsFixed(2)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                if (lowestSpenderData != null)
                  Row(
                    children: [
                      const Icon(Icons.trending_down, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      const Text(
                        'Menor gasto:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
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
}
