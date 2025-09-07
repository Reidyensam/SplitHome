import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseList extends StatefulWidget {
  final String groupId;
  const ExpenseList({super.key, required this.groupId});

  @override
  State<ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends State<ExpenseList> {
  List<Map<String, dynamic>> expenses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final result = await Supabase.instance.client
        .from('expenses')
        .select()
        .eq('group_id', widget.groupId)
        .order('date', ascending: false);

    setState(() {
      expenses = List<Map<String, dynamic>>.from(result);
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              final utcDate = DateTime.parse(expense['date']);
              final localDate = utcDate.toLocal();
              final formattedDate =
                  DateFormat('dd/MM/yyyy HH:mm').format(localDate);

              return Card(
                child: ListTile(
                  title: Text(expense['title']),
                  subtitle: Text('Bs. ${expense['amount'].toStringAsFixed(2)}'),
                  trailing: Text(formattedDate),
                ),
              );
            },
          );
  }
}