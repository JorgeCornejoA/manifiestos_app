import 'package:flutter/material.dart';
import 'package:manifiestos_app/features/manifest/manifest_form_screen.dart';
import 'package:manifiestos_app/models/manifest_data.dart';
import 'package:manifiestos_app/services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ManifestsListScreen extends StatefulWidget {
  const ManifestsListScreen({super.key});

  @override
  State<ManifestsListScreen> createState() => _ManifestsListScreenState();
}

class _ManifestsListScreenState extends State<ManifestsListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  late Future<List<ManifestData>> _manifestsFuture;

  @override
  void initState() {
    super.initState();
    _refreshManifests();
  }

  // Función para recargar la lista
  void _refreshManifests() {
    setState(() {
      _manifestsFuture = _supabaseService.getManifests();
    });
  }

  Future<void> _launchPDF(String? pdfUrl) async {
    if (pdfUrl == null || pdfUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este manifiesto no tiene un PDF guardado.')),
      );
      return;
    }

    try {
      final uri = Uri.parse(pdfUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $uri');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el PDF. Verifica tu conexión o instala un visor de PDF.')),
        );
      }
    }
  }

  // --- NUEVO: Función para confirmar y eliminar ---
  Future<void> _confirmDelete(ManifestData manifest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Manifiesto'),
        content: Text('¿Estás seguro de que deseas eliminar el manifiesto del Trailer ${manifest.trailerNo}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && manifest.id != null) {
      try {
        await _supabaseService.deleteManifest(manifest.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Manifiesto eliminado con éxito')),
          );
          _refreshManifests(); // Recargamos la lista
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manifiestos Guardados'),
      ),
      body: FutureBuilder<List<ManifestData>>(
        future: _manifestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay manifiestos guardados.'));
          }

          final manifests = snapshot.data!;
          return ListView.builder(
            itemCount: manifests.length,
            itemBuilder: (context, index) {
              final manifest = manifests[index];
              final hasPdf = manifest.pdfUrl != null && manifest.pdfUrl!.isNotEmpty;
              
              return ListTile(
                title: Text('Manifiesto - Trailer No. ${manifest.trailerNo}'),
                subtitle: Text('Fecha: ${manifest.fecha}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ManifestFormScreen(manifest: manifest),
                    ),
                  ).then((_) => _refreshManifests());
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botón PDF
                    IconButton(
                      icon: Icon(
                        Icons.picture_as_pdf,
                        color: hasPdf ? Colors.blue : Colors.grey,
                      ),
                      tooltip: 'Ver PDF',
                      onPressed: hasPdf ? () => _launchPDF(manifest.pdfUrl) : null,
                    ),
                    
                    // Botón Editar
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      tooltip: 'Editar',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ManifestFormScreen(manifest: manifest),
                          ),
                        ).then((_) => _refreshManifests());
                      },
                    ),

                    // --- NUEVO: Botón Eliminar ---
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Eliminar',
                      onPressed: () => _confirmDelete(manifest),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}