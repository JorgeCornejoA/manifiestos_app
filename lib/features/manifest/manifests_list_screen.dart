import 'package:flutter/material.dart';
import 'package:manifiestos_app/features/manifest/manifest_form_screen.dart';
import 'package:manifiestos_app/models/manifest_data.dart';
import 'package:manifiestos_app/services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http; // <--- NUEVO IMPORT PARA DESCARGAR
import 'package:share_plus/share_plus.dart'; // <--- NUEVO IMPORT PARA COMPARTIR

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
  
  // Variable para saber si el usuario es de solo lectura
  bool _isReadOnlyUser = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions(); // Verificamos permisos antes de cargar
    _fetchManifests();
  }

  // Función para consultar los permisos del empleado logueado
  Future<void> _checkPermissions() async {
    final usuarioActual = await _supabaseService.getCurrentEmployee();
    if (mounted) {
      setState(() {
        _isReadOnlyUser = usuarioActual?.soloLectura ?? false;
      });
    }
  }

  // Función auxiliar para convertir tu fecha (DD-MMM-YYYY) a DateTime real
  DateTime _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return DateTime(1900); 

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
    List<ManifestData> results = await _supabaseService.getManifests();
    
    // Ordenamiento manual por la fecha escrita
    results.sort((a, b) {
      final dateA = _parseDate(a.fecha);
      final dateB = _parseDate(b.fecha);
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
          ).toList(); 
    }

    setState(() {
      _foundManifests = results;
    });
  }

  // --- FUNCIÓN PARA VER EL PDF ---
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

  // --- NUEVA FUNCIÓN PARA COMPARTIR EL ARCHIVO FÍSICO ---
  Future<void> _sharePDF(String? pdfUrl, String trailerNo) async {
    if (pdfUrl == null || pdfUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este manifiesto no tiene un PDF guardado.')),
      );
      return;
    }

    try {
      // 1. Avisamos que se está descargando
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparando archivo para compartir...')),
      );

      // 2. Descargamos los datos del PDF en memoria
      final response = await http.get(Uri.parse(pdfUrl));
      final bytes = response.bodyBytes;

      // 3. Empaquetamos el archivo
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: 'Manifiesto_$trailerNo.pdf', // Nombre del adjunto
      );

      // 4. Compartimos usando el método actualizado
      await Share.shareXFiles(
        [xfile],
        text: 'Adjunto manifiesto del trailer $trailerNo',
      );
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al preparar el archivo para compartir.')),
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
                          
                          // Lógica: Determinar Tipo
                          final bool isEntrada = manifest.tipo == 'EA';
                          final String prefijo = isEntrada ? 'EA' : 'T';
                          final String titulo = isEntrada ? 'Entrada Alm.:' : 'Trailer:';
                          final Color avatarColor = isEntrada ? Colors.orange.shade100 : Colors.blue.shade100;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            elevation: 2,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // --- PARTE SUPERIOR: INFORMACIÓN ---
                                ListTile(
                                  contentPadding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: avatarColor,
                                    child: Text(
                                      prefijo, 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  title: Text(
                                    '$titulo $prefijo-${manifest.trailerNo}', 
                                    style: const TextStyle(fontWeight: FontWeight.bold)
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      '${manifest.fecha}\n${manifest.destinos.map((d) => d.consignadoA).join(' / ')}',
                                      style: const TextStyle(height: 1.3),
                                    ),
                                  ),
                                ),
                                
                                // --- PARTE INFERIOR: BARRA DE BOTONES ---
                                Padding(
                                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Botón 1: VER (Ojo)
                                      IconButton(
                                        icon: Icon(Icons.remove_red_eye, color: hasPdf ? Colors.blue : Colors.grey),
                                        onPressed: hasPdf ? () => _launchPDF(manifest.pdfUrl) : null,
                                        tooltip: 'Ver PDF',
                                      ),
                                      
                                      // Botón 2: COMPARTIR FÍSICO (Share verde)
                                      IconButton(
                                        icon: Icon(Icons.share, color: hasPdf ? Colors.green : Colors.grey),
                                        onPressed: hasPdf ? () => _sharePDF(manifest.pdfUrl, manifest.trailerNo) : null,
                                        tooltip: 'Compartir',
                                      ),
                                      
                                      // Botones 3 y 4: Ocultos si es Solo Lectura
                                      if (!_isReadOnlyUser) ...[
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.orange),
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) => ManifestFormScreen(manifest: manifest),
                                              ),
                                            ).then((_) => _fetchManifests());
                                          },
                                          tooltip: 'Editar',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _confirmDelete(manifest),
                                          tooltip: 'Eliminar',
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
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