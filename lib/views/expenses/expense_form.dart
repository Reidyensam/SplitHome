import 'package:flutter/material.dart';
import 'package:splithome/core/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

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
  File? receiptImage;
  String? receiptUrl;

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
    final response = await Supabase.instance.client
        .from('categories')
        .select('id, name, icon, color')
        .order('name');

    final loadedCategories = List<Map<String, dynamic>>.from(response);

    String? initialCategoryId;
    if (widget.expense != null && widget.expense!['categories'] != null) {
      final categoryName = widget.expense!['categories']['name'];
      final match = loadedCategories.firstWhere(
        (cat) =>
            cat['name'].toString().trim().toLowerCase() ==
            categoryName.toString().trim().toLowerCase(),
        orElse: () => {},
      );
      initialCategoryId = match.isNotEmpty ? match['id'].toString() : null;
    }

    setState(() {
      categoryOptions = loadedCategories;
      selectedCategoryId = initialCategoryId;
    });
  }

  Future<void> _pickImage({required ImageSource source}) async {
    final ImagePicker picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      final originalFile = File(pickedFile.path);
      final originalSize = await originalFile.length();

      const maxSizeInBytes = 2 * 1024 * 1024;

      if (originalSize > maxSizeInBytes) {
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          pickedFile.path,
          minWidth: 1024,
          minHeight: 1024,
          quality: 70,
        );

        if (compressedBytes != null) {
          final tempPath = '${pickedFile.path}_compressed.jpg';
          final compressedFile = await File(
            tempPath,
          ).writeAsBytes(compressedBytes);
          setState(() => receiptImage = compressedFile);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo comprimir la imagen')),
          );
        }
      } else {
        setState(() => receiptImage = originalFile);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('es'),
    );

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  void _mostrarSelectorFuenteImagen() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Seleccionar desde galería'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(source: ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Tomar foto'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(source: ImageSource.camera);
            },
          ),
        ],
      ),
    );
  }

  @override
void initState() {
  super.initState();
  final expense = widget.expense;
  print('🧾 Expense recibido: $expense');

  if (expense != null) {
    print('📎 Comprobante en expense: ${expense['receipt_url']}');

    title = expense['title'] ?? '';
    amount = (expense['amount'] as num).toDouble();
    selectedDate = DateTime.parse(expense['date']);

    if (expense['receipt_url'] != null) {
      receiptUrl = Supabase.instance.client.storage
        .from('receipts')
        .getPublicUrl(expense['receipt_url']);
      print('✅ Receipt URL generada: $receiptUrl');
    }
  }

  _loadCategories();
}

  void _mostrarComprobanteZoomable(String fileName) {
    final url = Supabase.instance.client.storage
        .from('receipts')
        .getPublicUrl(fileName);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Comprobante',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 300,
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 1,
                maxScale: 4,
                child: Image.network(url),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
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

        String? fileName;
        if (receiptImage != null) {
          // Si hay comprobante anterior, eliminarlo
          if (widget.expense?['receipt_url'] != null) {
            await client.storage.from('receipts').remove([
              widget.expense!['receipt_url'],
            ]);
          }

          final imageBytes = await receiptImage!.readAsBytes();
          fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await client.storage
              .from('receipts')
              .uploadBinary(fileName, imageBytes);
          data['receipt_url'] = fileName;
        } else if (receiptUrl == null &&
            widget.expense?['receipt_url'] != null) {
          // Si el usuario eliminó el comprobante manualmente
          await client.storage.from('receipts').remove([
            widget.expense!['receipt_url'],
          ]);
          data['receipt_url'] = null;
        } else if (receiptUrl != null) {
          // Si el comprobante anterior sigue y no se modificó
          data['receipt_url'] = widget.expense!['receipt_url'];
        }

        if (widget.expense == null) {
          data['user_id'] = userId;

          final insertResponse = await client
              .from('expenses')
              .insert(data)
              .select();
          final expenseId = insertResponse.first['id'];

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gasto registrado exitosamente')),
          );
        } else {
          data['updated_by'] = userId;
          final expenseId = widget.expense!['id'];

          if (receiptImage == null && widget.expense!['receipt_url'] != null) {
            await client.storage.from('receipts').remove([
              widget.expense!['receipt_url'],
            ]);
            data['receipt_url'] = null;
          }

          await client.from('expenses').update(data).eq('id', expenseId);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gasto actualizado exitosamente')),
          );
        }

        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasReceipt = receiptUrl != null;

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
          child: ListView(
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
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: hasReceipt ? Colors.blue : Colors.grey,
                    ),
                    onPressed: hasReceipt
                        ? () => _mostrarComprobanteZoomable(
                            widget.expense!['receipt_url'],
                          )
                        : null,
                    tooltip: hasReceipt ? 'Ver comprobante' : 'Sin comprobante',
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _mostrarSelectorFuenteImagen,
                    child: const Text('Subir comprobante'),
                  ),
                  if (receiptImage != null) ...[
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Image.file(receiptImage!, fit: BoxFit.cover),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Eliminar comprobante',
                      onPressed: () => setState(() {
                        receiptImage = null;
                        receiptUrl = null;
                      }),
                    ),
                  ] else if (receiptUrl != null) ...[
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Image.network(receiptUrl!, fit: BoxFit.cover),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Eliminar comprobante',
                      onPressed: () => setState(() => receiptUrl = null),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
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
