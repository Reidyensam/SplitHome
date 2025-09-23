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

  final Map<String, IconData> iconMap = {
    'school': Icons.school,
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'sports_esports': Icons.sports_esports,
    'local_hospital': Icons.local_hospital,
    'category': Icons.category,
    'services': Icons.miscellaneous_services,
  };

  Color hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<void> _loadCategories() async {

  try {
    final response = await Supabase.instance.client
        .from('categories')
        .select('id, name, icon, color')
        .order('name');

    debugPrint('📦 Categorías cargadas desde Supabase: $response');

    final loadedCategories = List<Map<String, dynamic>>.from(response);

    debugPrint('🔍 Nombres en categorías cargadas: ${loadedCategories.map((c) => c['name']).toList()}');

    String? initialCategoryId;

    if (widget.expense != null && widget.expense!['categories'] != null) {
      final categoryName = widget.expense!['categories']['name'];
Map<String, dynamic>? match;
try {
  match = loadedCategories.firstWhere(
    (cat) => cat['name'].toString().trim().toLowerCase() == categoryName.toString().trim().toLowerCase(),
  );
} catch (_) {
  match = null;
}
initialCategoryId = match?['id']?.toString();

      debugPrint('🔍 Nombre de categoría recibido: $categoryName');
      debugPrint('🔍 ID encontrado: $initialCategoryId');
    }

    setState(() {
      categoryOptions = loadedCategories;
      selectedCategoryId = initialCategoryId;
    });

    debugPrint('🧠 Categoría seleccionada: $selectedCategoryId');
    debugPrint('¿Existe en opciones? ${categoryOptions.any((cat) => cat['id'].toString() == selectedCategoryId) ? "Sí" : "No"}');
  } catch (error) {
    debugPrint('❌ Error en _loadCategories: $error');
  }
}

  Future<void> _submitExpense() async {
    if (_formKey.currentState!.validate()) {
      if (selectedCategoryId == null || selectedCategoryId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una categoría')),
        );
        return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      final client = Supabase.instance.client;

      if (userId != null) {
        final data = {
          'title': title,
          'amount': amount,
          'date': selectedDate.toIso8601String(),
          'category_id': selectedCategoryId,
          'group_id': widget.groupId,
        };

        if (widget.expense == null) {
          data['user_id'] = userId;
        } else {
          data['updated_by'] = userId;
        }

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
  debugPrint('🚀 Ejecutando _loadCategories');
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
                  debugPrint(
                    '🔍 Opciones disponibles: ${categoryOptions.map((c) => c['id']).toList()}',
                  );
                  return DropdownMenuItem(
                    value: cat['id'].toString(),
                    child: Row(
                      children: [
                        Icon(
                          iconMap[cat['icon']] ?? Icons.help_outline,
                          size: 20,
                          color: cat['color'] != null
                              ? hexToColor(cat['color'])
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(cat['name']),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => selectedCategoryId = value),
                decoration: const InputDecoration(labelText: 'Categoría'),
                validator: (value) =>
                    value == null ? 'Selecciona una categoría' : null,
              ),
              if (selectedCategoryId != null)
                Builder(
                  builder: (context) {
                    final selectedCat = categoryOptions.firstWhere(
                      (cat) => cat['id'].toString() == selectedCategoryId,
                      orElse: () => {},
                    );
                    if (selectedCat.isEmpty) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            iconMap[selectedCat['icon']] ?? Icons.help_outline,
                            color: selectedCat['color'] != null
                                ? hexToColor(selectedCat['color'])
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedCat['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
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
