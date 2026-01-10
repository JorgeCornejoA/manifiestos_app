class Producer {
  final int? id;
  final String name;

  Producer({this.id, required this.name});

  factory Producer.fromMap(Map<String, dynamic> map) {
    return Producer(
      id: map['id'],
      name: map['name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
    };
  }
  
  // Necesario para que el Autocomplete funcione correctamente
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Producer && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);
  
  @override
  String toString() => name;
}