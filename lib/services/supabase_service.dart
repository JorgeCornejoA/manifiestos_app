import 'dart:typed_data';
import 'package:manifiestos_app/models/manifest_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manifiestos_app/models/client.dart';
import 'package:manifiestos_app/models/operator.dart';
import 'package:manifiestos_app/models/employee.dart'; // <--- ESTE ES EL QUE FALTABA
import 'package:uuid/uuid.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  Future<String?> saveManifest(ManifestData data) async {
    try {
      final manifestId = data.id ?? _uuid.v4();

      String? embarcoFirmaUrl = data.embarcoFirmaUrl;
      String? recibioFirmaUrl = data.recibioFirmaUrl;
      
      // --- Lógica para Fotos de Evidencia ---
      List<String> finalPhotoUrls = List.from(data.evidencePhotosUrls ?? []);

      if (data.evidencePhotosBytes != null && data.evidencePhotosBytes!.isNotEmpty) {
        
        // Limpiamos para reconstruir la lista con las fotos actuales
        finalPhotoUrls.clear(); 
        
        for (int i = 0; i < data.evidencePhotosBytes!.length; i++) {
          final bytes = data.evidencePhotosBytes![i];
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

      // Lógica de firmas existente
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
      
      // Guardar lista de fotos
      manifestMap['evidence_photos_urls'] = finalPhotoUrls;

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
      print('Error en saveManifest: $e');
      return null;
    }
  }

  // --- MÉTODOS PARA EMPLEADOS (NUEVO) ---

  Future<List<Employee>> getEmployees() async {
    try {
      final response = await _supabase
          .from('employees')
          .select()
          .order('name', ascending: true);
      return response.map((map) => Employee.fromMap(map)).toList();
    } catch (e) {
      print('Error al obtener empleados: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchEmployees(String query) async {
    try {
      return await _supabase
          .from('employees')
          .select()
          .ilike('name', '%$query%');
    } catch (e) {
      print('Error buscando empleados: $e');
      return [];
    }
  }

  Future<void> saveEmployee(Employee employee, Uint8List? signatureBytes) async {
    try {
      String? signatureUrl = employee.signatureUrl;
      
      final employeeId = employee.id ?? _uuid.v4(); 

      if (signatureBytes != null && signatureBytes.isNotEmpty) {
        final path = 'employee_signatures/$employeeId.png';
        
        await _supabase.storage.from('manifests').uploadBinary(
              path,
              signatureBytes,
              fileOptions: const FileOptions(upsert: true),
            );
            
        signatureUrl = _supabase.storage.from('manifests').getPublicUrl(path);
      }

      final map = employee.toMap();
      map['signature_url'] = signatureUrl;

      if (employee.id == null) {
        map['id'] = employeeId;
        await _supabase.from('employees').insert(map);
      } else {
        await _supabase.from('employees').update(map).eq('id', employee.id!);
      }
    } catch (e) {
      print('Error guardando empleado: $e');
      throw Exception('Error al guardar empleado');
    }
  }

  Future<void> deleteEmployee(String id) async {
    try {
      await _supabase.from('employees').delete().eq('id', id);
    } catch (e) {
      print('Error eliminando empleado: $e');
      throw Exception('Error al eliminar');
    }
  }

  // --- RESTO DE MÉTODOS (MANIFIESTOS, PDFS, CLIENTES, OPERADORES) ---

  Future<void> deleteManifest(String id) async {
    try {
      await _supabase.from('manifests').delete().eq('id', id);
    } catch (e) {
      print('Error al eliminar manifiesto: $e');
      throw Exception('No se pudo eliminar el manifiesto: $e');
    }
  }

  Future<List<ManifestData>> getManifests() async {
    try {
      final response = await _supabase
          .from('manifests')
          .select()
          .order('created_at', ascending: false); 
          
      final manifests = (response as List<dynamic>)
          .map((data) => ManifestData.fromMap(data as Map<String, dynamic>))
          .toList();
      return manifests;
    } catch (e) {
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