import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // <--- IMPORTANTE: Asegúrate de tener este import
import 'package:manifiestos_app/models/employee.dart';
import 'package:manifiestos_app/services/supabase_service.dart';
import 'package:signature/signature.dart';

// --- PANTALLA DE LISTA ---
class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Employee> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    final data = await _supabaseService.getEmployees();
    if (mounted) {
      setState(() {
        _employees = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEmployee(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('¿Borrar este empleado?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
        ],
      ),
    );

    if (confirm == true) {
      await _supabaseService.deleteEmployee(id);
      _loadEmployees();
    }
  }

  void _navigateToForm({Employee? employee}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeFormScreen(employee: employee),
      ),
    );
    _loadEmployees();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Empleados')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? const Center(child: Text('No hay empleados registrados'))
              : ListView.builder(
                  itemCount: _employees.length,
                  itemBuilder: (context, index) {
                    final emp = _employees[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: emp.signatureUrl != null
                            ? const Text('Firma registrada', style: TextStyle(color: Colors.green))
                            : const Text('Sin firma', style: TextStyle(color: Colors.red)),
                        leading: emp.signatureUrl != null
                            ? Container(
                                width: 60,
                                color: Colors.grey[200],
                                child: Image.network(emp.signatureUrl!, fit: BoxFit.contain),
                              )
                            : const Icon(Icons.person, size: 40),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _navigateToForm(employee: emp),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteEmployee(emp.id!),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// --- PANTALLA DE FORMULARIO (VISTA COMPLETA) ---
class EmployeeFormScreen extends StatefulWidget {
  final Employee? employee;

  const EmployeeFormScreen({super.key, this.employee});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _nameController = TextEditingController();
  final SignatureController _signatureController = SignatureController(penStrokeWidth: 3, penColor: Colors.black);
  final SupabaseService _service = SupabaseService();
  final ImagePicker _picker = ImagePicker(); // Selector de imagen
  
  bool _isSaving = false;
  String? _existingSignatureUrl;
  Uint8List? _uploadedSignatureBytes; // Variable para almacenar la imagen subida

  @override
  void initState() {
    super.initState();
    if (widget.employee != null) {
      _nameController.text = widget.employee!.name;
      _existingSignatureUrl = widget.employee!.signatureUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  // --- Lógica para seleccionar imagen ---
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // Reducir tamaño para que no pese tanto
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _uploadedSignatureBytes = bytes;
          _signatureController.clear(); // Si sube imagen, limpiamos el pad
          _existingSignatureUrl = null; // Ocultamos la firma vieja para mostrar la nueva
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al imagen: $e')));
    }
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio')));
      return;
    }

    // Validar si hay firma (ya sea dibujada, subida o existente)
    bool hasSignature = _signatureController.isNotEmpty || 
                        _uploadedSignatureBytes != null || 
                        (_existingSignatureUrl != null && widget.employee?.signatureUrl != null);

    if (!hasSignature) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La firma es obligatoria (Dibuja o Sube imagen)')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      Uint8List? signatureBytes;
      
      // PRIORIDAD: 
      // 1. Imagen subida
      // 2. Firma dibujada
      if (_uploadedSignatureBytes != null) {
        signatureBytes = _uploadedSignatureBytes;
      } else if (_signatureController.isNotEmpty) {
        signatureBytes = await _signatureController.toPngBytes();
      }

      final newEmployee = Employee(
        id: widget.employee?.id,
        name: _nameController.text.toUpperCase(),
        // Si no subió nada nuevo, mantenemos la URL vieja (si la borró, será null)
        signatureUrl: (_uploadedSignatureBytes == null && _signatureController.isEmpty) 
            ? _existingSignatureUrl 
            : null, 
      );

      await _service.saveEmployee(newEmployee, signatureBytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empleado guardado')));
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee == null ? 'Nuevo Empleado' : 'Editar Empleado'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Nombre Completo', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              
              const Text('Firma:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              
              // --- ZONA VISUAL DE FIRMA ---
              Container(
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  color: Colors.grey[100],
                ),
                child: Stack(
                  children: [
                    // A. Mostrar imagen SUBIDA manualmente
                    if (_uploadedSignatureBytes != null)
                      Center(child: Image.memory(_uploadedSignatureBytes!, fit: BoxFit.contain)),

                    // B. Mostrar firma EXISTENTE de la nube
                    if (_existingSignatureUrl != null && _uploadedSignatureBytes == null)
                      Center(child: Image.network(_existingSignatureUrl!)),
                    
                    // C. Pad para DIBUJAR (Solo si no hay imagen subida)
                    if (_uploadedSignatureBytes == null && _existingSignatureUrl == null)
                      Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.transparent,
                        height: 250,
                        width: double.infinity,
                      ),
                      
                    // Botón BORRAR (Limpia todo)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Borrar firma y empezar de nuevo',
                          onPressed: () {
                            setState(() {
                              _existingSignatureUrl = null;
                              _uploadedSignatureBytes = null;
                              _signatureController.clear();
                            });
                          },
                        ),
                      ),
                    )
                  ],
                ),
              ),
              
              const SizedBox(height: 10),

              // --- BOTÓN PARA SUBIR IMAGEN ---
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Subir Imagen de Firma'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade100,
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: _isSaving ? const Text('Guardando...') : const Text('GUARDAR EMPLEADO'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}