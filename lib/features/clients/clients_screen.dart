// lib/features/clients/clients_screen.dart
import 'package:flutter/material.dart';
import 'package:manifiestos_app/models/client.dart';
import 'package:manifiestos_app/services/supabase_service.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _supabaseService = SupabaseService();
  late Future<List<Client>> _clientsFuture;

  @override
  void initState() {
    super.initState();
    _refreshClients();
  }

  /// Carga o recarga la lista de clientes
  void _refreshClients() {
    setState(() {
      _clientsFuture = _supabaseService.getClients();
    });
  }

  /// Navega al formulario para crear o editar un cliente
  Future<void> _navigateToForm([Client? client]) async {
    // Navegamos al formulario y esperamos a que regrese (con pop)
    await Navigator.of(context).pushNamed(
      '/client-form',
      arguments: client, // Pasamos el cliente como argumento
    );
    // Cuando regrese, recargamos la lista
    _refreshClients();
  }

  /// Muestra un diálogo de confirmación para eliminar
  Future<void> _deleteClient(Client client) async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que deseas eliminar a ${client.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true && client.id != null) {
      try {
        await _supabaseService.deleteClient(client.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${client.name} eliminado')),
        );
        _refreshClients();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Clientes'),
      ),
      body: FutureBuilder<List<Client>>(
        future: _clientsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final clients = snapshot.data;
          if (clients == null || clients.isEmpty) {
            return const Center(
              child: Text('No hay clientes. Añade uno con el botón "+".'),
            );
          }

          return ListView.builder(
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              return ListTile(
                title: Text(client.name),
                subtitle: Text(client.domicilio.isNotEmpty
                    ? client.domicilio
                    : 'Sin domicilio'),
                onTap: () => _navigateToForm(client), // Editar
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteClient(client), // Eliminar
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(), // Crear nuevo
        child: const Icon(Icons.add),
        tooltip: 'Añadir Cliente',
      ),
    );
  }
}