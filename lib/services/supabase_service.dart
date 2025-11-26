import 'dart:typed_data';

import 'package:manifiestos_app/models/manifest_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manifiestos_app/models/client.dart';
import 'package:manifiestos_app/models/operator.dart'; // Asegúrate de tener este import
import 'package:uuid/uuid.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  Future<String?> saveManifest(ManifestData data) async {
    try {
      String? embarcoFirmaUrl;
      String? recibioFirmaUrl;
      final manifestId = data.id ?? _uuid.v4();

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
      manifestMap['embarco_firma_url'] = embarcoFirmaUrl;
      manifestMap['recibio_firma_url'] = recibioFirmaUrl;
      
      // No incluimos 'pdf_url' aquí porque se actualiza DESPUÉS de subir el PDF

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

  Future<List<ManifestData>> getManifests() async {
    try {
      final response = await _supabase.from('manifests').select();
      final manifests = (response as List<dynamic>)
          .map((data) => ManifestData.fromMap(data as Map<String, dynamic>))
          .toList();
      return manifests;
    } catch (e) {
      return [];
    }
  }
  
  // MODIFICACIÓN: uploadPdf ahora devuelve la URL pública del archivo subido
  Future<String?> uploadPdf(Uint8List pdfBytes, String fileName) async {
    try {
      final path = 'pdfs/$fileName';
      await _supabase.storage.from('manifests').uploadBinary(
            path,
            pdfBytes,
            fileOptions: const FileOptions(upsert: true),
          );
      // Devuelve la URL pública
      return _supabase.storage.from('manifests').getPublicUrl(path);
    } catch (e) {
      // ignore: avoid_print
      print('Error al subir PDF: $e');
      return null;
    }
  }

  // MODIFICACIÓN: Nueva función para actualizar el manifiesto con la URL del PDF
  Future<void> updatePdfUrl(String manifestId, String pdfUrl) async {
    try {
      await _supabase
          .from('manifests')
          .update({'pdf_url': pdfUrl})
          .eq('id', manifestId);
    } catch (e) {
      // ignore: avoid_print
      print('Error al actualizar PDF URL: $e');
    }
  }

  // --- NUEVO: MÉTODO PARA BUSCAR CLIENTES ---
  Future<List<Map<String, dynamic>>> searchClients(String query) async {
    try {
      final response = await _supabase
          .from('clients') // <-- ¡Verifica que 'clients' sea el nombre de tu tabla!
          .select()       // <-- Selecciona todas las columnas
          .ilike('name', '%$query%'); // <-- ¡Verifica que 'name' sea tu columna de nombre!

      return response;
      
    } catch (e) {
      // ignore: avoid_print
      print('Error en searchClients: $e');
      return []; // Retorna lista vacía en caso de error
    }
  }

  // --- NUEVO: MÉTODO PARA BUSCAR OPERADORES ---
  Future<List<Map<String, dynamic>>> searchOperators(String query) async {
    try {
      final response = await _supabase
          .from('operators') // <-- ¡Verifica que 'operators' sea el nombre de tu tabla!
          .select()
          .ilike('name', '%$query%'); // <-- ¡Verifica que 'name' sea tu columna de nombre!

      return response;

    } catch (e) {
      // ignore: avoid_print
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

  /// Crea un nuevo cliente en la base de datos
  Future<void> createClient(Client client) async {
    try {
      // Quitamos el ID nulo para que Supabase genere uno nuevo
      final map = client.toMap()..remove('id'); 
      
      await _supabase.from('clients').insert(map);

    } catch (e) {
      print('Error en createClient: $e');
      // Re-lanzamos el error para que el formulario pueda mostrarlo
      throw Exception('Error al crear cliente: $e');
    }
  }

  /// Actualiza un cliente existente en la base de datos
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

  /// Elimina un cliente de la base de datos usando su ID
  Future<void> deleteClient(String id) async {
    try {
      await _supabase.from('clients').delete().eq('id', id);
    } catch (e) {
      print('Error en deleteClient: $e');
      throw Exception('Error al eliminar cliente: $e');
    }
  }

  // --- MÉTODOS CRUD PARA OPERADORES ---

  /// Obtiene todos los operadores
  Future<List<Operator>> getOperators() async {
    try {
      final response = await _supabase
          .from('operators') // Verifica que tu tabla se llame 'operators'
          .select()
          .order('name', ascending: true);
      
      return response.map((map) => Operator.fromMap(map)).toList();
    } catch (e) {
      print('Error en getOperators: $e');
      return [];
    }
  }

  /// Crea un nuevo operador
  Future<void> createOperator(Operator operator) async {
    try {
      final map = operator.toMap()..remove('id'); // Quitamos ID para que se autogenere
      await _supabase.from('operators').insert(map);
    } catch (e) {
      print('Error en createOperator: $e');
      throw Exception('Error al crear operador: $e');
    }
  }

  /// Actualiza un operador existente
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

  /// Elimina un operador
  Future<void> deleteOperator(String id) async {
    try {
      await _supabase.from('operators').delete().eq('id', id);
    } catch (e) {
      print('Error en deleteOperator: $e');
      throw Exception('Error al eliminar operador: $e');
    }
  }

} // <-- Fin de la clase SupabaseService