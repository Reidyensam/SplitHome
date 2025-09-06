import 'package:flutter/material.dart';
import 'package:splithome/core/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseForm extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic>? expense;

  const ExpenseForm({super.key, required this.groupId, this.expense});

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  String title = '';
  double amount = 0.0;
  DateTime selectedDate = DateTime.now();
  String? selectedCategoryId;
  List<Map<String, dynamic>> categoryOptions = [];

  Future<void> _loadCategories() async {
    final response = await Supabase.instance.client
        .from('categories')
        .select('id, name')
        .order('name');
    setState(() {
      categoryOptions = List<Map<String, dynamic>>.from(response);
      if (widget.expense != null) {
        selectedCategoryId = widget.expense!['category_id'];
      }
    });
  }

  Future<void> _submitExpense() async {
    if (_formKey.currentState!.validate()) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final client = Supabase.instance.client;

      if (userId != null) {
        final data = {
          'title': title,
          'amount': amount,
          'date': selectedDate.toIso8601String(),
          'category_id': selectedCategoryId,
          'group_id': widget.groupId,
          'user_id': userId,
        };

        if (widget.expense != null) {
          await client
              .from('expenses')
              .update(data)
              .eq('id', widget.expense!['id']);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gasto actualizado exitosamente')),
          );
        } else {
          await client.from('expenses').insert(data);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gasto registrado exitosamente')),
          );
        }

        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    if (expense != null) {
      title = expense['title'] ?? '';
      amount = (expense['amount'] as num).toDouble();
      selectedDate = DateTime.parse(expense['date']);
    }
    _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.expense != null ? 'Editar gasto' : 'Registrar gasto',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: title,
                decoration: const InputDecoration(
                  labelText: 'Título del gasto',
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa un título' : null,
                onChanged: (value) => title = value,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: amount != 0.0 ? amount.toString() : '',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monto (Bs.)'),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa un monto' : null,
                onChanged: (value) => amount = double.tryParse(value) ?? 0.0,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Fecha: ${selectedDate.toLocal().toString().split(' ')[0]}',
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _pickDate,
                    child: const Text('Cambiar fecha'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategoryId,
                items: categoryOptions.map((cat) {
                  return DropdownMenuItem(
                    value: cat['id'].toString(),
                    child: Text(cat['name']),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => selectedCategoryId = value),
                decoration: const InputDecoration(labelText: 'Categoría'),
                validator: (value) =>
                    value == null ? 'Selecciona una categoría' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.save, color: AppColors.textPrimary),
                label: const Text('Guardar gasto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _submitExpense,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
