import 'package:flutter/material.dart';
import 'package:manifiestos_app/features/manifest/manifest_form_screen.dart';
import 'package:manifiestos_app/models/manifest_data.dart';
import 'package:manifiestos_app/services/supabase_service.dart';
// MODIFICACIÓN: Se importa url_launcher
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
    _manifestsFuture = _supabaseService.getManifests();
  }

  // MODIFICACIÓN: Nueva función para abrir la URL del PDF
  Future<void> _launchPDF(String? pdfUrl) async {
    if (pdfUrl == null || pdfUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este manifiesto no tiene un PDF guardado.')),
      );
      return;
    }
    
    final uri = Uri.parse(pdfUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el PDF: $pdfUrl')),
      );
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
                // MODIFICACIÓN: Se cambia el onTap por un botón de editar
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ManifestFormScreen(manifest: manifest),
                    ),
                  ).then((_) {
                    // Actualiza la lista cuando regresa
                    setState(() {
                      _manifestsFuture = _supabaseService.getManifests();
                    });
                  });
                },
                // MODIFICACIÓN: Se añade el icono de PDF
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.picture_as_pdf,
                        color: hasPdf ? Colors.blue : Colors.grey,
                      ),
                      tooltip: 'Ver PDF',
                      onPressed: hasPdf ? () => _launchPDF(manifest.pdfUrl) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      tooltip: 'Editar Manifiesto',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ManifestFormScreen(manifest: manifest),
                          ),
                        ).then((_) {
                          // Actualiza la lista cuando regresa
                          setState(() {
                            _manifestsFuture = _supabaseService.getManifests();
                          });
                        });
                      },
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