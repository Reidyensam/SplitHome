import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';

class ExpenseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<bool> addExpense(Expense expense) async {
    try {
      final response = await _client.from('expenses').insert(expense.toJson());
      return response != null;
    } catch (e) {
      print('Error al registrar gasto: $e');
      return false;
    }
  }

  Future<List<Expense>> getExpensesByGroup(String groupId) async {
    try {
      final response = await _client
          .from('expenses')
          .select()
          .eq('group_id', groupId)
          .order('date', ascending: false);

      if (response != null && response is List) {
        return response.map((e) => Expense.fromJson(e)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error al obtener gastos: $e');
      return [];
    }
  }
}