import 'package:flutter/material.dart';
import 'package:manifiestos_app/models/company_trailer.dart';
import 'package:manifiestos_app/services/supabase_service.dart';

class CompanyTrailersScreen extends StatefulWidget {
  const CompanyTrailersScreen({super.key});

  @override
  State<CompanyTrailersScreen> createState() => _CompanyTrailersScreenState();
}

class _CompanyTrailersScreenState extends State<CompanyTrailersScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<CompanyTrailer> _trailers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrailers();
  }

  Future<void> _loadTrailers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabaseService.getCompanyTrailers();
      setState(() {
        _trailers = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTrailer(CompanyTrailer trailer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Unidad'),
        content: Text('¿Eliminar la unidad ${trailer.name}?'),
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

    if (confirm == true && trailer.id != null) {
      await _supabaseService.deleteCompanyTrailer(trailer.id!);
      _loadTrailers();
    }
  }

  // --- MODIFICADO: ACEPTA UN TRAILER PARA EDITAR ---
  void _showTrailerDialog({CompanyTrailer? trailerToEdit}) {
    final nameCtrl = TextEditingController(text: trailerToEdit?.name ?? '');
    final plateCtrl = TextEditingController(text: trailerToEdit?.plate ?? '');
    final boxCtrl = TextEditingController(text: trailerToEdit?.box ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trailerToEdit == null ? 'Nueva Unidad' : 'Editar Unidad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre / No. Económico',
                hintText: 'Ej: T-20',
                icon: Icon(Icons.local_shipping)
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: plateCtrl,
              decoration: const InputDecoration(
                labelText: 'Placas',
                hintText: 'Ej: SON-998',
                icon: Icon(Icons.confirmation_number)
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: boxCtrl,
              decoration: const InputDecoration(
                labelText: 'Tipo de Caja / No. Caja',
                hintText: 'Ej: 53 PIES / C-10',
                icon: Icon(Icons.check_box_outline_blank)
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;

              final trailerData = CompanyTrailer(
                id: trailerToEdit?.id, // Conservar ID si es edición
                name: nameCtrl.text,
                plate: plateCtrl.text,
                box: boxCtrl.text,
              );

              if (trailerToEdit == null) {
                // CREAR
                await _supabaseService.createCompanyTrailer(trailerData);
              } else {
                // ACTUALIZAR (EDITAR)
                await _supabaseService.updateCompanyTrailer(trailerData);
              }

              if (mounted) _loadTrailers();
              if (context.mounted) Navigator.pop(ctx);
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
      appBar: AppBar(title: const Text('Flotilla Local')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trailers.isEmpty
              ? const Center(child: Text('No hay unidades registradas.'))
              : ListView.builder(
                  itemCount: _trailers.length,
                  itemBuilder: (context, index) {
                    final t = _trailers[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.local_shipping),
                      ),
                      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Placas: ${t.plate} • Caja: ${t.box}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // --- BOTÓN EDITAR ---
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showTrailerDialog(trailerToEdit: t),
                          ),
                          // --- BOTÓN ELIMINAR ---
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTrailer(t),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTrailerDialog(), // Nuevo sin argumentos
        child: const Icon(Icons.add),
      ),
    );
  }
}