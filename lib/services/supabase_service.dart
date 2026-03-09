import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:manifiestos_app/models/manifest_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manifiestos_app/models/client.dart';
import 'package:manifiestos_app/models/operator.dart';
import 'package:manifiestos_app/models/employee.dart';
import 'package:manifiestos_app/models/company_trailer.dart'; 
import 'package:manifiestos_app/services/local_db_service.dart';
import 'package:manifiestos_app/utils/pdf_generator.dart'; // <--- IMPORTANTE PARA EL PDF OFICIAL
import 'package:uuid/uuid.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  Future<bool> _hasInternet() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) return false;
      return true;
    } catch (e) {
      return true; 
    }
  }

  // ==========================================================
  //      EL SINCRONIZADOR MÁGICO DE MANIFIESTOS PENDIENTES
  // ==========================================================
  static bool _isSyncing = false; // <--- EL CANDADO DE SEGURIDAD

  Future<void> syncPendingManifests() async {
    if (_isSyncing) return; // Si ya está sincronizando, detente
    if (!await _hasInternet()) return;

    final pending = LocalDbService.getPendingManifests();
    if (pending.isEmpty) return; 

    _isSyncing = true; // Ponemos el candado

    try {
      print('🌐 Iniciando sincronización de ${pending.length} manifiestos offline...');
      final currentEmp = await getCurrentEmployee();
      final usuarioSincronizador = currentEmp?.name ?? 'Sincronización Automática';

      for (int i = pending.length - 1; i >= 0; i--) {
        try {
          final item = pending[i];
          final rawData = Map<String, dynamic>.from(item['data']);
          
          final manifestId = rawData['id'];
          List<String> finalPhotoUrls = [];
          String? embarcoFirmaUrl;
          String? recibioFirmaUrl;

          final evidencePhotosBytes = (item['evidencePhotosBytes'] as List<dynamic>?)?.cast<Uint8List>();
          final embarcoFirmaBytes = item['embarcoFirmaBytes'] as Uint8List?;
          final recibioFirmaBytes = item['recibioFirmaBytes'] as Uint8List?;

          // 1. Subir Fotos
          if (evidencePhotosBytes != null && evidencePhotosBytes.isNotEmpty) {
            for (var bytes in evidencePhotosBytes) {
              final uniqueName = '${_uuid.v4()}.png';
              final path = 'evidence/$manifestId/$uniqueName';
              await _supabase.storage.from('manifests').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
              final url = _supabase.storage.from('manifests').getPublicUrl(path);
              finalPhotoUrls.add(url);
            }
          }

          // 2. Subir Firmas (Con Sello de Tiempo anti-caché)
          final timestamp = DateTime.now().millisecondsSinceEpoch; // El truco

          if (embarcoFirmaBytes != null && embarcoFirmaBytes.isNotEmpty) {
            final path = 'signatures/$manifestId/embarco_firma.png';
            await _supabase.storage.from('manifests').uploadBinary(path, embarcoFirmaBytes, fileOptions: const FileOptions(upsert: true));
            embarcoFirmaUrl = '${_supabase.storage.from('manifests').getPublicUrl(path)}?t=$timestamp';
          }
          if (recibioFirmaBytes != null && recibioFirmaBytes.isNotEmpty) {
            final path = 'signatures/$manifestId/recibio_firma.png';
            await _supabase.storage.from('manifests').uploadBinary(path, recibioFirmaBytes, fileOptions: const FileOptions(upsert: true));
            recibioFirmaUrl = '${_supabase.storage.from('manifests').getPublicUrl(path)}?t=$timestamp';
          }

          // 3. Preparar datos
          rawData['embarco_firma_url'] = embarcoFirmaUrl;
          rawData['recibio_firma_url'] = recibioFirmaUrl;
          rawData['evidence_photos_urls'] = finalPhotoUrls;
          rawData.remove('folio'); 
          rawData.remove('pdf_url'); 

          // 4. UPSERT en lugar de INSERT (Más seguro por si hay un micro-corte de internet)
          final savedRecord = await _supabase.from('manifests').upsert(rawData).select().single();
          final savedManifest = ManifestData.fromMap(savedRecord);

          savedManifest.embarcoFirmaBytes = embarcoFirmaBytes;
          savedManifest.recibioFirmaBytes = recibioFirmaBytes;
          savedManifest.evidencePhotosBytes = evidencePhotosBytes;

          // 5. Generar PDF Oficial
          final pdfBytes = await PdfGenerator.generatePdfBytes(savedManifest, nombreUsuario: usuarioSincronizador);
          final fileName = 'manifiesto-${savedManifest.id}.pdf';
          final pdfPath = 'pdfs/$fileName';
          
          await _supabase.storage.from('manifests').uploadBinary(pdfPath, pdfBytes, fileOptions: const FileOptions(upsert: true));
          
          // El truco en el PDF sincronizado
          final pdfUrl = '${_supabase.storage.from('manifests').getPublicUrl(pdfPath)}?t=$timestamp';

          // 6. Actualizar BD
          await _supabase.from('manifests').update({'pdf_url': pdfUrl}).eq('id', savedManifest.id!);

          // 7. Borrar de memoria
          await LocalDbService.deletePendingManifest(i);
          print('✅ Sincronizado. Folio Oficial: ${savedManifest.folio}');

        } catch (e) {
          print('❌ Error en índice $i: $e');
        }
      }
    } finally {
      _isSyncing = false; // Quitamos el candado al terminar, pase lo que pase
    }
  }

  // ==========================================
  //           MANIFIESTOS (Flujo Normal / Offline)
  // ==========================================

  Future<ManifestData?> saveManifest(ManifestData data) async { 
    try {
      final manifestId = data.id ?? _uuid.v4();

      // --- MODO OFFLINE (SIN INTERNET) ---
      if (!await _hasInternet()) {
        print('Modo Offline: Guardando manifiesto en la caja de pendientes...');
        
        final manifestDataMap = data.toMap();
        manifestDataMap['id'] = manifestId;
        manifestDataMap['folio'] = 0; // Forzamos 0 para que sea "PENDIENTE"
        
        final localMap = {
          'data': manifestDataMap,
          'embarcoFirmaBytes': data.embarcoFirmaBytes,
          'recibioFirmaBytes': data.recibioFirmaBytes,
          'evidencePhotosBytes': data.evidencePhotosBytes,
        };
        
        await LocalDbService.savePendingManifest(localMap);
        
        return ManifestData.fromMap(manifestDataMap);
      }

      // --- MODO ONLINE (CON INTERNET) ---
      final timestamp = DateTime.now().millisecondsSinceEpoch; // Sello anti-caché
      String? embarcoFirmaUrl = data.embarcoFirmaUrl;
      String? recibioFirmaUrl = data.recibioFirmaUrl;
      List<String> finalPhotoUrls = List.from(data.evidencePhotosUrls ?? []);

      if (data.evidencePhotosBytes != null && data.evidencePhotosBytes!.isNotEmpty) {
        finalPhotoUrls.clear(); 
        for (int i = 0; i < data.evidencePhotosBytes!.length; i++) {
          final bytes = data.evidencePhotosBytes![i];
          final uniqueName = '${_uuid.v4()}.png'; 
          final path = 'evidence/$manifestId/$uniqueName';
          
          await _supabase.storage.from('manifests').uploadBinary(
            path, bytes, fileOptions: const FileOptions(upsert: true),
          );
          
          final url = _supabase.storage.from('manifests').getPublicUrl(path);
          finalPhotoUrls.add(url);
        }
      }

      if (data.embarcoFirmaBytes != null && data.embarcoFirmaBytes!.isNotEmpty) {
        final path = 'signatures/$manifestId/embarco_firma.png';
        await _supabase.storage.from('manifests').uploadBinary(
              path, data.embarcoFirmaBytes!, fileOptions: const FileOptions(upsert: true),
            );
        embarcoFirmaUrl = '${_supabase.storage.from('manifests').getPublicUrl(path)}?t=$timestamp';
      }
      if (data.recibioFirmaBytes != null && data.recibioFirmaBytes!.isNotEmpty) {
        final path = 'signatures/$manifestId/recibio_firma.png';
        await _supabase.storage.from('manifests').uploadBinary(
              path, data.recibioFirmaBytes!, fileOptions: const FileOptions(upsert: true),
            );
        recibioFirmaUrl = '${_supabase.storage.from('manifests').getPublicUrl(path)}?t=$timestamp';
      }

      final manifestMap = data.toMap();
      manifestMap['embarco_firma_url'] = embarcoFirmaUrl;
      manifestMap['recibio_firma_url'] = recibioFirmaUrl;
      manifestMap['evidence_photos_urls'] = finalPhotoUrls;
      manifestMap.remove('pdf_url');

      final id = data.id;
      Map<String, dynamic> savedRecord;

      if (id == null) {
        manifestMap['id'] = manifestId;
        savedRecord = await _supabase.from('manifests').insert(manifestMap).select().single();
      } else {
        savedRecord = await _supabase.from('manifests').update(manifestMap).eq('id', id).select().single();
      }
      return ManifestData.fromMap(savedRecord);

    } catch (e) {
      print('Error en saveManifest: $e');
      throw Exception('Detalle del error: $e'); 
    }
  }

  Future<List<ManifestData>> getManifests() async {
    try {
      final response = await _supabase.from('manifests').select().order('created_at', ascending: false); 
      return (response as List<dynamic>).map((data) => ManifestData.fromMap(data as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error en getManifests: $e');
      return [];
    }
  }

  Future<void> deleteManifest(String id) async {
    try {
      await _supabase.from('manifests').delete().eq('id', id);
    } catch (e) {
      throw Exception('No se pudo eliminar el manifiesto: $e');
    }
  }

  Future<String?> uploadPdf(Uint8List pdfBytes, String fileName) async {
    try {
      if (!await _hasInternet()) return 'offline_pdf'; 

      final path = 'pdfs/$fileName';
      await _supabase.storage.from('manifests').uploadBinary(
            path, pdfBytes, fileOptions: const FileOptions(upsert: true),
          );
          
      // EL TRUCO: Le pegamos la hora exacta al link para romper la caché del celular
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return '${_supabase.storage.from('manifests').getPublicUrl(path)}?t=$timestamp';
    } catch (e) {
      return null;
    }
  }

  Future<void> updatePdfUrl(String manifestId, String pdfUrl) async {
    try {
      if (!await _hasInternet() || pdfUrl == 'offline_pdf') return; 
      await _supabase.from('manifests').update({'pdf_url': pdfUrl}).eq('id', manifestId);
    } catch (e) {
      print('Error al actualizar PDF URL: $e');
    }
  }

  // Descarga optimizada para firmas de Supabase
  Future<Uint8List?> _downloadBytesFromUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('manifests');
      
      if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
        final internalPath = pathSegments.sublist(bucketIndex + 1).join('/');
        return await Supabase.instance.client.storage.from('manifests').download(internalPath);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==========================================
  //           CATÁLOGOS
  // ==========================================
  
  Future<List<CompanyTrailer>> getCompanyTrailers() async {
    try {
      if (await _hasInternet()) {
        final response = await _supabase.from('company_trailers').select().order('name', ascending: true);
        final data = List<Map<String, dynamic>>.from(response);
        await LocalDbService.saveData(LocalDbService.trailersBox, data); 
        return data.map((e) => CompanyTrailer.fromMap(e)).toList();
      } else {
        throw Exception("Sin conexión");
      }
    } catch (e) {
      return LocalDbService.getData(LocalDbService.trailersBox).map((e) => CompanyTrailer.fromMap(e)).toList();
    }
  }

  Future<List<CompanyTrailer>> searchCompanyTrailers(String query) async {
    final all = await getCompanyTrailers();
    if (query.isEmpty) return all;
    return all.where((t) => t.name.toLowerCase().contains(query.toLowerCase())).toList();
  }

  Future<void> createCompanyTrailer(CompanyTrailer trailer) async {
    final map = trailer.toMap()..remove('id'); 
    await _supabase.from('company_trailers').insert(map);
  }

  Future<void> updateCompanyTrailer(CompanyTrailer trailer) async {
    await _supabase.from('company_trailers').update(trailer.toMap()).eq('id', trailer.id!);
  }

  Future<void> deleteCompanyTrailer(int id) async {
    await _supabase.from('company_trailers').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getProducers() async {
    try {
      if (await _hasInternet()) {
        final response = await _supabase.from('producers').select().order('name', ascending: true);
        final data = List<Map<String, dynamic>>.from(response);
        await LocalDbService.saveData(LocalDbService.producersBox, data);
        return data;
      } else {
        throw Exception("Sin conexión");
      }
    } catch (e) {
      return LocalDbService.getData(LocalDbService.producersBox);
    }
  }

  Future<List<Map<String, dynamic>>> searchProducers(String query) async {
    final all = await getProducers();
    if (query.isEmpty) return all;
    return all.where((p) => p['name'].toString().toLowerCase().contains(query.toLowerCase())).toList();
  }

  Future<void> saveProducer(String name) async {
    final existing = await _supabase.from('producers').select().eq('name', name).maybeSingle();
    if (existing == null) await _supabase.from('producers').insert({'name': name});
  }
  
  Future<void> updateProducer(int id, String name) async {
    await _supabase.from('producers').update({'name': name}).eq('id', id);
  }
  
  Future<void> deleteProducer(int id) async {
    await _supabase.from('producers').delete().eq('id', id);
  }

  Future<Employee?> getCurrentEmployee() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) return null;

      // 1. Si HAY internet, pedimos los datos completos a Supabase (Nombre y Firma)
      if (await _hasInternet()) {
        final response = await _supabase.from('employees').select().eq('email', user.email!).maybeSingle(); 
        if (response != null) return Employee.fromMap(response);
      } else {
        // 2. Si NO HAY internet, buscamos en la memoria local
        print('Modo Offline: Cargando nombre y forzando firma manual...');
        final localEmployees = LocalDbService.getData(LocalDbService.employeesBox);
        for (var empMap in localEmployees) {
          if (empMap['email'] == user.email) {
            // Hacemos una copia de los datos del empleado
            final offlineMap = Map<String, dynamic>.from(empMap);
            // ¡EL TRUCO! Borramos el link de la firma para obligarlo a firmar en la pantalla
            offlineMap['signature_url'] = null; 
            
            return Employee.fromMap(offlineMap);
          }
        }
      }
      return null;
    } catch (e) {
      // Plan de emergencia en caso de error
      final user = _supabase.auth.currentUser;
      if (user != null && user.email != null) {
        final localEmployees = LocalDbService.getData(LocalDbService.employeesBox);
        for (var empMap in localEmployees) {
          if (empMap['email'] == user.email) {
            final offlineMap = Map<String, dynamic>.from(empMap);
            offlineMap['signature_url'] = null; // Borramos la firma
            return Employee.fromMap(offlineMap);
          }
        }
      }
      return null;
    }
  }

  Future<List<Employee>> getEmployees() async {
    try {
      if (await _hasInternet()) {
        final response = await _supabase.from('employees').select().order('name', ascending: true);
        final data = List<Map<String, dynamic>>.from(response);
        await LocalDbService.saveData(LocalDbService.employeesBox, data);
        return data.map((map) => Employee.fromMap(map)).toList();
      } else {
        throw Exception("Sin conexión");
      }
    } catch (e) {
      return LocalDbService.getData(LocalDbService.employeesBox).map((map) => Employee.fromMap(map)).toList();
    }
  }

  Future<List<Map<String, dynamic>>> searchEmployees(String query) async {
    final all = await getEmployees();
    final allMaps = all.map((e) => e.toMap()).toList();
    if (query.isEmpty) return allMaps;
    return allMaps.where((e) => e['name'].toString().toLowerCase().contains(query.toLowerCase())).toList();
  }

  Future<void> saveEmployee(Employee employee, Uint8List? signatureBytes, {String? password}) async {
    String? signatureUrl = employee.signatureUrl;
    final employeeId = employee.id ?? _uuid.v4(); 

    if (signatureBytes != null && signatureBytes.isNotEmpty) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'employee_signatures/${employeeId}_$timestamp.png';
      await _supabase.storage.from('manifests').uploadBinary(path, signatureBytes, fileOptions: const FileOptions(upsert: true));
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

    if (password != null && password.isNotEmpty && employee.email != null) {
      await _supabase.auth.signUp(email: employee.email!, password: password);
    }
  }

  Future<void> deleteEmployee(String id) async {
    await _supabase.from('employees').delete().eq('id', id);
  }

  Future<List<Client>> getClients() async {
    try {
      if (await _hasInternet()) {
        final response = await _supabase.from('clients').select().order('name', ascending: true);
        final data = List<Map<String, dynamic>>.from(response);
        await LocalDbService.saveData(LocalDbService.clientsBox, data);
        return data.map((map) => Client.fromMap(map)).toList();
      } else {
        throw Exception("Sin conexión");
      }
    } catch (e) {
      return LocalDbService.getData(LocalDbService.clientsBox).map((map) => Client.fromMap(map)).toList();
    }
  }

  Future<List<Map<String, dynamic>>> searchClients(String query) async {
    final all = await getClients();
    final allMaps = all.map((e) => e.toMap()).toList();
    if (query.isEmpty) return allMaps;
    return allMaps.where((e) => e['name'].toString().toLowerCase().contains(query.toLowerCase())).toList();
  }

  Future<void> createClient(Client client) async {
    final map = client.toMap()..remove('id'); 
    await _supabase.from('clients').insert(map);
  }

  Future<void> updateClient(Client client) async {
    await _supabase.from('clients').update(client.toMap()).eq('id', client.id!);
  }

  Future<void> deleteClient(String id) async {
    await _supabase.from('clients').delete().eq('id', id);
  }

  Future<List<Operator>> getOperators() async {
    try {
      if (await _hasInternet()) {
        final response = await _supabase.from('operators').select().order('name', ascending: true);
        final data = List<Map<String, dynamic>>.from(response);
        await LocalDbService.saveData(LocalDbService.operatorsBox, data);
        return data.map((map) => Operator.fromMap(map)).toList();
      } else {
        throw Exception("Sin conexión");
      }
    } catch (e) {
      return LocalDbService.getData(LocalDbService.operatorsBox).map((map) => Operator.fromMap(map)).toList();
    }
  }

  Future<List<Map<String, dynamic>>> searchOperators(String query) async {
    final all = await getOperators();
    final allMaps = all.map((e) => e.toMap()).toList();
    if (query.isEmpty) return allMaps;
    return allMaps.where((e) => e['name'].toString().toLowerCase().contains(query.toLowerCase())).toList();
  }

  Future<void> createOperator(Operator operator) async {
    final map = operator.toMap()..remove('id');
    await _supabase.from('operators').insert(map);
  }

  Future<void> updateOperator(Operator operator) async {
    await _supabase.from('operators').update(operator.toMap()).eq('id', operator.id!);
  }

  Future<void> deleteOperator(String id) async { 
    await _supabase.from('operators').delete().eq('id', id);
  }
}