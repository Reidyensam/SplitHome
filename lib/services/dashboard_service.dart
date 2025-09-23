import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  static Future<void> loadUserData(BuildContext context, Function(String, String) setUser) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final response = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    setUser(response['name'] ?? '', response['role'] ?? 'user');
  }

  static Future<int> getUnreadNotificationCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 0;

    final unread = await Supabase.instance.client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .eq('read', false);

    return unread.length;
  }

  static Future<List<Map<String, dynamic>>> getRecentNotifications() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    final recent = await Supabase.instance.client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(3);

    return List<Map<String, dynamic>>.from(recent);
  }

  static Future<List<Map<String, dynamic>>> getUserGroups() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await Supabase.instance.client
        .from('group_members')
        .select('group_id, groups(name, created_by)')
        .eq('user_id', userId);

    return response
        .where((g) => g['groups'] != null)
        .map((g) => {
              'groupId': g['group_id'],
              'groupName': g['groups']['name'],
              'creator_id': g['groups']['created_by'],
            })
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getRecentExpensesForUser() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    final groupResponse = await Supabase.instance.client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);

    final groupIds = groupResponse.map((g) => g['group_id'].toString()).toList();
    final orCondition = groupIds.map((id) => 'group_id.eq.$id').join(',');

    final expenses = await Supabase.instance.client
        .from('expenses')
        .select('title, amount, date, group_id, user_id, groups(name)')
        .or(orCondition)
        .order('date', ascending: false)
        .limit(10);

    return List<Map<String, dynamic>>.from(expenses);
  }

  static Future<double> calculateGroupMemberAverageSum(List<Map<String, dynamic>> userGroups) async {
    double totalPromedios = 0.0;

    for (final group in userGroups) {
      final groupId = group['groupId'];

      final gastos = await Supabase.instance.client
          .from('expenses')
          .select('amount')
          .eq('group_id', groupId);

      final miembros = await Supabase.instance.client
          .from('group_members')
          .select('user_id')
          .eq('group_id', groupId);

      final totalGasto = gastos.fold<double>(
        0.0,
        (sum, item) => sum + (item['amount'] as num).toDouble(),
      );

      final cantidadMiembros = miembros.isNotEmpty ? miembros.length : 1;
      final promedioPorMiembro = totalGasto / cantidadMiembros;

      totalPromedios += promedioPorMiembro;
    }

    return totalPromedios;
  }
}