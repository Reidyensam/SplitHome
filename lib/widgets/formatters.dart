import 'package:intl/intl.dart';

String formatearFecha(String isoDate, {String? updatedIso}) {
  try {
    final created = DateTime.parse(isoDate).toLocal();
    final updated = updatedIso != null ? DateTime.tryParse(updatedIso)?.toLocal() : null;
    final fecha = DateFormat('dd/MM/yyyy – HH:mm').format(created);
    final editado = updated != null && updated.isAfter(created) ? ' (editado)' : '';
    return '$fecha$editado';
  } catch (e) {
    return 'Fecha inválida';
  }
}