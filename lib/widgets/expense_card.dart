import 'package:flutter/material.dart';
import 'package:splithome/views/groups/group_comments_section.dart';
import '../../core/constants.dart';

class ExpenseCard extends StatelessWidget {
  final Map<String, dynamic> expense;

  const ExpenseCard({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    final title = expense['title'] ?? 'Sin título';
    final amount = expense['amount'] ?? 0;
    final groupName = expense['groups']?['name'] ?? 'Grupo desconocido';
    final createdAt = expense['date'];
    final formattedDate = createdAt != null ? formatearFecha(createdAt) : 'Sin fecha';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color.fromARGB(221, 236, 236, 236))),
                    const SizedBox(height: 4),
                    Text(formattedDate, style: const TextStyle(fontSize: 13, color: Color.fromARGB(255, 194, 194, 194))),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Bs. $amount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 86, 171, 211))),
                    const SizedBox(height: 4),
                    Text('Grupo: $groupName', style: const TextStyle(fontSize: 13, color: Color.fromARGB(255, 233, 233, 233))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}