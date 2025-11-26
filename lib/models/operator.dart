// lib/models/operator.dart
class Operator {
  final String? id;
  final String name;
  final String trailer;
  final String placas;
  final String caja;
  final String lineaTransportista;
  final String tel;

  Operator({
    this.id,
    required this.name,
    this.trailer = '',
    this.placas = '',
    this.caja = '',
    this.lineaTransportista = '',
    this.tel = '',
  });

  factory Operator.fromMap(Map<String, dynamic> map) {
    return Operator(
      id: map['id'] as String?,
      name: map['name'] as String? ?? '',
      trailer: map['trailer'] as String? ?? '',
      placas: map['placas'] as String? ?? '',
      caja: map['caja'] as String? ?? '',
      lineaTransportista: map['linea_transportista'] as String? ?? '',
      tel: map['tel'] as String? ?? '',
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
    };
  }
}