import 'dart:typed_data';
import 'package:flutter/material.dart';
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
    // Navegamos a la nueva pantalla completa
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeFormScreen(employee: employee),
      ),
    );
    // Al volver, recargamos la lista
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
  bool _isSaving = false;
  String? _existingSignatureUrl;

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

  Future<void> _save() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio')));
      return;
    }

    if (_signatureController.isEmpty && (_existingSignatureUrl == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La firma es obligatoria')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      Uint8List? signatureBytes;
      if (_signatureController.isNotEmpty) {
        signatureBytes = await _signatureController.toPngBytes();
      }

      final newEmployee = Employee(
        id: widget.employee?.id,
        name: _nameController.text,
        signatureUrl: _existingSignatureUrl,
      );

      await _service.saveEmployee(newEmployee, signatureBytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empleado guardado')));
        Navigator.pop(context); // Regresar a la lista
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
                decoration: const InputDecoration(labelText: 'Nombre Completo', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              
              const Text('Firma:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              
              Container(
                height: 250, // Más altura para firmar cómodamente
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  color: Colors.grey[100],
                ),
                child: Stack(
                  children: [
                    if (_existingSignatureUrl != null)
                      Center(child: Image.network(_existingSignatureUrl!)),
                    
                    if (_existingSignatureUrl == null)
                      Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.transparent,
                        height: 250,
                        width: double.infinity,
                      ),
                      
                    Positioned(
                      right: 10,
                      top: 10,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Borrar firma y firmar de nuevo',
                          onPressed: () {
                            setState(() {
                              _existingSignatureUrl = null;
                              _signatureController.clear();
                            });
                          },
                        ),
                      ),
                    )
                  ],
                ),
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