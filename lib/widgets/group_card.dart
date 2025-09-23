import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';

class GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final bool isCreator;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const GroupCard({
    super.key,
    required this.group,
    required this.isCreator,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      child: ListTile(
        leading: const Icon(Icons.group, color: AppColors.primary),
        title: Text(group['groupName']),
        trailing: isCreator
            ? SizedBox(
                width: 96,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.primary),
                      tooltip: 'Editar grupo',
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      tooltip: 'Eliminar grupo',
                      onPressed: onDelete,
                    ),
                  ],
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}