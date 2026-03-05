import 'package:hive_flutter/hive_flutter.dart';

class LocalDbService {
  // Nombres de las "Cajas"
  static const String producersBox = 'producers_box';
  static const String clientsBox = 'clients_box';
  static const String operatorsBox = 'operators_box';
  static const String employeesBox = 'employees_box';
  static const String trailersBox = 'trailers_box';
  static const String pendingManifestsBox = 'pending_manifests_box'; // <--- LA NUEVA CAJA

  // 1. Inicializar la base de datos
  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Abrimos los espacios de memoria
    await Hive.openBox(producersBox);
    await Hive.openBox(clientsBox);
    await Hive.openBox(operatorsBox);
    await Hive.openBox(employeesBox);
    await Hive.openBox(trailersBox);
    await Hive.openBox(pendingManifestsBox); // <--- ABRIMOS LA CAJA DE PENDIENTES
  }

  // 2. Funciones para los catálogos
  static Future<void> saveData(String boxName, List<dynamic> data) async {
    final box = Hive.box(boxName);
    await box.clear(); 
    await box.addAll(data); 
  }

  static List<Map<String, dynamic>> getData(String boxName) {
    final box = Hive.box(boxName);
    return box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // =======================================================
  // 3. NUEVAS FUNCIONES PARA LOS MANIFIESTOS SIN INTERNET
  // =======================================================
  
  // Guardar un manifiesto para subirlo después
  static Future<void> savePendingManifest(Map<String, dynamic> manifestData) async {
    final box = Hive.box(pendingManifestsBox);
    await box.add(manifestData); 
  }

  // Leer la lista de manifiestos atorados
  static List<Map<dynamic, dynamic>> getPendingManifests() {
    final box = Hive.box(pendingManifestsBox);
    return box.values.map((e) => e as Map<dynamic, dynamic>).toList();
  }

  // Borrar el manifiesto de la memoria una vez que ya se subió a Supabase
  static Future<void> deletePendingManifest(int index) async {
    final box = Hive.box(pendingManifestsBox);
    await box.deleteAt(index);
  }
}