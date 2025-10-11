import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  static Future<void> loadUserData(
    BuildContext context,
    Function(String, String) setUser,
  ) async {
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
        .select('group_id, groups(name, created_by, limit)')
        .eq('user_id', userId);

    return response
        .where((g) => g['groups'] != null)
        .map(
          (g) => {
            'groupId': g['group_id'],
            'groupName': g['groups']['name'],
            'creator_id': g['groups']['created_by'],
            'limit': g['groups']['limit'], // puede ser null
          },
        )
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getRecentExpensesForUser() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    final groupResponse = await Supabase.instance.client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);

    final groupIds = groupResponse
        .map((g) => g['group_id'].toString())
        .toList();
    final orCondition = groupIds.map((id) => 'group_id.eq.$id').join(',');

    final expenses = await Supabase.instance.client
        .from('expenses')
        .select(
          'title, amount, date, group_id, user_id, groups(name), user_id(name)',
        )
        .or(orCondition)
        .order('date', ascending: false)
        .limit(10);

    return List<Map<String, dynamic>>.from(expenses);
  }

  static Future<double> calculateGroupMemberAverageSum(
    List<Map<String, dynamic>> userGroups,
  ) async {
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

  static Future<Map<String, dynamic>> getMonthlySpendingComparison(
    List<Map<String, dynamic>> userGroups,
  ) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return {
          'userTotal': 0.0,
          'expectedAverage': 0.0,
          'groupDetails': [],
          'userShouldReceive': 0.0,
          'userShouldContribute': 0.0,
        };
      }

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      final groupIds = userGroups.map((g) => g['groupId']).toList();
      final formattedIds = groupIds.join(',');

      // ✅ Gasto del usuario en el mes
      final userExpenses = await client
          .from('expenses')
          .select('amount')
          .eq('user_id', userId)
          .gte('date', startOfMonth.toIso8601String())
          .lte('date', endOfMonth.toIso8601String());

      final userTotal = userExpenses.fold<double>(
        0.0,
        (sum, item) => sum + (item['amount'] as num).toDouble(),
      );

      // ✅ Gasto total por grupo en el mes
      final groupExpenses = await client
          .from('expenses')
          .select('amount, group_id')
          .filter('group_id', 'in', '($formattedIds)')
          .gte('date', startOfMonth.toIso8601String())
          .lte('date', endOfMonth.toIso8601String());

      final Map<String, double> groupTotals = {};
      for (var item in groupExpenses) {
        final groupId = item['group_id'];
        final amount = (item['amount'] as num).toDouble();
        groupTotals[groupId] = (groupTotals[groupId] ?? 0.0) + amount;
      }

      List<Map<String, dynamic>> groupDetails = [];
      double expectedAverage = 0.0;

      for (var group in userGroups) {
        final groupId = group['groupId'];
        final groupName = group['groupName'];
        final groupLimit = group['limit'];

        final miembros = await client
            .from('group_members')
            .select('user_id')
            .eq('group_id', groupId);

        final memberCount = miembros.isNotEmpty ? miembros.length : 1;
        final total = groupTotals[groupId] ?? 0.0;
        expectedAverage += total / memberCount;
        final userGroupExpenses = await client
            .from('expenses')
            .select('amount')
            .eq('group_id', groupId)
            .eq('user_id', userId)
            .gte('date', startOfMonth.toIso8601String())
            .lte('date', endOfMonth.toIso8601String());

        final userContribution = userGroupExpenses.fold<double>(
          0.0,
          (sum, item) => sum + (item['amount'] as num).toDouble(),
        );
        groupDetails.add({
          'groupId': groupId,
          'groupName': groupName,
          'limit': groupLimit,
          'spent': total,
          'available': groupLimit != null ? (groupLimit - total) : null,
          'members': memberCount,
          'userContribution': userContribution,
        });
      }

      final difference = expectedAverage - userTotal;

      // ✅ Logs para depuración
      print('userTotal: $userTotal');
      print('expectedAverage: $expectedAverage');
      print('groupDetails: $groupDetails');
      print('groupIds: $groupIds');
      print('groupExpenses: $groupExpenses');

      return {
        'userTotal': userTotal,
        'expectedAverage': expectedAverage,
        'groupDetails': groupDetails,
        'userShouldReceive': difference < 0 ? difference.abs() : 0.0,
        'userShouldContribute': difference > 0 ? difference : 0.0,
      };
    } catch (e) {
      print('Error en getMonthlySpendingComparison: $e');
      return {
        'userTotal': 0.0,
        'expectedAverage': 0.0,
        'groupDetails': [],
        'userShouldReceive': 0.0,
        'userShouldContribute': 0.0,
      };
    }
  }
}
