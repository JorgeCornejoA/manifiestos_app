class Operator {
  final String? id; // <--- CORREGIDO: Debe ser String para aceptar UUIDs
  final String name;
  final String trailer;
  final String placas;
  final String caja;
  final String lineaTransportista;
  final String tel;
  final bool isLocal;

  Operator({
    this.id,
    required this.name,
    this.trailer = '',
    this.placas = '',
    this.caja = '',
    this.lineaTransportista = '',
    this.tel = '',
    this.isLocal = false,
  });

  factory Operator.fromMap(Map<String, dynamic> map) {
    return Operator(
      id: map['id']?.toString(), // <--- CORREGIDO: Aseguramos que sea String
      name: map['name'] ?? '',
      trailer: map['trailer'] ?? '',
      placas: map['placas'] ?? '',
      caja: map['caja'] ?? '',
      lineaTransportista: map['linea_transportista'] ?? '',
      tel: map['tel'] ?? '',
      isLocal: map['is_local'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'trailer': trailer,
      'placas': placas,
      'caja': caja,
      'linea_transportista': lineaTransportista,
      'tel': tel,
      'is_local': isLocal,
    };
  }
  
  @override
  String toString() => name;
}