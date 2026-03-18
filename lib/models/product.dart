class Product {
  final String codigoPro;
  final String nombrePro;
  final String? codigoTam; 
  final String nombreTam;

  Product({
    required this.codigoPro,
    required this.nombrePro,
    this.codigoTam,
    this.nombreTam = '',
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    final tamanoData = map['t_tamano'];
    String tamanoName = '';
    
    if (tamanoData != null && tamanoData is Map) {
      tamanoName = tamanoData['v_nombre_tam']?.toString() ?? '';
    }

    return Product(
      codigoPro: map['c_codigo_pro']?.toString() ?? '',
      nombrePro: map['v_nombre_pro']?.toString() ?? '',
      codigoTam: map['c_codigo_tam']?.toString(),
      nombreTam: tamanoName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'c_codigo_pro': codigoPro,
      'v_nombre_pro': nombrePro,
      'c_codigo_tam': codigoTam,
    };
  }
}