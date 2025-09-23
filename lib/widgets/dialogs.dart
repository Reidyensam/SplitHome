import 'dart:async';
import 'package:flutter/material.dart';

Widget buildDeleteDialog(BuildContext context) {
  int secondsLeft = 7;
  bool enabled = false;
  late Timer timer;

  return StatefulBuilder(
    builder: (context, setState) {
      if (secondsLeft == 7) {
        timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (secondsLeft > 1) {
            setState(() => secondsLeft--);
          } else {
            t.cancel();
            setState(() {
              secondsLeft = 0;
              enabled = true;
            });
          }
        });
      }

      return AlertDialog(
        title: const Text('¿Eliminar grupo?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Esta acción no se puede deshacer.'),
            SizedBox(height: 12),
            Text('El botón eliminar se habilitará en 7 segundos...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              timer.cancel();
              Navigator.pop(context, false);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: enabled
                ? () {
                    timer.cancel();
                    Navigator.pop(context, true);
                  }
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(
              enabled ? 'Eliminar definitivamente' : 'Eliminar ($secondsLeft)',
            ),
          ),
        ],
      );
    },
  );
}