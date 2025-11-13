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
  final List<CargaItem> carga;
  final String observaciones;
  final String embarcoNombre;
  final String recibioNombre;
  final Map<String, String> trailerLayout;
  final String? embarcoFirmaUrl;
  final String? recibioFirmaUrl;

  // MODIFICACIÓN: Se añade el campo para la URL del PDF
  final String? pdfUrl;

  // Transient fields for images
  final Uint8List? embarcoFirmaBytes;
  final Uint8List? recibioFirmaBytes;

  ManifestData({
    this.id,
    this.trailerNo = '',
    this.productor = '',
    this.certificadoOrigen = '',
    this.guiaFitosanitaria = '',
    this.fecha = '',
    this.consignadoA = '',
    this.factura = '',
    this.domicilio = '',
    this.ciudad = '',
    this.condiciones = '',
    this.operador = '',
    this.trailer = '',
    this.placas = '',
    this.caja = '',
    this.lineaTransportista = '',
    this.tel = '',
    this.importeFlete = 0,
    this.anticipoFlete = 0,
    this.cartaPorteNo = '',
    this.ctaChequesTransportista = '',
    this.carga = const [],
    this.observaciones = '',
    this.embarcoNombre = '',
    this.recibioNombre = '',
    this.trailerLayout = const {},
    this.embarcoFirmaUrl,
    this.recibioFirmaUrl,
    this.pdfUrl, // Se añade al constructor
    this.embarcoFirmaBytes,
    this.recibioFirmaBytes,
  });

  factory ManifestData.fromMap(Map<String, dynamic> map) {
    final cargaList = (map['carga'] as List<dynamic>?)
            ?.map((item) => CargaItem.fromMap(item as Map<String, dynamic>))
            .toList() ??
        [];
    
    final layoutMap = (map['trailer_layout'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value.toString()),
        ) ?? {};

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
      carga: cargaList,
      observaciones: map['observaciones'] ?? '',
      embarcoNombre: map['embarco_nombre'] ?? '',
      recibioNombre: map['recibio_nombre'] ?? '',
      trailerLayout: layoutMap,
      embarcoFirmaUrl: map['embarco_firma_url'],
      recibioFirmaUrl: map['recibio_firma_url'],
      pdfUrl: map['pdf_url'], // Se lee desde el mapa
    );
  }

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
      'carga': carga.map((item) => item.toMap()).toList(),
      'observaciones': observaciones,
      'embarco_nombre': embarcoNombre,
      'recibio_nombre': recibioNombre,
      'trailer_layout': trailerLayout,
      'embarco_firma_url': embarcoFirmaUrl,
      'recibio_firma_url': recibioFirmaUrl,
      'pdf_url': pdfUrl, // Se añade al mapa
    };
  }
}

class CargaItem {
  String producto;
  String etiquetas;
  String tamano;
  int pallets;
  int cajasPorPallet;
  
  int get cajas => pallets * cajasPorPallet;

  CargaItem({
    this.producto = '',
    this.etiquetas = '',
    this.tamano = '',
    this.pallets = 0,
    this.cajasPorPallet = 0,
  });

  factory CargaItem.fromMap(Map<String, dynamic> map) {
    return CargaItem(
      producto: map['producto'] ?? '',
      etiquetas: map['etiquetas'] ?? '',
      tamano: map['tamano'] ?? '',
      pallets: map['pallets'] ?? 0,
      cajasPorPallet: map['cajas_por_pallet'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'producto': producto,
      'etiquetas': etiquetas,
      'tamano': tamano,
      'pallets': pallets,
      'cajas_por_pallet': cajasPorPallet,
      'cajas': cajas,
    };
  }
}