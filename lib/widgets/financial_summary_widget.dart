import 'package:flutter/material.dart'; import 'package:splithome/core/constants.dart'; import 'package:splithome/services/dashboard_service.dart';

class FinancialSummaryWidget extends StatefulWidget { final List<Map<String, dynamic>> userGroups;

const FinancialSummaryWidget({super.key, required this.userGroups});

@override State<FinancialSummaryWidget> createState() => _FinancialSummaryWidgetState(); }

class _FinancialSummaryWidgetState extends State<FinancialSummaryWidget> { bool isExpanded = false; bool isLoading = false; Map<String, dynamic>? financialData;

@override void didUpdateWidget(covariant FinancialSummaryWidget oldWidget) { super.didUpdateWidget(oldWidget); if (widget.userGroups != oldWidget.userGroups) { financialData = null; if (isExpanded) _loadFinancialData(); } }

void _loadFinancialData() async { setState(() => isLoading = true); final data = await DashboardService.getMonthlySpendingComparison( widget.userGroups, ); if (mounted) { setState(() { financialData = data; isLoading = false; }); } }

@override Widget build(BuildContext context) { if (widget.userGroups.isEmpty) { return const Center(child: Text('No tienes grupos aún')); }

return Card(
  margin: const EdgeInsets.symmetric(vertical: 8),
  child: ExpansionTile(
    initiallyExpanded: false,
    onExpansionChanged: (expanded) {
      setState(() => isExpanded = expanded);
      if (expanded && financialData == null) {
        _loadFinancialData();
      }
    },
    leading: const Icon(Icons.person, color: AppColors.primary),
    title: const Text(
      'Resumen Personal Del Mes',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    ),
    children: [
      if (isLoading)
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (financialData != null)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
  child: Text(
    '💰 TU GASTO GLOBAL DEL MES: Bs. ${financialData!['userTotal'].toStringAsFixed(2)}',
    style: const TextStyle(
      color: Color.fromARGB(255, 0, 173, 196),
      fontSize: 14,
      fontWeight: FontWeight.bold,
    ),
    textAlign: TextAlign.center,
  ),
),
              
              const SizedBox(height: 8),
              ...List<Map<String, dynamic>>.from(
                financialData!['groupDetails'],
              ).map((group) {
                final groupName = group['groupName'];
                final spent = (group['spent'] ?? 0.0) as double;
                final members = (group['members'] ?? 1) as int;
                final userContribution = (group['userContribution'] ?? 0.0) as double;
                final averagePerPerson = members > 0 ? spent / members : 0.0;
                final balance = userContribution - averagePerPerson;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          '$groupName ($members miembros)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gasto total: Bs. ${spent.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      Text(
                        '➡️ Promedio por persona: Bs. ${averagePerPerson.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      Text(
                        userContribution > 0
                            ? '✅ Aportaste Bs. ${userContribution.toStringAsFixed(2)}'
                            : '⚠️ No has aportado aún',
                        style: TextStyle(
                          color: userContribution > 0 ? Colors.green : Colors.orange,
                        ),
                      ),
                      Text(
                        balance >= 0
                            ? '🟢 +Bs. ${balance.toStringAsFixed(2)} sobre el promedio'
                            : '🔴 -Bs. ${balance.abs().toStringAsFixed(2)} bajo el promedio',
                        style: TextStyle(color: balance >= 0 ? Colors.green : Colors.red),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
    ],
  ),
);

} }