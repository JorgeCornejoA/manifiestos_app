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

      // --- CORRECCIÓN: Inicializar con la URL existente ---
      // Antes estaba en null, por eso borraba la firma si no la cambiabas.
      String? embarcoFirmaUrl = data.embarcoFirmaUrl;
      String? recibioFirmaUrl = data.recibioFirmaUrl;

      // Solo si hay bytes NUEVOS, subimos y actualizamos la URL
      if (data.embarcoFirmaBytes != null && data.embarcoFirmaBytes!.isNotEmpty) {
        final path = 'signatures/$manifestId/embarco_firma.png';
        await _supabase.storage.from('manifests').uploadBinary(
              path,
              data.embarcoFirmaBytes!,
              fileOptions: const FileOptions(upsert: true),
            );
        embarcoFirmaUrl = _supabase.storage.from('manifests').getPublicUrl(path);
      }
      
      if (data.recibioFirmaBytes != null && data.recibioFirmaBytes!.isNotEmpty) {
        final path = 'signatures/$manifestId/recibio_firma.png';
        await _supabase.storage.from('manifests').uploadBinary(
              path,
              data.recibioFirmaBytes!,
              fileOptions: const FileOptions(upsert: true),
            );
        recibioFirmaUrl = _supabase.storage.from('manifests').getPublicUrl(path);
      }

      final manifestMap = data.toMap();
      // Guardamos la URL correcta (la nueva o la que ya existía)
      manifestMap['embarco_firma_url'] = embarcoFirmaUrl;
      manifestMap['recibio_firma_url'] = recibioFirmaUrl;
      
      // Eliminamos pdf_url del mapa para no borrarlo accidentalmente al editar
      manifestMap.remove('pdf_url');

      final id = data.id;
      if (id == null) {
        manifestMap['id'] = manifestId;
         await _supabase.from('manifests').insert(manifestMap);
      } else {
        await _supabase.from('manifests').update(manifestMap).eq('id', id);
      }
      return manifestId;
    } catch (e) {
      // ignore: avoid_print
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