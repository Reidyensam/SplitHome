import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
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

  final pieChartKey = GlobalKey();
  final barChartKey = GlobalKey();

  Future<Uint8List?> _captureChartAsImage(GlobalKey key) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  String _generarInterpretacion() {
    if (members.isEmpty) return '';
    final mayor = members.reduce(
      (a, b) =>
          (userTotals[a['user_id']] ?? 0) > (userTotals[b['user_id']] ?? 0)
          ? a
          : b,
    );
    final menor = members.reduce(
      (a, b) =>
          (userTotals[a['user_id']] ?? 0) < (userTotals[b['user_id']] ?? 0)
          ? a
          : b,
    );
    final mayorNombre = mayor['users']['name'];
    final menorNombre = menor['users']['name'];
    final mayorMonto =
        userTotals[mayor['user_id']]?.toStringAsFixed(2) ?? '0.00';
    final menorMonto =
        userTotals[menor['user_id']]?.toStringAsFixed(2) ?? '0.00';

    return 'Durante el mes de $selectedMonth, el grupo $groupName presentó un gasto total de Bs. ${totalGroup.toStringAsFixed(2)}. '
        '$mayorNombre fue quien más aportó (Bs. $mayorMonto), mientras que $menorNombre tuvo la menor contribución (Bs. $menorMonto).';
  }

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

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();
    final insights = _generarInterpretacion();
    final pieImage = await _captureChartAsImage(pieChartKey);
    final barImage = await _captureChartAsImage(barChartKey);

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Balance del grupo $groupName')),
          pw.Paragraph(text: 'Mes: $selectedMonth'),
          pw.Paragraph(text: 'Categoría: $selectedCategoryId'),
          if (pieImage != null) pw.Image(pw.MemoryImage(pieImage)),
          if (barImage != null) pw.Image(pw.MemoryImage(barImage)),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Nombre', 'Bs.', '%', '±'],
            data: members.map((m) {
              final name = m['users']['name'];
              final amount = userTotals[m['user_id']] ?? 0.0;
              final percent = totalGroup > 0 ? (amount / totalGroup * 100) : 0;
              final diff = average - amount;
              final diffText = diff.abs().toStringAsFixed(2);
              final symbol = diff > 0 ? '+$diffText' : '-$diffText';
              return [
                name,
                amount.toStringAsFixed(2),
                '${percent.toStringAsFixed(1)}%',
                symbol,
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Paragraph(text: insights),
          pw.Paragraph(
            text:
                'Total del grupo: Bs. ${totalGroup.toStringAsFixed(2)}\n'
                'Promedio por persona: Bs. ${average.toStringAsFixed(2)}',
          ),
        ],
      ),
    );

    final dir = Directory('/storage/emulated/0/Download');
    final safeName = '${groupName}_$selectedMonth'.replaceAll(
      RegExp(r'[^\w]+'),
      '_',
    );
    final file = File('${dir.path}/balance_$safeName.pdf');

    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('PDF guardado en ${file.path}')));
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
        .select(
          'amount, date, user_id, category_id, users!expenses_user_id_fkey(name)',
        )
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

      final matchesMonth =
          selectedMonth == 'Todos' || date.month == selectedMonthIndex;
      final matchesCategory =
          selectedCategoryId == 'Todas' ||
          e['category_id'].toString() == selectedCategoryId;

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
                  const SizedBox(height: 32),

                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      // Selector de grupo
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          value: selectedGroupId,
                          decoration: const InputDecoration(labelText: 'Grupo'),
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
                      ),

                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          value: selectedMonth,
                          decoration: const InputDecoration(labelText: 'Mes'),
                          items: meses.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m));
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedMonth = value!);
                          },
                        ),
                      ),

                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          value: selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                          ),
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
                      ),
                    ],
                  ),

                  // Resumen
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total del grupo',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Bs. ${totalGroup.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Promedio por persona',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Bs. ${average.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
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

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        'Contribuciones Individuales',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: DataTable(
                            columnSpacing: 32,
                            headingRowHeight: 48,
                            dataRowHeight: 50,
                            headingRowColor: WidgetStateColor.resolveWith(
                              (states) => AppColors.card,
                            ),
                            dataRowColor: WidgetStateColor.resolveWith(
                              (states) => AppColors.background,
                            ),
                            columns: const [
                              DataColumn(
                                label: Center(
                                  child: Text(
                                    'Nombre',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Center(
                                  child: Text(
                                    'Bs.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Center(
                                  child: Text(
                                    '%',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Center(
                                  child: Text(
                                    '±',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            rows: members.map((m) {
                              final name = m['users']['name'];
                              final amount = totals[m['user_id']] ?? 0.0;
                              final percent = totalGroup > 0
                                  ? (amount / totalGroup * 100)
                                  : 0;
                              final diff = average - amount;
                              final diffText = diff.abs().toStringAsFixed(2);
                              final symbol = diff > 0
                                  ? '+$diffText'
                                  : '-$diffText';
                              final diffColor = diff > 0
                                  ? AppColors.error
                                  : AppColors.success;

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Center(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Center(
                                      child: Text(
                                        amount.toStringAsFixed(2),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Center(
                                      child: Text(
                                        '${percent.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Center(
                                      child: Text(
                                        symbol,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: diffColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _exportToPdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Exportar Balance - PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
