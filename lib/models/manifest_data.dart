import 'dart:typed_data';

class ManifestData {
  final String? id;
  final int? folio; // <--- NUEVO: Folio Autoincrementable
  final String tipo; 
  final String trailerNo;
  final String productor;
  final String fecha;
  final String? horaSalida;
  final String consignadoA;
  final String domicilio;
  final String ciudad;
  final String condiciones;
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
    this.folio, // <--- Agregar al constructor
    this.tipo = 'T',
    required this.trailerNo,
    required this.productor,
    required this.fecha,
    this.horaSalida,
    required this.consignadoA,
    this.domicilio = '',
    this.ciudad = '',
    this.condiciones = '',
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
  }) : sectionProducers = sectionProducers ?? List.filled(carga.length, '');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      // 'folio': folio, <-- NO ENVIAMOS FOLIO (La base de datos lo genera)
      'tipo': tipo,
      'trailer_no': trailerNo,
      'productor': productor,
      'fecha': fecha,
      'hora_salida': horaSalida,
      'consignado_a': consignadoA,
      'domicilio': domicilio,
      'ciudad': ciudad,
      'condiciones': condiciones,
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
          parsedCarga = rawCarga.map((section) => 
            (section as List).map((item) => CargaItem.fromMap(item)).toList()
          ).toList();
        } else {
          parsedCarga = [
            rawCarga.map((item) => CargaItem.fromMap(item)).toList()
          ];
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

    return ManifestData(
      id: map['id'],
      folio: map['folio'], // <--- LEEMOS EL FOLIO DE LA BD
      tipo: map['tipo'] ?? 'T',
      trailerNo: map['trailer_no'] ?? '',
      productor: map['productor'] ?? '',
      fecha: map['fecha'] ?? '',
      horaSalida: map['hora_salida'], // <--- ¡AQUÍ ESTÁ AGREGADO!
      consignadoA: map['consignado_a'] ?? '',
      domicilio: map['domicilio'] ?? '',
      ciudad: map['ciudad'] ?? '',
      condiciones: map['condiciones'] ?? '',
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
      observaciones: map['observaciones'] ?? '',
      embarcoNombre: map['embarco_nombre'] ?? '',
      recibioNombre: map['recibio_nombre'] ?? '',
      trailerLayout: Map<String, String>.from(map['trailer_layout'] ?? {}),
      embarcoFirmaUrl: map['embarco_firma_url'],
      recibioFirmaUrl: map['recibio_firma_url'],
      evidencePhotosUrls: map['evidence_photos_urls'] != null 
          ? List<String>.from(map['evidence_photos_urls']) 
          : [],
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