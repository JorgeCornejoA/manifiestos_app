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
  
  // Listas para manejar el buscador
  List<ManifestData> _allManifests = [];
  List<ManifestData> _foundManifests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchManifests();
  }

  // --- NUEVO: Función auxiliar para convertir tu fecha (DD-MMM-YYYY) a DateTime real ---
  DateTime _parseDate(String dateStr) {
    try {
      // Formato esperado: "12-DIC-2024"
      final parts = dateStr.split('-');
      if (parts.length != 3) return DateTime(1900); // Si está mal formada, la manda al final

      final day = int.parse(parts[0]);
      final monthStr = parts[1].toUpperCase();
      final year = int.parse(parts[2]);

      const months = {
        'ENE': 1, 'FEB': 2, 'MAR': 3, 'ABR': 4, 'MAY': 5, 'JUN': 6,
        'JUL': 7, 'AGO': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DIC': 12
      };

      final month = months[monthStr] ?? 1;
      return DateTime(year, month, day);
    } catch (e) {
      return DateTime(1900);
    }
  }

  // Función para obtener datos y ordenarlos
  Future<void> _fetchManifests() async {
    setState(() => _isLoading = true);
    // Obtenemos los datos (no importa el orden en que vengan de la BD)
    List<ManifestData> results = await _supabaseService.getManifests();
    
    // --- NUEVO: Ordenamiento manual por la fecha escrita ---
    results.sort((a, b) {
      final dateA = _parseDate(a.fecha);
      final dateB = _parseDate(b.fecha);
      // b.compareTo(a) ordena de MAYOR a MENOR (Más reciente primero)
      return dateB.compareTo(dateA); 
    });

    if (mounted) {
      setState(() {
        _allManifests = results;
        _foundManifests = results; 
        _isLoading = false;
      });
    }
  }

  // Función de filtrado (Buscador)
  void _runFilter(String enteredKeyword) {
    List<ManifestData> results = [];
    if (enteredKeyword.isEmpty) {
      results = _allManifests;
    } else {
      results = _allManifests
          .where((manifest) =>
              manifest.trailerNo.toLowerCase().contains(enteredKeyword.toLowerCase()) ||
              manifest.productor.toLowerCase().contains(enteredKeyword.toLowerCase()) ||
              manifest.destinos.any((d) => d.consignadoA.toLowerCase().contains(enteredKeyword.toLowerCase()))
          ).toList(); // <--- ¡AQUÍ ESTÁ EL PARÉNTESIS CORREGIDO!
    }

    setState(() {
      _foundManifests = results;
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
          const SnackBar(content: Text('No se pudo abrir el PDF. Verifica tu conexión.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(ManifestData manifest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Manifiesto'),
        content: Text('¿Estás seguro de eliminar el manifiesto del Trailer ${manifest.trailerNo}?'),
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
      await _supabaseService.deleteManifest(manifest.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manifiesto eliminado')),
        );
        _fetchManifests(); // Recargamos la lista
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manifiestos Guardados'),
      ),
      body: Column(
        children: [
          // --- BARRA DE BÚSQUEDA ---
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              onChanged: (value) => _runFilter(value),
              decoration: const InputDecoration(
                labelText: 'Buscar manifiesto',
                suffixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              ),
            ),
          ),
          
          // --- LISTA DE RESULTADOS ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _foundManifests.isEmpty
                    ? const Center(child: Text('No se encontraron resultados'))
                    : ListView.builder(
                        itemCount: _foundManifests.length,
                        itemBuilder: (context, index) {
                          final manifest = _foundManifests[index];
                          final hasPdf = manifest.pdfUrl != null && manifest.pdfUrl!.isNotEmpty;
                          
                          // --- NUEVA LÓGICA: Determinar Tipo ---
                          final bool isEntrada = manifest.tipo == 'EA';
                          final String prefijo = isEntrada ? 'EA' : 'T';
                          final String titulo = isEntrada ? 'Entrada Alm.:' : 'Trailer:';
                          // Color diferente en el ícono para distinguirlos más rápido visualmente
                          final Color avatarColor = isEntrada ? Colors.orange.shade100 : Colors.blue.shade100;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: avatarColor,
                                child: Text(
                                  prefijo, // Mostrará 'T' o 'EA'
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              // Mostrará 'Trailer: T-123' o 'Entrada Alm.: EA-123'
                              title: Text(
                                '$titulo $prefijo-${manifest.trailerNo}', 
                                style: const TextStyle(fontWeight: FontWeight.bold)
                              ),
                              subtitle: Text('${manifest.fecha}\n${manifest.destinos.map((d) => d.consignadoA).join(' / ')}'),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.picture_as_pdf, color: hasPdf ? Colors.blue : Colors.grey),
                                    onPressed: hasPdf ? () => _launchPDF(manifest.pdfUrl) : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.orange),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => ManifestFormScreen(manifest: manifest),
                                        ),
                                      ).then((_) => _fetchManifests());
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _confirmDelete(manifest),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}