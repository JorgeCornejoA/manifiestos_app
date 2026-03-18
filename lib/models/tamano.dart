class Tamano {
  final String codigoTam;
  final String nombreTam;

  Tamano({required this.codigoTam, required this.nombreTam});

  factory Tamano.fromMap(Map<String, dynamic> map) {
    return Tamano(
      codigoTam: map['c_codigo_tam']?.toString() ?? '',
      nombreTam: map['v_nombre_tam']?.toString() ?? '',
    );
  }
}