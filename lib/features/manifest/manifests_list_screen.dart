import 'package:flutter/material.dart';
import 'package:manifiestos_app/features/manifest/manifest_form_screen.dart';
import 'package:manifiestos_app/models/manifest_data.dart';
import 'package:manifiestos_app/services/supabase_service.dart';

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
              return ListTile(
                title: Text('Manifiesto - Trailer No. ${manifest.trailerNo}'),
                subtitle: Text('Fecha: ${manifest.fecha}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ManifestFormScreen(manifest: manifest),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

