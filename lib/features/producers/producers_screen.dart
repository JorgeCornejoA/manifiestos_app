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
      final data = await _supabaseService.getProducers();
      setState(() {
        _producers = data.map((e) => Producer.fromMap(e)).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addProducer() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Productor'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nombre del Productor'),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _supabaseService.saveProducer(controller.text.toUpperCase());
                Navigator.pop(context);
                _loadProducers();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productores')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _producers.length,
              itemBuilder: (context, index) {
                final producer = _producers[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.agriculture)),
                  title: Text(producer.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () async {
                      if (producer.id != null) {
                        await _supabaseService.deleteProducer(producer.id!);
                        _loadProducers();
                      }
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProducer,
        child: const Icon(Icons.add),
      ),
    );
  }
}