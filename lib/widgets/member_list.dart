import 'package:flutter/material.dart';
import 'package:splithome/core/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemberList extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final String? currentUserRole;
  final String groupId;
  final VoidCallback onAddMember;
  final void Function(String memberId, String name) onViewExpenses;
  final VoidCallback onDeleteMember;

  const MemberList({
    super.key,
    required this.members,
    required this.currentUserRole,
    required this.groupId,
    required this.onAddMember,
    required this.onViewExpenses,
    required this.onDeleteMember,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    bool showMembersExpanded = false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: (expanded) => showMembersExpanded = expanded,
        leading: const Icon(Icons.group_outlined, color: AppColors.primary),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Miembros del grupo (${members.length})',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentUserRole == 'admin' || currentUserRole == 'super_admin')
              IconButton(
                icon: const Icon(Icons.person_add, color: AppColors.primary),
                tooltip: 'Agregar miembro',
                onPressed: onAddMember,
              ),
            const Icon(Icons.expand_more, color: Colors.white),
          ],
        ),
        children: [
          const SizedBox(height: 10),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No hay miembros registrados.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...members.map((m) {
              final user = m['users'] ?? {};
              final name = user['name'] ?? 'Sin nombre';
              final email = user['email'] ?? 'Sin correo';
              final role = m['role'] ?? 'Sin rol';
              final memberId = m['user_id'];

              final isAdmin = currentUserRole == 'admin' || currentUserRole == 'super_admin';
              final isSelf = currentUserId != null && memberId == currentUserId;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 25),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 15)),
                            Text(
                              '$email • Rol: $role',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.receipt_long, size: 23),
                        tooltip: 'Ver gastos',
                        onPressed: () => onViewExpenses(memberId, name),
                      ),
                      if (isAdmin && !isSelf)
                        IconButton(
                          icon: const Icon(Icons.delete, size: 23, color: Colors.redAccent),
                          tooltip: 'Eliminar miembro',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('¿Eliminar miembro?'),
                                content: const Text(
                                  'Esta acción no se puede deshacer. ¿Estás seguro de que deseas eliminar este miembro?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext, true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              final targetUserId = m['user_id']?.toString();
                              if (targetUserId != null && targetUserId.isNotEmpty) {
                                await Supabase.instance.client
                                    .from('group_members')
                                    .delete()
                                    .match({
                                      'group_id': groupId,
                                      'user_id': targetUserId,
                                    });
                                onDeleteMember();
                              }
                            }
                          },
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}