import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';

class UserExpensePage extends StatefulWidget {
  final String userId;
  final String userName;
  final String groupId;

  const UserExpensePage({
    super.key,
    required this.userId,
    required this.userName,
    required this.groupId,
  });

  @override
  State<UserExpensePage> createState() => _UserExpensePageState();
}

class _UserExpensePageState extends State<UserExpensePage> {
  List<Map<String, dynamic>> expenses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserExpenses();
  }

  Future<void> _loadUserExpenses() async {
    final client = Supabase.instance.client;
    try {
      final response = await client
          .from('expenses')
          .select('title, amount, date')
          .eq('user_id', widget.userId)
          .eq('group_id', widget.groupId)
          .order('date', ascending: false);

      setState(() {
        expenses = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      print('Error al cargar gastos del usuario: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  double get totalSpent =>
      expenses.fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gastos de ${widget.userName}'),
        backgroundColor: AppColors.primary,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '🧾 Total gastado: Bs. ${totalSpent.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                ...expenses.map((e) {
                  final dateTime = DateTime.parse(e['date']);
                  final formattedDate =
                      '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
                  final formattedTime =
                      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Columna izquierda
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e['title'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fecha: $formattedDate',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          // Columna derecha
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Bs. ${e['amount'].toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hora: $formattedTime',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
