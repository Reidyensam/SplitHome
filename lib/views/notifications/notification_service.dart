import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> notifyGroupExpense({
  required String actorId,
  required String actorName,
  required String groupId,
  required String groupName,
  required String expenseName,
  required String type, // 'expense_add', 'expense_edit', 'expense_delete'
}) async {
  print('🔔 Ejecutando notifyGroupExpense: $type');

  final members = await Supabase.instance.client
      .from('group_members')
      .select('user_id')
      .eq('group_id', groupId);

  print('👥 Miembros encontrados: ${members.length}');

  final formattedMessage = '“$expenseName”\nEn el grupo: "$groupName"';

  for (final member in members) {
    final targetUserId = member['user_id']?.toString().trim();
    if (targetUserId == null || targetUserId == actorId.trim()) {
      print('🔕 Ignorado (autor): $targetUserId');
      continue;
    }

    print('🔔 Notificando a: $targetUserId');

    await Supabase.instance.client.from('notifications').insert({
      'user_id': targetUserId,
      'type': type,
      'message': formattedMessage,
      'actor_name': actorName,
      'group_id': groupId,
      'group_name': groupName,
      'created_at': DateTime.now().toIso8601String(),
      'read': false,
    });
  }
}