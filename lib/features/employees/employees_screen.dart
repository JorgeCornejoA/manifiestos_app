import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <--- IMPORTANTE PARA EL FORMATO
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:manifiestos_app/models/employee.dart';
import 'package:manifiestos_app/services/supabase_service.dart';

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
    try {
      final data = await _supabaseService.getEmployees();
      setState(() {
        _employees = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al cargar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Empleado'),
        content: Text('¿Seguro de eliminar a ${employee.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm == true && employee.id != null) {
      try {
        await _supabaseService.deleteEmployee(employee.id!);
        _loadEmployees();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  void _showEmployeeDialog({Employee? employee}) {
    final nameCtrl = TextEditingController(text: employee?.name ?? '');
    final emailCtrl = TextEditingController(text: employee?.email ?? '');
    final passwordCtrl = TextEditingController(); 
    
    final SignatureController signatureController = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
    );
    
    String? currentSignatureUrl = employee?.signatureUrl;
    Uint8List? pickedSignatureBytes;
    bool isSaving = false; 
    bool isAdmin = employee?.isAdmin ?? false; 
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          
          Future<void> pickImage(ImageSource source) async {
            try {
              final XFile? image = await picker.pickImage(source: source, maxWidth: 800);
              if (image != null) {
                final bytes = await image.readAsBytes();
                setStateDialog(() {
                  pickedSignatureBytes = bytes;
                  currentSignatureUrl = null; 
                });
              }
            } catch (e) {
              print("Error seleccionando imagen: $e");
            }
          }

          return AlertDialog(
            title: Text(employee == null ? 'Nuevo Empleado' : 'Editar Empleado'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SWITCH DE ADMINISTRADOR ---
                    Container(
                      decoration: BoxDecoration(
                        color: isAdmin ? Colors.green.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isAdmin ? Colors.green : Colors.grey.shade300)
                      ),
                      child: SwitchListTile(
                        title: const Text("¿Es Administrador del Sistema?", 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text("Tendrá acceso al módulo de Empleados", style: TextStyle(fontSize: 11)),
                        value: isAdmin,
                        activeColor: Colors.green,
                        onChanged: isSaving ? null : (val) {
                          setStateDialog(() {
                            isAdmin = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 15),

                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.characters, // <--- TECLADO EN MAYÚSCULAS
                      inputFormatters: [UpperCaseTextFormatter()], // <--- FORZA MAYÚSCULAS
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo',
                        icon: Icon(Icons.person),
                      ),
                      enabled: !isSaving,
                    ),
                    const SizedBox(height: 15),
                    
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        hintText: 'ejemplo@fruver.com.mx',
                        icon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isSaving,
                    ),

                    // --- CONTRASEÑA SÓLO SI ES NUEVO ---
                    if (employee == null) ...[
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña de Acceso',
                          hintText: 'Mínimo 6 caracteres',
                          icon: Icon(Icons.lock),
                        ),
                        enabled: !isSaving,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 40, top: 5),
                        child: Text(
                          "Ojo: Crear la cuenta cerrará tu sesión actual de administrador. Tendrás que volver a entrar.",
                          style: TextStyle(color: Colors.orange, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      )
                    ],
                    
                    const SizedBox(height: 20),
                    const Text('Firma del Empleado', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    // Área de firma
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child: pickedSignatureBytes != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(pickedSignatureBytes!, fit: BoxFit.contain),
                                if (!isSaving)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () => setStateDialog(() => pickedSignatureBytes = null),
                                    ),
                                  )
                              ],
                            )
                          : (currentSignatureUrl != null && currentSignatureUrl!.isNotEmpty)
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      currentSignatureUrl!, 
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => const Center(child: Text("Error al cargar firma")),
                                    ),
                                    if (!isSaving)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, color: Colors.red),
                                          onPressed: () => setStateDialog(() => currentSignatureUrl = null),
                                        ),
                                      )
                                  ],
                                )
                              : Signature(
                                  controller: signatureController,
                                  backgroundColor: Colors.transparent,
                                ),
                    ),

                    if (!isSaving && pickedSignatureBytes == null && (currentSignatureUrl == null || currentSignatureUrl!.isEmpty))
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.camera_alt, color: Colors.blue),
                                  onPressed: () => pickImage(ImageSource.camera)),
                              IconButton(
                                  icon: const Icon(Icons.photo_library, color: Colors.blue),
                                  onPressed: () => pickImage(ImageSource.gallery)),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () => signatureController.clear(),
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Limpiar Dibujo'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              if (!isSaving)
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (nameCtrl.text.isEmpty) return;

                  if (employee == null && emailCtrl.text.isNotEmpty && passwordCtrl.text.length < 6) {
                     ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('La contraseña debe tener mínimo 6 caracteres'))
                     );
                     return;
                  }

                  setStateDialog(() {
                    isSaving = true;
                  });

                  Uint8List? finalBytes = pickedSignatureBytes;
                  if (finalBytes == null && signatureController.isNotEmpty) {
                    finalBytes = await signatureController.toPngBytes();
                  }

                  final empData = Employee(
                    id: employee?.id,
                    name: nameCtrl.text,
                    email: emailCtrl.text.isEmpty ? null : emailCtrl.text.trim(),
                    signatureUrl: currentSignatureUrl, 
                    isAdmin: isAdmin, 
                  );

                  try {
                    await _supabaseService.saveEmployee(
                      empData, 
                      finalBytes,
                      password: passwordCtrl.text.isNotEmpty ? passwordCtrl.text : null
                    );
                    
                    if (mounted) _loadEmployees();
                    if (ctx.mounted) Navigator.pop(ctx);

                    if (employee == null && passwordCtrl.text.isNotEmpty) {
                      if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(
                             content: Text('Empleado guardado. Si el sistema te sacó, vuelve a iniciar sesión como admin.'),
                             duration: Duration(seconds: 5),
                           )
                         );
                      }
                    }

                  } catch (e) {
                    setStateDialog(() {
                      isSaving = false;
                    });
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")))
                      );
                    }
                  }
                },
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Text('Guardar'),
              ),
            ],
          );
        }
      ),
    ).then((_) {
      signatureController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Directorio de Empleados'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? const Center(child: Text('No hay empleados registrados.'))
              : ListView.builder(
                  itemCount: _employees.length,
                  itemBuilder: (context, index) {
                    final emp = _employees[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: emp.isAdmin ? Colors.orange.shade100 : Colors.green.shade50,
                          child: Icon(
                            emp.isAdmin ? Icons.admin_panel_settings : Icons.badge, 
                            color: emp.isAdmin ? Colors.orange : Colors.green
                          ),
                        ),
                        title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp.email != null && emp.email!.isNotEmpty 
                                ? emp.email! 
                                : '⚠️ Sin correo vinculado',
                              style: TextStyle(
                                color: emp.email != null && emp.email!.isNotEmpty ? Colors.grey[700] : Colors.redAccent,
                              ),
                            ),
                            if (emp.isAdmin)
                               const Text("Rol: Administrador", style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEmployeeDialog(employee: emp),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteEmployee(emp),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEmployeeDialog(),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

// --- CLASE MÁGICA PARA FORZAR MAYÚSCULAS ---
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}