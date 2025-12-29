import 'dart:typed_data';

class ManifestData {
  final String? id;
  final String trailerNo;
  final String productor;
  final String certificadoOrigen;
  final String guiaFitosanitaria;
  final String fecha;
  final String consignadoA;
  final String factura;
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
  final String cartaPorteNo;
  final String ctaChequesTransportista;
  
  // --- CAMBIO PRINCIPAL: Ahora es una Lista de Listas (Secciones de Carga) ---
  final List<List<CargaItem>> carga; 
  
  final String observaciones;
  final String embarcoNombre;
  final String recibioNombre;
  final Map<String, String> trailerLayout;
  
  // Firmas
  final Uint8List? embarcoFirmaBytes;
  final Uint8List? recibioFirmaBytes;
  final String? embarcoFirmaUrl;
  final String? recibioFirmaUrl;

  // Evidencia
  final List<String>? evidencePhotosUrls;
  final List<Uint8List>? evidencePhotosBytes;
  
  // PDF URL
  final String? pdfUrl;

  ManifestData({
    this.id,
    required this.trailerNo,
    required this.productor,
    this.certificadoOrigen = '',
    this.guiaFitosanitaria = '',
    required this.fecha,
    required this.consignadoA,
    this.factura = '',
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
    this.cartaPorteNo = '',
    this.ctaChequesTransportista = '',
    required this.carga,
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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trailer_no': trailerNo,
      'productor': productor,
      'certificado_origen': certificadoOrigen,
      'guia_fitosanitaria': guiaFitosanitaria,
      'fecha': fecha,
      'consignado_a': consignadoA,
      'factura': factura,
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
      'carta_porte_no': cartaPorteNo,
      'cta_cheques_transportista': ctaChequesTransportista,
      
      // Serializamos la lista de listas
      'carga': carga.map((section) => section.map((item) => item.toMap()).toList()).toList(),
      
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
    // Lógica para leer la carga compatible con versiones anteriores
    List<List<CargaItem>> parsedCarga = [];
    
    if (map['carga'] != null) {
      final rawCarga = map['carga'] as List;
      if (rawCarga.isNotEmpty) {
        // Si el primer elemento es una lista, es el formato NUEVO (Lista de Listas)
        if (rawCarga.first is List) {
          parsedCarga = rawCarga.map((section) => 
            (section as List).map((item) => CargaItem.fromMap(item)).toList()
          ).toList();
        } else {
          // Si el primer elemento es un mapa, es el formato VIEJO (Lista plana)
          // Lo envolvemos en una sola sección para no romper la app
          parsedCarga = [
            rawCarga.map((item) => CargaItem.fromMap(item)).toList()
          ];
        }
      }
    }

    return ManifestData(
      id: map['id'],
      trailerNo: map['trailer_no'] ?? '',
      productor: map['productor'] ?? '',
      certificadoOrigen: map['certificado_origen'] ?? '',
      guiaFitosanitaria: map['guia_fitosanitaria'] ?? '',
      fecha: map['fecha'] ?? '',
      consignadoA: map['consignado_a'] ?? '',
      factura: map['factura'] ?? '',
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
      cartaPorteNo: map['carta_porte_no'] ?? '',
      ctaChequesTransportista: map['cta_cheques_transportista'] ?? '',
      
      carga: parsedCarga, // Usamos la carga procesada
      
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
  final int cajas; // Calculado

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