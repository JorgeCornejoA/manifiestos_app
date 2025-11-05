import 'package:flutter/material.dart';

// Este es un ejemplo de la pantalla de clientes.
// La lógica para obtener datos de Supabase y manejar el estado (con Provider) se agregaría aquí.

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Lógica para mostrar diálogo/pantalla de "Añadir Cliente"
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 10, // Reemplazar con la lista de clientes de Supabase
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text('Nombre del Cliente ${index + 1}'),
              subtitle: Text('email_cliente_${index + 1}@example.com'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      // Lógica para editar
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      // Lógica para mostrar confirmación y eliminar
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirmar Eliminación'),
                          content: const Text('¿Estás seguro de que quieres eliminar este cliente?'),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('Cancelar'),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                            TextButton(
                              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                              onPressed: () {
                                // Llamar al servicio para eliminar
                                Navigator.of(ctx).pop();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
