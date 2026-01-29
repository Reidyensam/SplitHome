import 'package:flutter/material.dart';
import 'package:splithome/core/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

Future<void> notifyGroupExpense({
  required String actorId,
  required String actorName,
  required String groupId,
  required String groupName,
  required String expenseName,
  required String type, // 'expense_add' o 'expense_edit'
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
      'created_at': DateTime.now().toIso8601String(),
      'read': false,
    });
  }
}

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

  @override
  void initState() {
    super.initState();
    _loadCategories();

    title = widget.expense?['title'] ?? '';
    amount = widget.expense?['amount']?.toDouble() ?? 0.0;
    selectedDate = widget.expense?['date'] != null
        ? DateTime.parse(widget.expense!['date'])
        : DateTime.now();
    selectedCategoryId = widget.expense?['category_id']?.toString();

    receiptUrl = widget.expense?['receipt_url'];
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
    final picker = ImagePicker();
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

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: usuario no autenticado')),
      );
      return;
    }

    final data = {
      'title': title,
      'amount': amount,
      // 🔧 Ajuste: eliminamos fracciones de segundo
      'date': selectedDate.toIso8601String().split('.').first,
      'category_id': selectedCategoryId,
      'group_id': widget.groupId,
    };

    if (widget.expense == null) {
      data['user_id'] = currentUserId;
    }

    // 🗑️ Eliminar comprobante anterior si fue quitado manualmente
    if (widget.expense != null &&
        widget.expense!['receipt_url'] != null &&
        receiptUrl == null &&
        receiptImage == null) {
      await Supabase.instance.client.storage.from('receipts').remove([
        widget.expense!['receipt_url'],
      ]);
    }

    if (receiptImage != null) {
      final imageBytes = await receiptImage!.readAsBytes();
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage
          .from('receipts')
          .uploadBinary(fileName, imageBytes);

      data['receipt_url'] = fileName;
    } else if (receiptUrl != null) {
      data['receipt_url'] = receiptUrl;
    } else {
      data['receipt_url'] = null;
    }

    try {
      debugPrint('📤 Enviando gasto con datos: $data');
      debugPrint('📅 Fecha enviada: ${data['date']}');

      final currentUserName =
          Supabase.instance.client.auth.currentUser?.userMetadata?['name'] ??
          'Alguien';
      final groupResponse = await Supabase.instance.client
          .from('groups')
          .select('name')
          .eq('id', widget.groupId)
          .single();
      final groupName = groupResponse['name'] ?? 'Grupo desconocido';

      if (widget.expense != null) {
        final originalUserId = widget.expense!['user_id'];
        if (originalUserId != null) {
          data['user_id'] = originalUserId;
        }

        data['updated_by'] = currentUserId;

        await Supabase.instance.client
            .from('expenses')
            .update(data)
            .eq('id', widget.expense!['id']);

        await notifyGroupExpense(
          actorId: currentUserId,
          actorName: currentUserName,
          groupId: widget.groupId,
          groupName: groupName,
          expenseName: title,
          type: 'expense_edit',
        );
      } else {
        await Supabase.instance.client.from('expenses').insert(data);

        await notifyGroupExpense(
          actorId: currentUserId,
          actorName: currentUserName,
          groupId: widget.groupId,
          groupName: groupName,
          expenseName: title,
          type: 'expense_add',
        );
      }

      if (context.mounted) Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('❌ Error al guardar gasto: $error');
      debugPrint('🪵 StackTrace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al guardar: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );

      if (picked != null && picked != selectedDate) {
        setState(() {
          selectedDate = picked;
        });
        debugPrint(
          '📅 Nueva fecha seleccionada: ${selectedDate.toIso8601String()}',
        );
      } else {
        debugPrint('⚠️ Selección de fecha cancelada o sin cambios');
      }
    } catch (e, st) {
      debugPrint('❌ Error al abrir selector de fecha: $e');
      debugPrint('🪵 StackTrace: $st');
    }
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

  @override
  Widget build(BuildContext context) {
    debugPrint('📷 receiptImage: $receiptImage');
    debugPrint('🌐 receiptUrl: $receiptUrl');

    final tieneComprobante = receiptUrl != null || receiptImage != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.expense != null ? 'Editar Gasto' : 'Registrar Gasto',
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
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    title = value[0].toUpperCase() + value.substring(1);
                  } else {
                    title = value;
                  }
                  setState(() {});
                },
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
                    style: const TextStyle(fontSize: 16),
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
                      color: tieneComprobante ? Colors.blue : Colors.grey,
                    ),
                    onPressed: tieneComprobante
                        ? () {
                            if (receiptImage != null) {
                              showDialog(
                                context: context,
                                builder: (_) =>
                                    Dialog(child: Image.file(receiptImage!)),
                              );
                            } else if (receiptUrl != null) {
                              _mostrarComprobanteZoomable(receiptUrl!);
                            }
                          }
                        : null,
                    tooltip: tieneComprobante
                        ? 'Ver comprobante'
                        : 'Sin comprobante',
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
                      child: Image.network(
                        Supabase.instance.client.storage
                            .from('receipts')
                            .getPublicUrl(receiptUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Eliminar comprobante',
                      onPressed: () async {
                        if (receiptUrl != null) {
                          await Supabase.instance.client.storage
                              .from('receipts')
                              .remove([receiptUrl!]);
                        }
                        setState(() => receiptUrl = null);
                      },
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
