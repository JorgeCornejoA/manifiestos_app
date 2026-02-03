class CompanyTrailer {
  final int? id;
  final String name;
  final String plate;
  final String box;

  CompanyTrailer({
    this.id, 
    required this.name, 
    this.plate = '', 
    this.box = ''
  });

  factory CompanyTrailer.fromMap(Map<String, dynamic> map) {
    return CompanyTrailer(
      id: map['id'],
      name: map['name'] ?? '',
      plate: map['plate'] ?? '',
      box: map['box_type'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'plate': plate,
      'box_type': box,
    };
  }
  
  @override
  String toString() => name;
}