import 'package:flutter/material.dart';
import 'package:manifiestos_app/models/producer.dart';
import 'package:manifiestos_app/services/supabase_service.dart';

class ProducersScreen extends StatefulWidget {
  const ProducersScreen({super.key});

  @override
  State<ProducersScreen> createState() => _ProducersScreenState();
}

class _ProducersScreenState extends State<ProducersScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Producer> _producers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducers();
  }

  Future<void> _loadProducers() async {
    setState(() => _isLoading = true);
    try {
      // getProducers devuelve List<Map<String, dynamic>>, lo mapeamos a nuestro modelo
      final data = await _supabaseService.getProducers();
      setState(() {
        _producers = data.map((map) => Producer.fromMap(map)).toList();
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

  Future<void> _deleteProducer(Producer producer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Productor'),
        content: Text('¿Seguro que deseas eliminar a ${producer.name}?'),
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

    if (confirm == true && producer.id != null) {
      try {
        await _supabaseService.deleteProducer(producer.id!); // Pasamos el ID int
        _loadProducers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  void _showProducerDialog({Producer? producer}) {
    final nameCtrl = TextEditingController(text: producer?.name ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Evita que se cierre tocando fuera mientras guarda
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(producer == null ? 'Nuevo Productor' : 'Editar Productor'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8, // Fija el ancho del modal
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Productor',
                        icon: Icon(Icons.agriculture),
                      ),
                      enabled: !isSaving,
                      textCapitalization: TextCapitalization.words,
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
                  if (nameCtrl.text.trim().isEmpty) return;

                  setStateDialog(() {
                    isSaving = true;
                  });

                  try {
                    if (producer == null) {
                      // CREAR
                      await _supabaseService.saveProducer(nameCtrl.text.trim());
                    } else {
                      // EDITAR
                      await _supabaseService.updateProducer(producer.id!, nameCtrl.text.trim());
                    }
                    
                    if (mounted) _loadProducers();
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
        title: const Text('Directorio de Productores'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _producers.isEmpty
              ? const Center(child: Text('No hay productores registrados.'))
              : ListView.builder(
                  itemCount: _producers.length,
                  itemBuilder: (context, index) {
                    final p = _producers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.lightGreen.shade50,
                          child: const Icon(Icons.grass, color: Colors.lightGreen),
                        ),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Botón Editar
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showProducerDialog(producer: p),
                            ),
                            // Botón Eliminar
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteProducer(p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProducerDialog(), // Sin parámetros para crear nuevo
        child: const Icon(Icons.add),
      ),
    );
  }
}