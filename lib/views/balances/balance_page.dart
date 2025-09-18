import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';

class BalancePage extends StatefulWidget {
  const BalancePage({super.key});

  @override
  State<BalancePage> createState() => _BalancePageState();
}

class _BalancePageState extends State<BalancePage> {
  List<Map<String, dynamic>> expenses = [];
  List<Map<String, dynamic>> members = [];
  List<Map<String, dynamic>> userGroups = [];
  List<Map<String, dynamic>> categorias = [];

  bool isLoading = true;
  String selectedGroupId = '';
  String groupName = '';
  String selectedMonth = 'Todos';
  String selectedCategoryId = 'Todas';

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
  Map<int, double> get monthlyTotals {
    final Map<int, double> totals = {for (var i = 1; i <= 12; i++) i: 0.0};
    for (var e in expenses) {
      final rawDate = e['date'];
      if (rawDate == null) continue;
      final date = DateTime.tryParse(rawDate.toString());
      if (date == null) continue;

      final month = date.month;
      final amount = (e['amount'] as num).toDouble();
      totals[month] = (totals[month] ?? 0) + amount;
    }
    return totals;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadCategories();
  }

  Future<void> _loadInitialData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final groupResponse = await Supabase.instance.client
        .from('group_members')
        .select('group_id, groups(name)')
        .eq('user_id', userId);

    userGroups = List<Map<String, dynamic>>.from(groupResponse);

    if (userGroups.isNotEmpty) {
      selectedGroupId = userGroups.first['group_id'];
      groupName = userGroups.first['groups']['name'];
      await _loadGroupData();
    }
  }

  Future<void> _loadCategories() async {
    final response = await Supabase.instance.client
        .from('categories')
        .select('id, name');

    categorias = [
      {'id': 'Todas', 'name': 'Todas'},
    ];
    categorias.addAll(List<Map<String, dynamic>>.from(response));
    setState(() {});
    print('Categorías cargadas: $categorias');
  }

  Future<void> _loadGroupData() async {
    setState(() => isLoading = true);

    final response = await Supabase.instance.client
    .from('expenses')
    .select('amount, date, user_id, category_id, users!expenses_user_id_fkey(name)')
    .eq('group_id', selectedGroupId);

    final memberResponse = await Supabase.instance.client
        .from('group_members')
        .select('user_id, users(name)')
        .eq('group_id', selectedGroupId);

    expenses = List<Map<String, dynamic>>.from(response);
    members = List<Map<String, dynamic>>.from(memberResponse);

    setState(() => isLoading = false);
  }

List<Map<String, dynamic>> get filteredExpenses {
  final selectedMonthIndex = meses.indexOf(selectedMonth);
  return expenses.where((e) {
    final rawDate = e['date'];
    if (rawDate == null) return false;
    final date = DateTime.tryParse(rawDate.toString());
    if (date == null) return false;

    final matchesMonth = selectedMonth == 'Todos' || date.month == selectedMonthIndex;
    final matchesCategory = selectedCategoryId == 'Todas' || e['category_id'].toString() == selectedCategoryId;

    return matchesMonth && matchesCategory;
  }).toList();
}

  Map<String, double> get userTotals {
    final Map<String, double> totals = {};
    for (var e in filteredExpenses) {
      final userId = e['user_id'];
      final amount = (e['amount'] as num).toDouble();
      totals[userId] = (totals[userId] ?? 0) + amount;
    }
    return totals;
  }

  double get totalGroup => filteredExpenses.fold(
    0,
    (sum, e) => sum + (e['amount'] as num).toDouble(),
  );
  double get average => members.isNotEmpty ? totalGroup / members.length : 0;

  @override
  Widget build(BuildContext context) {
    final totals = userTotals;
    final pieData = {
      for (var m in members) m['users']['name']: totals[m['user_id']] ?? 0.0,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Balances de tus grupos'),
        backgroundColor: AppColors.primary,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector de grupo
                  if (userGroups.isNotEmpty)
                    DropdownButton<String>(
                      value: selectedGroupId,
                      hint: const Text('Selecciona un grupo'),
                      items: userGroups.map((group) {
                        return DropdownMenuItem(
                          value: group['group_id'].toString(),
                          child: Text(group['groups']['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedGroupId = value!;
                          groupName = userGroups.firstWhere(
                            (g) => g['group_id'] == value,
                          )['groups']['name'];
                        });
                        _loadGroupData();
                      },
                    ),

                  const SizedBox(height: 16),

                  // Filtro de mes
                  Row(
                    children: [
                      const Text('Mes:'),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: selectedMonth,
                        items: meses.map((m) {
                          return DropdownMenuItem(value: m, child: Text(m));
                        }).toList(),
                        onChanged: (value) {
                          setState(() => selectedMonth = value!);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16), // espacio entre los selectores

                  Row(
                    children: [
                      const Text('Categoría:'),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: selectedCategoryId,
                        items: categorias.map((c) {
                          return DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text(c['name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => selectedCategoryId = value!);
                        },
                      ),
                    ],
                  ),

                  // Resumen
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total del grupo: Bs. ${totalGroup.toStringAsFixed(2)}',
                          ),
                          Text(
                            'Promedio por persona: Bs. ${average.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // PieChart
                  if (pieData.values.any((v) => v > 0))
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: pieData.entries.map((entry) {
                            final percent = totalGroup > 0
                                ? (entry.value / totalGroup) * 100
                                : 0;
                            return PieChartSectionData(
                              value: entry.value,
                              title:
                                  '${entry.key}\n${percent.toStringAsFixed(1)}%',
                              color:
                                  Colors.primaries[pieData.keys
                                          .toList()
                                          .indexOf(entry.key) %
                                      Colors.primaries.length],
                              radius: 60,
                              titleStyle: const TextStyle(fontSize: 12),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                  if (monthlyTotals.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const Text(
                          'Gasto mensual del grupo',

                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 250,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 68, // más espacio vertical
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index < 1 || index > 12) {
                                        return const SizedBox();
                                      }
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        space:
                                            80, // separa el texto de la barra
                                        child: RotatedBox(
                                          quarterTurns: 3,
                                          child: SizedBox(
                                            width: 53,
                                            height: 60,
                                            child: Center(
                                              child: Text(
                                                meses[index],
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                softWrap: false,
                                                overflow: TextOverflow.visible,
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 48,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        'Bs ${value.toInt()}',
                                        style: const TextStyle(fontSize: 12),
                                        textAlign: TextAlign.right,
                                      );
                                    },
                                  ),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              barGroups: monthlyTotals.entries.map((entry) {
                                final color =
                                    Colors.primaries[(entry.key - 1) %
                                        Colors.primaries.length];
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value,
                                      color: color,
                                      width: 13,
                                      borderRadius: BorderRadius.circular(4),
                                      rodStackItems: [],
                                      backDrawRodData:
                                          BackgroundBarChartRodData(
                                            show: true,
                                            toY: monthlyTotals.values.reduce(
                                              (a, b) => a > b ? a : b,
                                            ),
                                            color: Colors.grey.shade200,
                                          ),
                                    ),
                                  ],
                                  showingTooltipIndicators: [0],
                                );
                              }).toList(),
                              gridData: FlGridData(show: true),
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),

                  // Tabla de contribuciones
                  const Text(
                    'Contribuciones individuales',
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
                      ...members.map((m) {
                        final name = m['users']['name'];
                        final amount = totals[m['user_id']] ?? 0.0;
                        final percent = totalGroup > 0
                            ? (amount / totalGroup * 100)
                            : 0;
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(name),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(amount.toStringAsFixed(2)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('${percent.toStringAsFixed(1)}%'),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
