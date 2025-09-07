import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';

class EditExpensePage extends StatefulWidget {
  final String expenseId;

  const EditExpensePage({super.key, required this.expenseId});

  @override
  State<EditExpensePage> createState() => _EditExpensePageState();
}

class _EditExpensePageState extends State<EditExpensePage> {
  final _formKey = GlobalKey<FormState>();
  String title = '';
  double amount = 0.0;
  String? categoryId;
  DateTime date = DateTime.now();
  bool isOwnerOrAdmin = false;
  bool isLoading = true;
  List<Map<String, dynamic>> categoryOptions = [];
  bool isOwnExpense = false;
  bool editedByAdmin = false;
  String? creatorName;
  String? editorName;

  @override
  void initState() {
    super.initState();
    _loadCategories().then((_) => _loadExpense());
  }

  Future<void> _loadExpense() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final expense = await Supabase.instance.client
        .from('expenses')
        .select('title, amount, category_id, date, user_id, group_id')
        .eq('id', widget.expenseId)
        .single();

    final creatorId = expense['user_id'];

    final groupAdmin = await Supabase.instance.client
        .from('group_members')
        .select('role')
        .eq('group_id', expense['group_id'])
        .eq('user_id', userId)
        .single();

    final isAdmin = groupAdmin['role'] == 'admin';

    final creator = await Supabase.instance.client
        .from('users')
        .select('name')
        .eq('id', creatorId)
        .single();

    final editor = await Supabase.instance.client
        .from('users')
        .select('name')
        .eq('id', userId)
        .single();

    setState(() {
      title = expense['title'];
      amount = double.tryParse(expense['amount'].toString()) ?? 0.0;
      categoryId = expense['category_id']?.toString();
      date = DateTime.parse(expense['date']);
      isOwnerOrAdmin = (creatorId == userId) || isAdmin;
      isOwnExpense = creatorId == userId;
      editedByAdmin = (creatorId != userId) && isAdmin;
      creatorName = creator['name'];
      editorName = editor['name'];
      isLoading = false;
    });
    print('🧾 Autor: $creatorName');
    print('🧾 Editor: $editorName');
    print('🛡️ ¿Editado por admin?: $editedByAdmin');
  }

  Future<void> _loadCategories() async {
    final response = await Supabase.instance.client
        .from('categories')
        .select('id, name')
        .order('name');

    setState(() {
      categoryOptions = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _updateExpense() async {
    if (_formKey.currentState!.validate()) {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      final updateData = {
        'title': title,
        'amount': amount,
        'category_id': categoryId,
        'date': date.toIso8601String(),
        'updated_by': userId,
      };

      updateData.remove('user_id');

      await Supabase.instance.client
          .from('expenses')
          .update(updateData)
          .eq('id', widget.expenseId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gasto actualizado'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!isOwnerOrAdmin && !(editedByAdmin && title.isNotEmpty && amount > 0)) {
      return Scaffold(
        body: Center(
          child: Text(
            'No tienes permiso para editar este gasto',
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Editar gasto'),
            if (editedByAdmin)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.shield, color: AppColors.primary),
              ),
          ],
        ),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$creatorName ',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      if (editedByAdmin)
                        WidgetSpan(
                          child: Icon(
                            Icons.shield,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          alignment: PlaceholderAlignment.middle,
                        ),
                      TextSpan(
                        text: '  Modificado por: $editorName',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$creatorName ',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      WidgetSpan(
                        child: Icon(
                          Icons.shield,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        alignment: PlaceholderAlignment.middle,
                      ),
                      TextSpan(
                        text: '  Modificado por: $editorName',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
              TextFormField(
                initialValue: title,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa un título' : null,
                onChanged: (value) => title = value,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: amount.toString(),
                decoration: const InputDecoration(labelText: 'Monto'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa un monto' : null,
                onChanged: (value) => amount = double.tryParse(value) ?? amount,
              ),
              const SizedBox(height: 16),
              categoryOptions.isEmpty
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<String>(
                      value: categoryId, // 👈 Este valor viene precargado
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: categoryOptions.map((cat) {
                        return DropdownMenuItem(
                          value: cat['id'].toString(),
                          child: Text(cat['name']),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => categoryId = value),
                      validator: (value) =>
                          value == null ? 'Selecciona una categoría' : null,
                    ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.save, color: AppColors.textPrimary),
                label: const Text('Guardar cambios'),
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
                onPressed: _updateExpense,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
