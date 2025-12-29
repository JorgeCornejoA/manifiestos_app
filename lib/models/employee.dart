class Employee {
  final String? id;
  final String name;
  final String? signatureUrl;

  Employee({
    this.id,
    required this.name,
    this.signatureUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'signature_url': signatureUrl,
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'],
      name: map['name'] ?? '',
      signatureUrl: map['signature_url'],
    );
  }
}