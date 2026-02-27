import 'package:flutter/material.dart';
import 'package:manifiestos_app/models/client.dart';
import 'package:manifiestos_app/services/supabase_service.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Client> _clients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabaseService.getClients();
      setState(() {
        _clients = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al cargar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteClient(Client client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: Text('¿Seguro que deseas eliminar a ${client.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm == true && client.id != null) {
      try {
        await _supabaseService.deleteClient(client.id!); // O client.id.toString() si en tu BD es int
        _loadClients();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  void _showClientDialog({Client? client}) {
    final nameCtrl = TextEditingController(text: client?.name ?? '');
    final domicilioCtrl = TextEditingController(text: client?.domicilio ?? '');
    final ciudadCtrl = TextEditingController(text: client?.ciudad ?? '');
    
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Evita que se cierre tocando fuera mientras guarda
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(client == null ? 'Nuevo Cliente' : 'Editar Cliente'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8, // Fija el ancho del modal
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre / Consignado A',
                        icon: Icon(Icons.business),
                      ),
                      enabled: !isSaving,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: domicilioCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Domicilio',
                        icon: Icon(Icons.location_on),
                      ),
                      enabled: !isSaving,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: ciudadCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ciudad',
                        icon: Icon(Icons.location_city),
                      ),
                      enabled: !isSaving,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (!isSaving)
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (nameCtrl.text.isEmpty) return;

                  // Activamos el estado de carga
                  setStateDialog(() {
                    isSaving = true;
                  });

                  // Creamos el objeto cliente con los datos del formulario
                  final clientData = Client(
                    id: client?.id, // Mantiene el ID si es edición
                    name: nameCtrl.text,
                    domicilio: domicilioCtrl.text,
                    ciudad: ciudadCtrl.text,
                  );

                  try {
                    if (client == null) {
                      await _supabaseService.createClient(clientData);
                    } else {
                      await _supabaseService.updateClient(clientData);
                    }
                    
                    if (mounted) _loadClients();
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    setStateDialog(() {
                      isSaving = false;
                    });
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Error al guardar: $e'))
                      );
                    }
                  }
                },
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Text('Guardar'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Directorio de Clientes'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _clients.isEmpty
              ? const Center(child: Text('No hay clientes registrados.'))
              : ListView.builder(
                  itemCount: _clients.length,
                  itemBuilder: (context, index) {
                    final c = _clients[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade50,
                          child: const Icon(Icons.business, color: Colors.teal),
                        ),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (c.domicilio.isNotEmpty) Text(c.domicilio, style: const TextStyle(fontSize: 12)),
                            if (c.ciudad.isNotEmpty) Text(c.ciudad, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Botón Editar
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showClientDialog(client: c),
                            ),
                            // Botón Eliminar
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteClient(c),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showClientDialog(), // Llama a la función sin parámetros para Crear
        child: const Icon(Icons.add),
      ),
    );
  }
}