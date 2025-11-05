import 'package:flutter/material.dart';
import 'package:manifiestos_app/models/manifest_data.dart';
import 'package:manifiestos_app/services/supabase_service.dart';
import 'package:manifiestos_app/utils/pdf_generator.dart';
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';

// Helper class to manage controllers and focus nodes for each CargaItem
class _CargaItemControllers {
  final TextEditingController producto;
  final TextEditingController etiquetas;
  final TextEditingController tamano;
  final TextEditingController pallets;
  final TextEditingController cajasPorPallet;
  final TextEditingController cajas;

  final FocusNode productoNode;
  final FocusNode etiquetasNode;
  final FocusNode tamanoNode;
  final FocusNode palletsNode;
  final FocusNode cajasPorPalletNode;

  _CargaItemControllers(CargaItem item)
      : producto = TextEditingController(text: item.producto),
        etiquetas = TextEditingController(text: item.etiquetas),
        tamano = TextEditingController(text: item.tamano),
        pallets = TextEditingController(text: item.pallets.toString()),
        cajasPorPallet = TextEditingController(text: item.cajasPorPallet.toString()),
        cajas = TextEditingController(text: (item.pallets * item.cajasPorPallet).toString()),
        productoNode = FocusNode(),
        etiquetasNode = FocusNode(),
        tamanoNode = FocusNode(),
        palletsNode = FocusNode(),
        cajasPorPalletNode = FocusNode();

  void dispose() {
    producto.dispose();
    etiquetas.dispose();
    tamano.dispose();
    pallets.dispose();
    cajasPorPallet.dispose();
    cajas.dispose();
    productoNode.dispose();
    etiquetasNode.dispose();
    tamanoNode.dispose();
    palletsNode.dispose();
    cajasPorPalletNode.dispose();
  }
}

class ManifestFormScreen extends StatefulWidget {
  final ManifestData? manifest;
  const ManifestFormScreen({super.key, this.manifest});

  @override
  State<ManifestFormScreen> createState() => _ManifestFormScreenState();
}

class _ManifestFormScreenState extends State<ManifestFormScreen> {
  int _currentStep = 0;
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = false;

  // Controllers y FocusNodes para todos los campos
  final _trailerNoController = TextEditingController();
  final _productorController = TextEditingController();
  final _certificadoOrigenController = TextEditingController();
  final _guiaFitosanitariaController = TextEditingController();
  final _fechaController = TextEditingController();
  final _consignadoAController = TextEditingController();
  final _facturaController = TextEditingController();
  final _domicilioController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _condicionesController = TextEditingController();
  final _operadorController = TextEditingController();
  final _trailerController = TextEditingController();
  final _placasController = TextEditingController();
  final _cajaController = TextEditingController();
  final _lineaTransportistaController = TextEditingController();
  final _telController = TextEditingController();
  final _importeFleteController = TextEditingController();
  final _anticipoFleteController = TextEditingController();
  final _cartaPorteNoController = TextEditingController();
  final _ctaChequesTransportistaController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _embarcoNombreController = TextEditingController();
  final _recibioNombreController = TextEditingController();

  List<_CargaItemControllers> _cargaItemControllers = [];
  late Map<int, TextEditingController> _trailerLayoutControllers;
  final SignatureController _embarcoSignatureController = SignatureController(penStrokeWidth: 2, penColor: Colors.black);
  final SignatureController _recibioSignatureController = SignatureController(penStrokeWidth: 2, penColor: Colors.black);

  int _totalPallets = 0;
  int _totalCajas = 0;

  final int _totalSteps = 6;

  @override
  void initState() {
    super.initState();
    _trailerLayoutControllers = { for (var i = 0; i < 30; i++) i: TextEditingController() };
    if (widget.manifest != null) {
      _loadManifestData(widget.manifest!);
    } else {
      _fechaController.text = _formatDate(DateTime.now());
      setState(() { _addCargaItem(); });
    }
  }
  
  String _formatDate(DateTime date) {
    const months = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    return '$day-$month-$year';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _fechaController.text = _formatDate(picked);
      });
    }
  }

  void _addCargaItem() {
    final newControllers = _CargaItemControllers(CargaItem());
    newControllers.pallets.addListener(_calculateTotals);
    newControllers.cajasPorPallet.addListener(_calculateTotals);
    setState(() {
      _cargaItemControllers.add(newControllers);
    });
  }

  void _removeCargaItem(int index) {
    setState(() {
      _cargaItemControllers[index].dispose();
      _cargaItemControllers.removeAt(index);
      _calculateTotals();
    });
  }

  void _calculateTotals() {
    int currentTotalPallets = 0;
    int currentTotalCajas = 0;

    for (final controllers in _cargaItemControllers) {
      final pallets = int.tryParse(controllers.pallets.text) ?? 0;
      final cajasPorPallet = int.tryParse(controllers.cajasPorPallet.text) ?? 0;
      final cajas = pallets * cajasPorPallet;

      controllers.cajas.text = cajas.toString();
      currentTotalPallets += pallets;
      currentTotalCajas += cajas;
    }
    
    if (mounted) {
      setState(() {
        _totalPallets = currentTotalPallets;
        _totalCajas = currentTotalCajas;
      });
    }
  }


  void _loadManifestData(ManifestData manifest) {
    _trailerNoController.text = manifest.trailerNo;
    _productorController.text = manifest.productor;
    _certificadoOrigenController.text = manifest.certificadoOrigen;
    _guiaFitosanitariaController.text = manifest.guiaFitosanitaria;
    _fechaController.text = manifest.fecha;
    _consignadoAController.text = manifest.consignadoA;
    _facturaController.text = manifest.factura;
    _domicilioController.text = manifest.domicilio;
    _ciudadController.text = manifest.ciudad;
    _condicionesController.text = manifest.condiciones;
    _operadorController.text = manifest.operador;
    _trailerController.text = manifest.trailer;
    _placasController.text = manifest.placas;
    _cajaController.text = manifest.caja;
    _lineaTransportistaController.text = manifest.lineaTransportista;
    _telController.text = manifest.tel;
    _importeFleteController.text = manifest.importeFlete.toString();
    _anticipoFleteController.text = manifest.anticipoFlete.toString();
    _cartaPorteNoController.text = manifest.cartaPorteNo;
    _ctaChequesTransportistaController.text = manifest.ctaChequesTransportista;
    _observacionesController.text = manifest.observaciones;
    _embarcoNombreController.text = manifest.embarcoNombre;
    _recibioNombreController.text = manifest.recibioNombre;

    setState(() {
      for (final controller in _cargaItemControllers) {
        controller.dispose();
      }
      _cargaItemControllers = manifest.carga.map((item) {
        final newControllers = _CargaItemControllers(item);
        newControllers.pallets.addListener(_calculateTotals);
        newControllers.cajasPorPallet.addListener(_calculateTotals);
        return newControllers;
      }).toList();
      
      if (_cargaItemControllers.isEmpty) {
        _addCargaItem();
      }

      for (final entry in manifest.trailerLayout.entries) {
        final index = int.tryParse(entry.key);
        if (index != null && _trailerLayoutControllers.containsKey(index)) {
          _trailerLayoutControllers[index]!.text = entry.value;
        }
      }
      _calculateTotals();
    });
  }

  @override
  void dispose() {
    _trailerNoController.dispose();
    _productorController.dispose();
    _certificadoOrigenController.dispose();
    _guiaFitosanitariaController.dispose();
    _fechaController.dispose();
    _consignadoAController.dispose();
    _facturaController.dispose();
    _domicilioController.dispose();
    _ciudadController.dispose();
    _condicionesController.dispose();
    _operadorController.dispose();
    _trailerController.dispose();
    _placasController.dispose();
    _cajaController.dispose();
    _lineaTransportistaController.dispose();
    _telController.dispose();
    _importeFleteController.dispose();
    _anticipoFleteController.dispose();
    _cartaPorteNoController.dispose();
    _ctaChequesTransportistaController.dispose();
    _observacionesController.dispose();
    _embarcoNombreController.dispose();
    _recibioNombreController.dispose();
    _embarcoSignatureController.dispose();
    _recibioSignatureController.dispose();
    _trailerLayoutControllers.forEach((_, controller) => controller.dispose());
     for (final controllers in _cargaItemControllers) {
      controllers.dispose();
    }
    super.dispose();
  }

  Future<void> _generateAndSavePdf() async {
    setState(() => _isLoading = true);
    
    try {
      final embarcoFirmaBytes = await _embarcoSignatureController.toPngBytes();
      final recibioFirmaBytes = await _recibioSignatureController.toPngBytes();

      final layoutMap = <String, String>{};
      _trailerLayoutControllers.forEach((key, controller) {
        if (controller.text.isNotEmpty) layoutMap[key.toString()] = controller.text;
      });
      
      final cargaItems = _cargaItemControllers.map((controllers) {
        return CargaItem(
          producto: controllers.producto.text,
          etiquetas: controllers.etiquetas.text,
          tamano: controllers.tamano.text,
          pallets: int.tryParse(controllers.pallets.text) ?? 0,
          cajasPorPallet: int.tryParse(controllers.cajasPorPallet.text) ?? 0,
        );
      }).toList();

      final data = ManifestData(
        id: widget.manifest?.id,
        trailerNo: _trailerNoController.text,
        productor: _productorController.text,
        certificadoOrigen: _certificadoOrigenController.text,
        guiaFitosanitaria: _guiaFitosanitariaController.text,
        fecha: _fechaController.text,
        consignadoA: _consignadoAController.text,
        factura: _facturaController.text,
        domicilio: _domicilioController.text,
        ciudad: _ciudadController.text,
        condiciones: _condicionesController.text,
        operador: _operadorController.text,
        trailer: _trailerController.text,
        placas: _placasController.text,
        caja: _cajaController.text,
        lineaTransportista: _lineaTransportistaController.text,
        tel: _telController.text,
        importeFlete: int.tryParse(_importeFleteController.text) ?? 0,
        anticipoFlete: int.tryParse(_anticipoFleteController.text) ?? 0,
        cartaPorteNo: _cartaPorteNoController.text,
        ctaChequesTransportista: _ctaChequesTransportistaController.text,
        carga: cargaItems,
        observaciones: _observacionesController.text,
        embarcoNombre: _embarcoNombreController.text,
        recibioNombre: _recibioNombreController.text,
        trailerLayout: layoutMap,
        embarcoFirmaBytes: embarcoFirmaBytes,
        recibioFirmaBytes: recibioFirmaBytes,
      );

      final manifestId = await _supabaseService.saveManifest(data);

      if (manifestId == null) throw Exception("Error al guardar el manifiesto en la base de datos.");

      final pdfBytes = await PdfGenerator.generatePdfBytes(data);
      final fileName = 'manifiesto-$manifestId.pdf';
      await _supabaseService.uploadPdf(pdfBytes, fileName);
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manifiesto guardado y PDF generado con éxito')));
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.manifest == null ? 'Nuevo Manifiesto' : 'Detalles del Manifiesto')),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: () { if (_currentStep < _totalSteps - 1) setState(() => _currentStep += 1); else _generateAndSavePdf(); },
        onStepCancel: () { if (_currentStep > 0) setState(() => _currentStep -= 1); },
        controlsBuilder: (context, details) {
           final isLastStep = _currentStep == _totalSteps - 1;
           return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                if (_currentStep != 0) TextButton.icon(icon: const Icon(Icons.arrow_back), label: const Text('ANTERIOR'), onPressed: details.onStepCancel),
                const Spacer(),
                ElevatedButton.icon(icon: isLastStep ? const Icon(Icons.picture_as_pdf) : const Icon(Icons.arrow_forward), label: Text(isLastStep ? 'GUARDAR Y GENERAR' : 'SIGUIENTE'), onPressed: details.onStepContinue),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Info General'),
            content: Column(children: [
              TextFormField(controller: _trailerNoController, decoration: const InputDecoration(labelText: 'TRAILER No.'), textInputAction: TextInputAction.next),
              TextFormField(controller: _productorController, decoration: const InputDecoration(labelText: 'PRODUCTOR'), textInputAction: TextInputAction.next),
              TextFormField(controller: _certificadoOrigenController, decoration: const InputDecoration(labelText: 'CERTIFICADO DE ORIGEN'), textInputAction: TextInputAction.next),
              TextFormField(controller: _guiaFitosanitariaController, decoration: const InputDecoration(labelText: 'GUÍA FITOSANITARIA'), textInputAction: TextInputAction.next),
              TextFormField(
                controller: _fechaController,
                decoration: const InputDecoration(labelText: 'FECHA', suffixIcon: Icon(Icons.calendar_today)),
                readOnly: true,
                onTap: _selectDate,
              ),
            ]),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text('Destino'),
            content: Column(children: [
              TextFormField(controller: _consignadoAController, decoration: const InputDecoration(labelText: 'CONSIGNADO A'), textInputAction: TextInputAction.next),
              TextFormField(controller: _facturaController, decoration: const InputDecoration(labelText: 'FACTURA'), textInputAction: TextInputAction.next),
              TextFormField(controller: _domicilioController, decoration: const InputDecoration(labelText: 'DOMICILIO'), textInputAction: TextInputAction.next),
              TextFormField(controller: _ciudadController, decoration: const InputDecoration(labelText: 'CIUDAD'), textInputAction: TextInputAction.next),
              TextFormField(controller: _condicionesController, decoration: const InputDecoration(labelText: 'CONDICIONES'), textInputAction: TextInputAction.done),
            ]),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text('Transportista'),
            content: SingleChildScrollView(child: Column(children: [
              TextFormField(controller: _operadorController, decoration: const InputDecoration(labelText: 'OPERADOR'), textInputAction: TextInputAction.next),
              TextFormField(controller: _trailerController, decoration: const InputDecoration(labelText: 'TRAILER'), textInputAction: TextInputAction.next),
              TextFormField(controller: _placasController, decoration: const InputDecoration(labelText: 'PLACAS'), textInputAction: TextInputAction.next),
              TextFormField(controller: _cajaController, decoration: const InputDecoration(labelText: 'CAJA'), textInputAction: TextInputAction.next),
              TextFormField(controller: _lineaTransportistaController, decoration: const InputDecoration(labelText: 'LINEA TRANSPORTISTA'), textInputAction: TextInputAction.next),
              TextFormField(controller: _telController, decoration: const InputDecoration(labelText: 'TEL. (INCLUIR LADA)'), textInputAction: TextInputAction.next),
              TextFormField(controller: _importeFleteController, decoration: const InputDecoration(labelText: 'IMPORTE DEL FLETE'), keyboardType: TextInputType.number, textInputAction: TextInputAction.next),
              TextFormField(controller: _anticipoFleteController, decoration: const InputDecoration(labelText: 'ANTICIPO DEL FLETE'), keyboardType: TextInputType.number, textInputAction: TextInputAction.next),
              TextFormField(controller: _cartaPorteNoController, decoration: const InputDecoration(labelText: 'CARTA PORTE No.'), textInputAction: TextInputAction.next),
              TextFormField(controller: _ctaChequesTransportistaController, decoration: const InputDecoration(labelText: 'No. CTA CHEQUES TRANSPORTISTA'), textInputAction: TextInputAction.done),
            ])),
            isActive: _currentStep >= 2,
          ),
          Step(
            title: const Text('Carga'),
            content: _buildCargaTable(),
            isActive: _currentStep >= 3,
          ),
          Step(
            title: const Text('Firmas'),
            content: _buildSignatureSection(),
            isActive: _currentStep >= 4,
          ),
          Step(
            title: const Text('Diagrama'),
            content: _buildTrailerDiagram(),
            isActive: _currentStep >= 5,
          ),
        ],
      ),
      floatingActionButton: _isLoading ? const CircularProgressIndicator() : null,
    );
  }

  Widget _buildCargaTable() {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _cargaItemControllers.length,
          itemBuilder: (context, index) {
            final controllers = _cargaItemControllers[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Producto ${index + 1}', style: Theme.of(context).textTheme.titleMedium),
                        if (_cargaItemControllers.length > 1) IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeCargaItem(index))
                      ],
                    ),
                    TextFormField(controller: controllers.producto, focusNode: controllers.productoNode, decoration: const InputDecoration(labelText: 'Producto'), onEditingComplete: () => controllers.etiquetasNode.requestFocus(), textInputAction: TextInputAction.next),
                    TextFormField(controller: controllers.etiquetas, focusNode: controllers.etiquetasNode, decoration: const InputDecoration(labelText: 'Etiquetas'), onEditingComplete: () => controllers.tamanoNode.requestFocus(), textInputAction: TextInputAction.next),
                    TextFormField(controller: controllers.tamano, focusNode: controllers.tamanoNode, decoration: const InputDecoration(labelText: 'Tamaño'), onEditingComplete: () => controllers.palletsNode.requestFocus(), textInputAction: TextInputAction.next),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: controllers.pallets, focusNode: controllers.palletsNode, decoration: const InputDecoration(labelText: 'No. Pallets'), keyboardType: TextInputType.number, onEditingComplete: () => controllers.cajasPorPalletNode.requestFocus(), textInputAction: TextInputAction.next)),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('x')),
                        Expanded(child: TextFormField(controller: controllers.cajasPorPallet, focusNode: controllers.cajasPorPalletNode, decoration: const InputDecoration(labelText: 'Cajas x Pallet'), keyboardType: TextInputType.number, textInputAction: TextInputAction.done)),
                      ],
                    ),
                    TextFormField(controller: controllers.cajas, decoration: const InputDecoration(labelText: 'Cajas (Total)'), readOnly: true),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        TextButton.icon(icon: const Icon(Icons.add), label: const Text('Añadir Producto'), onPressed: () => _addCargaItem()),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('TOTALES: ', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: 80, child: Text('$_totalPallets p.', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(width: 80, child: Text('$_totalCajas', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        )
      ],
    );
  }
  
  Widget _buildSignatureSection() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextFormField(controller: _observacionesController, decoration: const InputDecoration(labelText: 'OBSERVACIONES'), maxLines: 3),
          const SizedBox(height: 24),
          _buildSignaturePad(title: 'EMBARCÓ (Nombre y Firma)', nameController: _embarcoNombreController, signatureController: _embarcoSignatureController),
          const SizedBox(height: 24),
          _buildSignaturePad(title: 'RECIBIÓ (NOMBRE y FIRMA)', nameController: _recibioNombreController, signatureController: _recibioSignatureController),
        ],
      ),
    );
  }

  Widget _buildSignaturePad({required String title, required TextEditingController nameController, required SignatureController signatureController}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
          child: Signature(controller: signatureController, height: 150, backgroundColor: Colors.grey[200]!),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(icon: const Icon(Icons.undo), onPressed: () => signatureController.undo()),
            IconButton(icon: const Icon(Icons.redo), onPressed: () => signatureController.redo()),
            IconButton(icon: const Icon(Icons.clear), onPressed: () => signatureController.clear()),
          ],
        ),
        TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
      ],
    );
  }

  Widget _buildTrailerDiagram() {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('DIFUSOR'), Text('PUERTAS')]),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
          itemCount: 30,
          itemBuilder: (context, index) {
            return TextFormField(controller: _trailerLayoutControllers[index], decoration: InputDecoration(border: const OutlineInputBorder(), labelText: '${index + 1}'), textAlign: TextAlign.center);
          },
        ),
      ],
    );
  }
}

