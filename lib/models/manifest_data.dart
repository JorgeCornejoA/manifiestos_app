import 'dart:typed_data';

// --- NUEVA CLASE PARA AGRUPAR LOS DATOS DE CADA DESTINO ---
class DestinoData {
  final String consignadoA;
  final String domicilio;
  final String ciudad;
  final String condiciones;

  DestinoData({
    this.consignadoA = '',
    this.domicilio = '',
    this.ciudad = '',
    this.condiciones = '',
  });

  Map<String, dynamic> toMap() => {
        'consignado_a': consignadoA,
        'domicilio': domicilio,
        'ciudad': ciudad,
        'condiciones': condiciones,
      };

  factory DestinoData.fromMap(Map<String, dynamic> map) => DestinoData(
        consignadoA: map['consignado_a'] ?? '',
        domicilio: map['domicilio'] ?? '',
        ciudad: map['ciudad'] ?? '',
        condiciones: map['condiciones'] ?? '',
      );
}

class ManifestData {
  final String? id;
  final int? folio;
  final String tipo;
  final String trailerNo;
  final String productor;
  final String fecha;
  final String? horaSalida;
  
  // --- AHORA ES UNA LISTA DE DESTINOS ---
  final List<DestinoData> destinos;
  
  final String operador;
  final String trailer;
  final String placas;
  final String caja;
  final String lineaTransportista;
  final String tel;
  final int importeFlete;
  final int anticipoFlete;

  final List<List<CargaItem>> carga;
  final List<String> sectionProducers;
  final List<int> sectionDestinos; // <--- LIGA LA CARGA AL DESTINO (0 = Destino 1, 1 = Destino 2, etc.)

  final String observaciones;
  final String embarcoNombre;
  final String recibioNombre;
  final Map<String, String> trailerLayout;

  // Firmas
  Uint8List? embarcoFirmaBytes;
  Uint8List? recibioFirmaBytes;
  final String? embarcoFirmaUrl;
  final String? recibioFirmaUrl;

  // Evidencia
  List<String>? evidencePhotosUrls;
  List<Uint8List>? evidencePhotosBytes;

  final String? pdfUrl;

  ManifestData({
    this.id,
    this.folio,
    this.tipo = 'T',
    required this.trailerNo,
    required this.productor,
    required this.fecha,
    this.horaSalida,
    required this.destinos,
    required this.operador,
    this.trailer = '',
    this.placas = '',
    this.caja = '',
    this.lineaTransportista = '',
    this.tel = '',
    this.importeFlete = 0,
    this.anticipoFlete = 0,
    required this.carga,
    List<String>? sectionProducers,
    List<int>? sectionDestinos,
    this.observaciones = '',
    required this.embarcoNombre,
    required this.recibioNombre,
    required this.trailerLayout,
    this.embarcoFirmaBytes,
    this.recibioFirmaBytes,
    this.embarcoFirmaUrl,
    this.recibioFirmaUrl,
    this.evidencePhotosUrls,
    this.evidencePhotosBytes,
    this.pdfUrl,
  })  : sectionProducers = sectionProducers ?? List.filled(carga.length, ''),
        sectionDestinos = sectionDestinos ?? List.filled(carga.length, 0);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo,
      'trailer_no': trailerNo,
      'productor': productor,
      'fecha': fecha,
      'hora_salida': horaSalida,
      
      // Guardamos la lista de destinos en JSON
      'destinos': destinos.map((d) => d.toMap()).toList(),
      // Guardamos la liga de cada carga con su destino
      'section_destinos': sectionDestinos,

      // Por compatibilidad con tu BD vieja, guardamos el Destino 1 en los campos viejos
      'consignado_a': destinos.isNotEmpty ? destinos.first.consignadoA : '',
      'domicilio': destinos.isNotEmpty ? destinos.first.domicilio : '',
      'ciudad': destinos.isNotEmpty ? destinos.first.ciudad : '',
      'condiciones': destinos.isNotEmpty ? destinos.first.condiciones : '',

      'operador': operador,
      'trailer': trailer,
      'placas': placas,
      'caja': caja,
      'linea_transportista': lineaTransportista,
      'tel': tel,
      'importe_flete': importeFlete,
      'anticipo_flete': anticipoFlete,
      'carga': carga.map((section) => section.map((item) => item.toMap()).toList()).toList(),
      'section_producers': sectionProducers,
      'observaciones': observaciones,
      'embarco_nombre': embarcoNombre,
      'recibio_nombre': recibioNombre,
      'trailer_layout': trailerLayout,
      'embarco_firma_url': embarcoFirmaUrl,
      'recibio_firma_url': recibioFirmaUrl,
      'evidence_photos_urls': evidencePhotosUrls,
      'pdf_url': pdfUrl,
    };
  }

  factory ManifestData.fromMap(Map<String, dynamic> map) {
    List<List<CargaItem>> parsedCarga = [];
    if (map['carga'] != null) {
      final rawCarga = map['carga'] as List;
      if (rawCarga.isNotEmpty) {
        if (rawCarga.first is List) {
          parsedCarga = rawCarga.map((section) => (section as List).map((item) => CargaItem.fromMap(item)).toList()).toList();
        } else {
          parsedCarga = [rawCarga.map((item) => CargaItem.fromMap(item)).toList()];
        }
      }
    }

    List<String> parsedProducers = [];
    if (map['section_producers'] != null) {
      parsedProducers = List<String>.from(map['section_producers']);
    } else {
      if (parsedCarga.isNotEmpty) {
        parsedProducers.add(map['productor'] ?? '');
        for (int i = 1; i < parsedCarga.length; i++) parsedProducers.add('');
      }
    }

    // --- CARGAMOS LOS DESTINOS (Nuevos o Viejos) ---
    List<DestinoData> parsedDestinos = [];
    if (map['destinos'] != null) {
      parsedDestinos = (map['destinos'] as List).map((e) => DestinoData.fromMap(e)).toList();
    } else {
      parsedDestinos.add(DestinoData(
        consignadoA: map['consignado_a'] ?? '',
        domicilio: map['domicilio'] ?? '',
        ciudad: map['ciudad'] ?? '',
        condiciones: map['condiciones'] ?? '',
      ));
    }

    List<int> parsedSectionDestinos = [];
    if (map['section_destinos'] != null) {
      parsedSectionDestinos = List<int>.from(map['section_destinos']);
    } else {
      parsedSectionDestinos = List.filled(parsedCarga.length, 0);
    }

    return ManifestData(
      id: map['id'],
      folio: map['folio'],
      tipo: map['tipo'] ?? 'T',
      trailerNo: map['trailer_no'] ?? '',
      productor: map['productor'] ?? '',
      fecha: map['fecha'] ?? '',
      horaSalida: map['hora_salida'],
      destinos: parsedDestinos,
      operador: map['operador'] ?? '',
      trailer: map['trailer'] ?? '',
      placas: map['placas'] ?? '',
      caja: map['caja'] ?? '',
      lineaTransportista: map['linea_transportista'] ?? '',
      tel: map['tel'] ?? '',
      importeFlete: map['importe_flete'] ?? 0,
      anticipoFlete: map['anticipo_flete'] ?? 0,
      carga: parsedCarga,
      sectionProducers: parsedProducers,
      sectionDestinos: parsedSectionDestinos,
      observaciones: map['observaciones'] ?? '',
      embarcoNombre: map['embarco_nombre'] ?? '',
      recibioNombre: map['recibio_nombre'] ?? '',
      trailerLayout: Map<String, String>.from(map['trailer_layout'] ?? {}),
      embarcoFirmaUrl: map['embarco_firma_url'],
      recibioFirmaUrl: map['recibio_firma_url'],
      evidencePhotosUrls: map['evidence_photos_urls'] != null ? List<String>.from(map['evidence_photos_urls']) : [],
      pdfUrl: map['pdf_url'],
    );
  }
}

class CargaItem {
  final String producto;
  final String etiquetas;
  final String tamano;
  final int pallets;
  final int cajasPorPallet;
  final int cajas;

  CargaItem({
    this.producto = '',
    this.etiquetas = '',
    this.tamano = '',
    this.pallets = 0,
    this.cajasPorPallet = 0,
  }) : cajas = pallets * cajasPorPallet;

  Map<String, dynamic> toMap() {
    return {
      'producto': producto,
      'etiquetas': etiquetas,
      'tamano': tamano,
      'pallets': pallets,
      'cajas_por_pallet': cajasPorPallet,
    };
  }

  factory CargaItem.fromMap(Map<String, dynamic> map) {
    return CargaItem(
      producto: map['producto'] ?? '',
      etiquetas: map['etiquetas'] ?? '',
      tamano: map['tamano'] ?? '',
      pallets: map['pallets'] ?? 0,
      cajasPorPallet: map['cajas_por_pallet'] ?? 0,
    );
  }
}