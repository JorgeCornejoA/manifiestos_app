// IMPORTACIÓN AÑADIDA: Necesaria para usar Uint8List
import 'dart:typed_data';

import 'package:manifiestos_app/models/manifest_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  Future<String?> saveManifest(ManifestData data) async {
    try {
      String? embarcoFirmaUrl;
      String? recibioFirmaUrl;
      final manifestId = data.id ?? _uuid.v4();

      // MEJORA: Se verifica que los bytes de la firma no sean nulos NI estén vacíos.
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
  
  Future<void> uploadPdf(Uint8List pdfBytes, String fileName) async {
    try {
      await _supabase.storage.from('manifests').uploadBinary(
            'pdfs/$fileName',
            pdfBytes,
            fileOptions: const FileOptions(upsert: true),
          );
    } catch (e) {
      // Manejar error
    }
  }
}

