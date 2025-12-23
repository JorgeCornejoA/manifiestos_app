import 'dart:typed_data';
import 'package:manifiestos_app/models/manifest_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manifiestos_app/models/client.dart';
import 'package:manifiestos_app/models/operator.dart';
import 'package:uuid/uuid.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  Future<String?> saveManifest(ManifestData data) async {
    try {
      final manifestId = data.id ?? _uuid.v4();

      String? embarcoFirmaUrl = data.embarcoFirmaUrl;
      String? recibioFirmaUrl = data.recibioFirmaUrl;
      
      // --- NUEVO: Lógica para Fotos de Evidencia ---
      // 1. Iniciamos con las URLs que ya existían
      List<String> finalPhotoUrls = List.from(data.evidencePhotosUrls ?? []);

      // 2. Si hay fotos nuevas (bytes), las subimos una por una
      if (data.evidencePhotosBytes != null && data.evidencePhotosBytes!.isNotEmpty) {
        // NOTA: Para simplificar, en este ejemplo asumimos que "bytes" contiene SOLO las nuevas.
        // En la práctica real del formulario, combinaremos todo.
        
        // Pero espera, tu UI mandará TODAS las fotos (viejas descargadas + nuevas) como bytes para el PDF.
        // Para la BD, lo ideal es subir las nuevas. 
        // TRUCO: Vamos a subir todas las que vengan en bytes y reemplazar la lista. 
        // Es un poco ineficiente re-subir, pero es lo más seguro para evitar conflictos de índices ahora.
        
        finalPhotoUrls.clear(); // Limpiamos para reconstruir la lista con las fotos actuales
        
        for (int i = 0; i < data.evidencePhotosBytes!.length; i++) {
          final bytes = data.evidencePhotosBytes![i];
          // Usamos un nombre único para cada foto
          final uniqueName = '${_uuid.v4()}.png'; 
          final path = 'evidence/$manifestId/$uniqueName';
          
          await _supabase.storage.from('manifests').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
          
          final url = _supabase.storage.from('manifests').getPublicUrl(path);
          finalPhotoUrls.add(url);
        }
      }
      // ---------------------------------------------

      // ... (Lógica de firmas existente igual) ...
      if (data.embarcoFirmaBytes != null && data.embarcoFirmaBytes!.isNotEmpty) {
         // ... tu código de siempre ...
      }
      if (data.recibioFirmaBytes != null && data.recibioFirmaBytes!.isNotEmpty) {
         // ... tu código de siempre ...
      }

      final manifestMap = data.toMap();
      manifestMap['embarco_firma_url'] = embarcoFirmaUrl;
      manifestMap['recibio_firma_url'] = recibioFirmaUrl;
      
      // --- GUARDAR LISTA DE FOTOS ---
      manifestMap['evidence_photos_urls'] = finalPhotoUrls;

      manifestMap.remove('pdf_url');

      // ... Insert o Update igual ...
      final id = data.id;
      if (id == null) {
        manifestMap['id'] = manifestId;
        await _supabase.from('manifests').insert(manifestMap);
      } else {
        await _supabase.from('manifests').update(manifestMap).eq('id', id);
      }
      return manifestId;
    } catch (e) {
      print('Error en saveManifest: $e');
      return null;
    }
  }

  // --- (El resto de tu archivo sigue exactamente igual) ---
  Future<void> deleteManifest(String id) async {
    try {
      await _supabase.from('manifests').delete().eq('id', id);
    } catch (e) {
      print('Error al eliminar manifiesto: $e');
      throw Exception('No se pudo eliminar el manifiesto: $e');
    }
  }

  // En supabase_service.dart

  Future<List<ManifestData>> getManifests() async {
    try {
      // MODIFICACIÓN: Agregamos .order para ordenar del más nuevo al más viejo
      final response = await _supabase
          .from('manifests')
          .select()
          .order('created_at', ascending: false); 
          
      final manifests = (response as List<dynamic>)
          .map((data) => ManifestData.fromMap(data as Map<String, dynamic>))
          .toList();
      return manifests;
    } catch (e) {
      // ignore: avoid_print
      print('Error en getManifests: $e');
      return [];
    }
  }
  
  Future<String?> uploadPdf(Uint8List pdfBytes, String fileName) async {
    try {
      final path = 'pdfs/$fileName';
      await _supabase.storage.from('manifests').uploadBinary(
            path,
            pdfBytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return _supabase.storage.from('manifests').getPublicUrl(path);
    } catch (e) {
      print('Error al subir PDF: $e');
      return null;
    }
  }

  Future<void> updatePdfUrl(String manifestId, String pdfUrl) async {
    try {
      await _supabase
          .from('manifests')
          .update({'pdf_url': pdfUrl})
          .eq('id', manifestId);
    } catch (e) {
      print('Error al actualizar PDF URL: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchClients(String query) async {
    try {
      final response = await _supabase
          .from('clients')
          .select()
          .ilike('name', '%$query%');
      return response;
    } catch (e) {
      print('Error en searchClients: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchOperators(String query) async {
    try {
      final response = await _supabase
          .from('operators')
          .select()
          .ilike('name', '%$query%');
      return response;
    } catch (e) {
      print('Error en searchOperators: $e');
      return [];
    }
  }

  Future<List<Client>> getClients() async {
    try {
      final response = await _supabase
          .from('clients')
          .select()
          .order('name', ascending: true);
      return response.map((map) => Client.fromMap(map)).toList();
    } catch (e) {
      print('Error en getClients: $e');
      return [];
    }
  }

  Future<void> createClient(Client client) async {
    try {
      final map = client.toMap()..remove('id'); 
      await _supabase.from('clients').insert(map);
    } catch (e) {
      print('Error en createClient: $e');
      throw Exception('Error al crear cliente: $e');
    }
  }

  Future<void> updateClient(Client client) async {
    try {
      if (client.id == null) {
        throw Exception('No se puede actualizar un cliente sin ID');
      }
      await _supabase
          .from('clients')
          .update(client.toMap())
          .eq('id', client.id!);
    } catch (e) {
      print('Error en updateClient: $e');
      throw Exception('Error al actualizar cliente: $e');
    }
  }

  Future<void> deleteClient(String id) async {
    try {
      await _supabase.from('clients').delete().eq('id', id);
    } catch (e) {
      print('Error en deleteClient: $e');
      throw Exception('Error al eliminar cliente: $e');
    }
  }

  Future<List<Operator>> getOperators() async {
    try {
      final response = await _supabase
          .from('operators')
          .select()
          .order('name', ascending: true);
      return response.map((map) => Operator.fromMap(map)).toList();
    } catch (e) {
      print('Error en getOperators: $e');
      return [];
    }
  }

  Future<void> createOperator(Operator operator) async {
    try {
      final map = operator.toMap()..remove('id');
      await _supabase.from('operators').insert(map);
    } catch (e) {
      print('Error en createOperator: $e');
      throw Exception('Error al crear operador: $e');
    }
  }

  Future<void> updateOperator(Operator operator) async {
    try {
      if (operator.id == null) throw Exception('ID requerido');
      await _supabase
          .from('operators')
          .update(operator.toMap())
          .eq('id', operator.id!);
    } catch (e) {
      print('Error en updateOperator: $e');
      throw Exception('Error al actualizar operador: $e');
    }
  }

  Future<void> deleteOperator(String id) async {
    try {
      await _supabase.from('operators').delete().eq('id', id);
    } catch (e) {
      print('Error en deleteOperator: $e');
      throw Exception('Error al eliminar operador: $e');
    }
  }
}