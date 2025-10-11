import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../views/expenses/expense_form.dart';

class GroupExpenseList extends StatelessWidget {
  final List<Map<String, dynamic>> expenses;
  final String groupId;
  final String? currentUserRole;
  final int selectedMonthIndex;
  final double threshold;
  final void Function(String fileName) onShowReceipt;
  final Future<void> Function() onRefreshGroup;
  final void Function(String message)? onShowSuccess;

  const GroupExpenseList({
    super.key,
    required this.expenses,
    required this.groupId,
    required this.currentUserRole,
    required this.selectedMonthIndex,
    required this.threshold,
    required this.onShowReceipt,
    required this.onRefreshGroup,
    required this.onShowSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final filteredExpenses = expenses.where((e) {
      final fecha = DateTime.tryParse(e['date']);
      return fecha != null &&
          (selectedMonthIndex == 0 || fecha.month == selectedMonthIndex);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.accent, size: 22),
            const SizedBox(width: 13),
            const Text(
              'Gastos Registrados',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_card, color: AppColors.primary),
              tooltip: 'Agregar gasto',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExpenseForm(groupId: groupId),
                  ),
                );
                if (result == true) {
                  await onRefreshGroup();
                }
              },
            ),
          ],
        ),
        if (filteredExpenses.isEmpty)
          const Text(
            'No hay gastos registrados en este mes.',
            style: TextStyle(color: Colors.grey),
          ),
        ...filteredExpenses.map((e) {
          final amount = (e['amount'] as num).toDouble();
          final name = e['users']?['name'] ?? 'Sin nombre';
          final editorName = e['editor']?['name'];
          final wasEdited = editorName != null && editorName != name;
          final rawDate = DateTime.parse(e['date']);
          final hour = rawDate.hour % 12 == 0 ? 12 : rawDate.hour % 12;
          final period = rawDate.hour < 12 ? 'am' : 'pm';

          return GestureDetector(
            onTap: () async {
              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id;
              final expenseUserId = e['user_id'];
              final isOwner =
                  currentUserId != null &&
                  expenseUserId != null &&
                  expenseUserId == currentUserId;
              final isPrivileged =
                  currentUserRole == 'admin' ||
                  currentUserRole == 'super_admin';

              if (isOwner || isPrivileged) {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Editar Gasto'),
                        onTap: () async {
                          if (context.mounted && Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ExpenseForm(groupId: groupId, expense: e),
                            ),
                          );
                          if (result == true) {
                            await onRefreshGroup();
                          }
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete),
                        title: const Text('Eliminar gasto'),
                        onTap: () async {
                          if (context.mounted && Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('¿Eliminar gasto?'),
                              content: const Text(
                                'Esta acción no se puede deshacer. ¿Estás seguro de que deseas eliminar este gasto?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            final expenseId = e['id'];
                            final isValidUuid =
                                expenseId is String &&
                                expenseId.isNotEmpty &&
                                RegExp(
                                  r'^[0-9a-fA-F\-]{36}$',
                                ).hasMatch(expenseId);

                            if (!isValidUuid) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '❌ No se pudo eliminar: ID inválido',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            try {
                              final receiptUrl = e['receipt_url'];
                              if (receiptUrl != null &&
                                  receiptUrl is String &&
                                  receiptUrl.isNotEmpty) {
                                await Supabase.instance.client.storage
                                    .from('receipts')
                                    .remove([receiptUrl]);
                              }

                              await Supabase.instance.client
                                  .from('expenses')
                                  .delete()
                                  .eq('id', expenseId);

                              final expenseTitle = e['title']
                                  ?.toString()
                                  .trim();
                              final displayTitle =
                                  (expenseTitle == null || expenseTitle.isEmpty)
                                  ? 'Gasto'
                                  : expenseTitle;

                              final currentUserId =
                                  Supabase.instance.client.auth.currentUser?.id;
                              final currentUserName =
                                  Supabase
                                      .instance
                                      .client
                                      .auth
                                      .currentUser
                                      ?.userMetadata?['name'] ??
                                  'Alguien';

                              final groupResponse = await Supabase
                                  .instance
                                  .client
                                  .from('groups')
                                  .select('name')
                                  .eq('id', groupId)
                                  .single();

                              final groupName =
                                  groupResponse['name'] ?? 'Grupo';

                              await notifyGroupExpense(
                                actorId: currentUserId!,
                                actorName: currentUserName,
                                groupId: groupId,
                                groupName: groupName,
                                expenseName: displayTitle,
                                type: 'expense_delete',
                              );

                              await onRefreshGroup();

                              print(
                                '✅ SnackBar debería mostrarse: $displayTitle',
                              );

                              onShowSuccess?.call(
                                '✅ "$displayTitle" fue eliminado exitosamente',
                              );
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '❌ Error al eliminar: $error',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              }
            },
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              color: AppColors.card,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap:
                                    (e['receipt_url'] is String &&
                                        e['receipt_url'].isNotEmpty)
                                    ? () => onShowReceipt(e['receipt_url'])
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 22,
                                    color: e['receipt_url'] != null
                                        ? Colors.blue
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 3),
                                  child: Text(
                                    e['title'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              getIconFromName(e['categories']?['icon']),
                              size: 18,
                              color: hexToColor(e['categories']?['color']),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              e['categories']?['name'] ?? 'Sin categoría',
                              style: TextStyle(
                                fontSize: 15,
                                color: hexToColor(e['categories']?['color']),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Bs. ${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (amount > threshold) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.report_problem_outlined,
                                color: Color.fromARGB(255, 230, 0, 0),
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '$hour:${rawDate.minute.toString().padLeft(2, '0')} $period',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (wasEdited) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.edit,
                                size: 15,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Modificado por: $editorName',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${rawDate.day.toString().padLeft(2, '0')}-${rawDate.month.toString().padLeft(2, '0')}-${rawDate.year}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
