import 'package:flutter/material.dart';
import 'dart:typed_data'; 
import 'package:http/http.dart' as http; 
import 'package:image_picker/image_picker.dart';
import 'package:manifiestos_app/models/manifest_data.dart';
import 'package:manifiestos_app/services/supabase_service.dart';
import 'package:manifiestos_app/utils/pdf_generator.dart';
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'package:intl/intl.dart';

import 'package:manifiestos_app/models/client.dart';
import 'package:manifiestos_app/models/operator.dart';

// Helper class (Sin cambios)
class _CargaItemControllers {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
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
  final int _totalSteps = 7; 
  
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = false;
  bool _canPop = false;

  Client? _selectedClient;
  Operator? _selectedOperator;

  String? _embarcoFirmaUrl;
  String? _recibioFirmaUrl;

  List<Uint8List> _evidencePhotos = [];
  final ImagePicker _picker = ImagePicker();

  final _formKeyStep0 = GlobalKey<FormState>();
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();
  final _formKeyStep4 = GlobalKey<FormState>();

  // Controllers
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
  final SignatureController _embarcoSignatureController =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);
  final SignatureController _recibioSignatureController =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);

  int _totalPallets = 0;
  int _totalCajas = 0;

  @override
  void initState() {
    super.initState();
    _trailerLayoutControllers = {
      for (var i = 0; i < 30; i++) i: TextEditingController()
    };
    if (widget.manifest != null) {
      _loadManifestData(widget.manifest!);
    } else {
      _fechaController.text = _formatDate(DateTime.now());
      setState(() {
        _addCargaItem();
      });
    }
  }

  // --- Helpers de Fecha ---
  String _formatDate(DateTime date) {
    try {
      return DateFormat('dd-MMM-yyyy', 'es_ES').format(date).toUpperCase();
    } catch (e) {
      const months = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
      final day = date.day.toString().padLeft(2, '0');
      final month = months[date.month - 1];
      final year = date.year;
      return '$day-$month-$year';
    }
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

  // --- Lógica Carga ---
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

  // --- Funciones para Fotos ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70, 
        maxWidth: 1200,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _evidencePhotos.add(bytes);
        });
      }
    } catch (e) {
      _showErrorSnackbar('Error al seleccionar imagen: $e');
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _evidencePhotos.removeAt(index);
    });
  }

  // --- Carga de Datos ---
  void _loadManifestData(ManifestData manifest) async { 
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

    _embarcoFirmaUrl = manifest.embarcoFirmaUrl;
    _recibioFirmaUrl = manifest.recibioFirmaUrl;

    if (manifest.evidencePhotosUrls != null) {
      List<Uint8List> loadedPhotos = [];
      for (String url in manifest.evidencePhotosUrls!) {
        final bytes = await _downloadBytesFromUrl(url);
        if (bytes != null) loadedPhotos.add(bytes);
      }
      if (mounted) {
        setState(() {
          _evidencePhotos = loadedPhotos;
        });
      }
    }

    if (mounted) {
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

  // --- Buscadores ---
  Future<Iterable<Client>> _searchClients(String query) async {
    if (query.isEmpty) return const Iterable.empty();
    try {
      final data = await _supabaseService.searchClients(query);
      return data.map((json) => Client.fromMap(json));
    } catch (e) {
      _showErrorSnackbar('Error al buscar clientes: $e');
      return const Iterable.empty();
    }
  }

  Future<Iterable<Operator>> _searchOperators(String query) async {
    if (query.isEmpty) return const Iterable.empty();
    try {
      final data = await _supabaseService.searchOperators(query);
      return data.map((json) => Operator.fromMap(json));
    } catch (e) {
      _showErrorSnackbar('Error al buscar operadores: $e');
      return const Iterable.empty();
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Si sales ahora, perderás los datos ingresados en este manifiesto.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Salir'),
          ),
        ],
      ),
    ) ?? false;
  }

  // --- Validaciones ---
  bool _validateAllSteps() {
    if (_trailerNoController.text.isEmpty ||
        _productorController.text.isEmpty ||
        _fechaController.text.isEmpty) {
      _showErrorSnackbar('Error en "Info General": Faltan campos obligatorios.');
      return false;
    }
    if (_consignadoAController.text.isEmpty) {
      _showErrorSnackbar('Error en "Destino": Falta "Consignado A".');
      return false;
    }
    if (_operadorController.text.isEmpty) {
      _showErrorSnackbar('Error en "Transportista": Falta "Operador".');
      return false;
    }
    if (_cargaItemControllers.isEmpty) {
      _showErrorSnackbar('Error en "Carga": Debe añadir al menos un producto.');
      return false;
    }
    for (int i = 0; i < _cargaItemControllers.length; i++) {
      final item = _cargaItemControllers[i];
      if (item.producto.text.isEmpty ||
          (int.tryParse(item.pallets.text) ?? 0) <= 0 ||
          (int.tryParse(item.cajasPorPallet.text) ?? 0) <= 0) {
        _showErrorSnackbar('Error en "Carga" (Producto ${i + 1}): Datos inválidos.');
        return false;
      }
    }
    if (_embarcoNombreController.text.isEmpty ||
        _recibioNombreController.text.isEmpty) {
       _showErrorSnackbar('Error en "Firmas": Faltan los nombres.');
       return false;
    }
    bool embarcoValid = _embarcoSignatureController.isNotEmpty || (_embarcoFirmaUrl != null && _embarcoFirmaUrl!.isNotEmpty);
    bool recibioValid = _recibioSignatureController.isNotEmpty || (_recibioFirmaUrl != null && _recibioFirmaUrl!.isNotEmpty);

    if (!embarcoValid || !recibioValid) {
      _showErrorSnackbar('Error en "Firmas": Faltan las firmas gráficas.');
      return false;
    }
    bool isDiagramValid = _trailerLayoutControllers.values.any((c) => c.text.isNotEmpty);
    if (!isDiagramValid) {
      _showErrorSnackbar('Error en "Diagrama": Indique al menos una posición.');
      return false;
    }
    return true;
  }

  void _onStepContinue() {
    final isLastStep = _currentStep == _totalSteps - 1;

    if (isLastStep) {
      if (_validateAllSteps()) {
        _generateAndSavePdf();
      }
    } else {
      bool isValidCurrent = false;
      if (_currentStep == 0) isValidCurrent = _formKeyStep0.currentState!.validate();
      else if (_currentStep == 1) isValidCurrent = _formKeyStep1.currentState!.validate();
      else if (_currentStep == 2) isValidCurrent = _formKeyStep2.currentState!.validate();
      else if (_currentStep == 3) {
        isValidCurrent = _cargaItemControllers.isNotEmpty;
        if (!isValidCurrent) _showErrorSnackbar('Añada carga antes de continuar.');
      }
      else if (_currentStep == 4) isValidCurrent = _formKeyStep4.currentState!.validate();
      else if (_currentStep == 5) isValidCurrent = true; 
      else if (_currentStep == 6) isValidCurrent = true; 
      
      if (isValidCurrent) {
        setState(() => _currentStep += 1);
      }
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  // --- Descarga Bytes ---
  Future<Uint8List?> _downloadBytesFromUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return response.bodyBytes; 
      } else {
        debugPrint('Error descarga: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Excepción al descargar: $e');
      return null;
    }
  }

  // --- GUARDAR Y GENERAR PDF ---
  Future<void> _generateAndSavePdf() async {
    setState(() => _isLoading = true);
    try {
      Uint8List? pdfEmbarcoBytes;
      Uint8List? pdfRecibioBytes;
      
      Uint8List? bdEmbarcoBytes;
      Uint8List? bdRecibioBytes;

      // 1. EMBARCO
      if (_embarcoSignatureController.isNotEmpty) {
        final bytes = await _embarcoSignatureController.toPngBytes();
        pdfEmbarcoBytes = bytes;
        bdEmbarcoBytes = bytes; 
      } else if (_embarcoFirmaUrl != null && _embarcoFirmaUrl!.isNotEmpty) {
        pdfEmbarcoBytes = await _downloadBytesFromUrl(_embarcoFirmaUrl!);
        bdEmbarcoBytes = null; 
      }

      // 2. RECIBIO
      if (_recibioSignatureController.isNotEmpty) {
        final bytes = await _recibioSignatureController.toPngBytes();
        pdfRecibioBytes = bytes;
        bdRecibioBytes = bytes;
      } else if (_recibioFirmaUrl != null && _recibioFirmaUrl!.isNotEmpty) {
        pdfRecibioBytes = await _downloadBytesFromUrl(_recibioFirmaUrl!);
        bdRecibioBytes = null;
      }

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

      final dataForBd = ManifestData(
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
        
        embarcoFirmaBytes: bdEmbarcoBytes,
        recibioFirmaBytes: bdRecibioBytes,
        embarcoFirmaUrl: _embarcoFirmaUrl,
        recibioFirmaUrl: _recibioFirmaUrl,
        
        evidencePhotosBytes: _evidencePhotos, 
        evidencePhotosUrls: widget.manifest?.evidencePhotosUrls, 
      );

      final manifestId = await _supabaseService.saveManifest(dataForBd);
      if (manifestId == null) throw Exception("Error al guardar en BD.");

      final dataForPdf = ManifestData(
        id: manifestId,
        trailerNo: dataForBd.trailerNo,
        productor: dataForBd.productor,
        certificadoOrigen: dataForBd.certificadoOrigen,
        guiaFitosanitaria: dataForBd.guiaFitosanitaria,
        fecha: dataForBd.fecha,
        consignadoA: dataForBd.consignadoA,
        factura: dataForBd.factura,
        domicilio: dataForBd.domicilio,
        ciudad: dataForBd.ciudad,
        condiciones: dataForBd.condiciones,
        operador: dataForBd.operador,
        trailer: dataForBd.trailer,
        placas: dataForBd.placas,
        caja: dataForBd.caja,
        lineaTransportista: dataForBd.lineaTransportista,
        tel: dataForBd.tel,
        importeFlete: dataForBd.importeFlete,
        anticipoFlete: dataForBd.anticipoFlete,
        cartaPorteNo: dataForBd.cartaPorteNo,
        ctaChequesTransportista: dataForBd.ctaChequesTransportista,
        carga: dataForBd.carga,
        observaciones: dataForBd.observaciones,
        embarcoNombre: dataForBd.embarcoNombre,
        recibioNombre: dataForBd.recibioNombre,
        trailerLayout: dataForBd.trailerLayout,
        
        embarcoFirmaBytes: pdfEmbarcoBytes,
        recibioFirmaBytes: pdfRecibioBytes,
        
        evidencePhotosBytes: _evidencePhotos,
      );

      final pdfBytes = await PdfGenerator.generatePdfBytes(dataForPdf);
      final fileName = 'manifiesto-$manifestId.pdf';
      final pdfUrl = await _supabaseService.uploadPdf(pdfBytes, fileName);
      
      if (pdfUrl != null) {
        await _supabaseService.updatePdfUrl(manifestId, pdfUrl);
      }

      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Manifiesto guardado y PDF generado con éxito')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _showErrorSnackbar('Error al generar PDF: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmationDialog();
        if (shouldExit) {
          setState(() {
            _canPop = true;
          });
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.manifest == null
              ? 'Nuevo Manifiesto'
              : 'Detalles del Manifiesto'),
          actions: [
            // --- NUEVO: Botón de Guardar en la barra superior ---
            if (!_isLoading)
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Guardar Manifiesto',
                onPressed: () {
                  if (_validateAllSteps()) {
                    _generateAndSavePdf();
                  }
                },
              ),
          ],
        ),
        body: Stepper(
          type: StepperType.vertical,
          physics: const ClampingScrollPhysics(),
          currentStep: _currentStep,
          onStepTapped: (int index) {
            setState(() {
              _currentStep = index;
            });
          },
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          controlsBuilder: (context, details) {
            final isLastStep = _currentStep == _totalSteps - 1;
            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                children: <Widget>[
                  if (_currentStep != 0)
                    Expanded(
                      child: TextButton.icon(
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('ATRÁS'),
                          onPressed: details.onStepCancel),
                    ),
                  if (_currentStep != 0) const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                        icon: isLastStep
                            ? const Icon(Icons.save, size: 18)
                            : const Icon(Icons.arrow_forward, size: 18),
                        label: Text(isLastStep ? 'FINALIZAR' : 'SIGUIENTE'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: details.onStepContinue),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Info General'),
              content: Form(
                key: _formKeyStep0,
                child: Column(children: [
                  TextFormField(
                    controller: _trailerNoController,
                    decoration: const InputDecoration(labelText: 'TRAILER No.'),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                  ),
                  TextFormField(
                    controller: _productorController,
                    decoration: const InputDecoration(labelText: 'PRODUCTOR'),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                  ),
                  TextFormField(
                      controller: _certificadoOrigenController,
                      decoration: const InputDecoration(labelText: 'CERTIFICADO DE ORIGEN'),
                      textInputAction: TextInputAction.next),
                  TextFormField(
                      controller: _guiaFitosanitariaController,
                      decoration: const InputDecoration(labelText: 'GUÍA FITOSANITARIA'),
                      textInputAction: TextInputAction.next),
                  TextFormField(
                    controller: _fechaController,
                    decoration: const InputDecoration(
                        labelText: 'FECHA', suffixIcon: Icon(Icons.calendar_today)),
                    readOnly: true,
                    onTap: _selectDate,
                    validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                  ),
                ]),
              ),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text('Destino'),
              content: Form(
                key: _formKeyStep1,
                child: Column(children: [
                  Autocomplete<Client>(
                    optionsBuilder: (textEditingValue) => _searchClients(textEditingValue.text),
                    displayStringForOption: (option) => option.name,
                    onSelected: (selection) {
                      setState(() {
                        _selectedClient = selection;
                        _consignadoAController.text = selection.name;
                        _domicilioController.text = selection.domicilio;
                        _ciudadController.text = selection.ciudad;
                      });
                      FocusScope.of(context).nextFocus();
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (textEditingController.text != _consignadoAController.text) {
                          textEditingController.text = _consignadoAController.text;
                        }
                      });
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: 'CONSIGNADO A'),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                        onChanged: (value) {
                          _consignadoAController.text = value;
                          if (_selectedClient != null && value != _selectedClient!.name) {
                            setState(() {
                              _selectedClient = null;
                              _domicilioController.clear();
                              _ciudadController.clear();
                            });
                          }
                        },
                      );
                    },
                  ),
                  TextFormField(
                      controller: _facturaController,
                      decoration: const InputDecoration(labelText: 'FACTURA'),
                      textInputAction: TextInputAction.next),
                  TextFormField(
                      controller: _domicilioController,
                      decoration: const InputDecoration(labelText: 'DOMICILIO'),
                      readOnly: _domicilioController.text.isNotEmpty && _consignadoAController.text.isNotEmpty,
                      textInputAction: TextInputAction.next),
                  TextFormField(
                      controller: _ciudadController,
                      decoration: const InputDecoration(labelText: 'CIUDAD'),
                      readOnly: _ciudadController.text.isNotEmpty && _consignadoAController.text.isNotEmpty,
                      textInputAction: TextInputAction.next),
                  TextFormField(
                      controller: _condicionesController,
                      decoration: const InputDecoration(labelText: 'CONDICIONES'),
                      textInputAction: TextInputAction.done),
                ]),
              ),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text('Transportista'),
              content: Form(
                key: _formKeyStep2,
                child: SingleChildScrollView(
                    child: Column(children: [
                  Autocomplete<Operator>(
                    optionsBuilder: (textEditingValue) => _searchOperators(textEditingValue.text),
                    displayStringForOption: (option) => option.name,
                    onSelected: (selection) {
                      setState(() {
                        _selectedOperator = selection;
                        _operadorController.text = selection.name;
                        _trailerController.text = selection.trailer;
                        _placasController.text = selection.placas;
                        _cajaController.text = selection.caja;
                        _lineaTransportistaController.text = selection.lineaTransportista;
                        _telController.text = selection.tel;
                      });
                      FocusScope.of(context).nextFocus();
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (textEditingController.text != _operadorController.text) {
                          textEditingController.text = _operadorController.text;
                        }
                      });
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: 'OPERADOR'),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                        onChanged: (value) {
                          _operadorController.text = value;
                          if (_selectedOperator != null && value != _selectedOperator!.name) {
                            setState(() {
                              _selectedOperator = null;
                              _trailerController.clear();
                              _placasController.clear();
                              _cajaController.clear();
                              _lineaTransportistaController.clear();
                              _telController.clear();
                            });
                          }
                        },
                      );
                    },
                  ),
                  TextFormField(
                      controller: _trailerController,
                      decoration: const InputDecoration(labelText: 'TRAILER'),
                      readOnly: _trailerController.text.isNotEmpty && _operadorController.text.isNotEmpty,
                      textInputAction: TextInputAction.next),
                  TextFormField(
                      controller: _placasController,
                      decoration: const InputDecoration(labelText: 'PLACAS'),
                      readOnly: _placasController.text.isNotEmpty && _operadorController.text.isNotEmpty,
                      textInputAction: TextInputAction.next),
                  TextFormField(
                      controller: _cajaController,
                      decoration: const InputDecoration(labelText: 'CAJA'),
                      readOnly: _cajaController.text.isNotEmpty && _operadorController.text.isNotEmpty,
                      textInputAction: TextInputAction.next),
                  TextFormField(
                      controller: _lineaTransportistaController,
                      decoration: const InputDecoration(labelText: 'LINEA TRANSPORTISTA'),
                      readOnly: _lineaTransportistaController.text.isNotEmpty && _operadorController.text.isNotEmpty,
                      textInputAction: TextInputAction.next),
                  TextFormField(
                      controller: _telController,
                      decoration: const InputDecoration(labelText: 'TEL. (INCLUIR LADA)'),
                      readOnly: _telController.text.isNotEmpty && _operadorController.text.isNotEmpty,
                      textInputAction: TextInputAction.next),
                  TextFormField(
                      controller: _importeFleteController,
                      decoration: const InputDecoration(labelText: 'IMPORTE DEL FLETE'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next),
                  TextFormField(
                      controller: _anticipoFleteController,
                      decoration: const InputDecoration(labelText: 'ANTICIPO DEL FLETE'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next),
                  TextFormField(
                      controller: _cartaPorteNoController,
                      decoration: const InputDecoration(labelText: 'CARTA PORTE No.'),
                      textInputAction: TextInputAction.next),
                  TextFormField(
                      controller: _ctaChequesTransportistaController,
                      decoration: const InputDecoration(labelText: 'No. CTA CHEQUES TRANSPORTISTA'),
                      textInputAction: TextInputAction.done),
                ])),
              ),
              isActive: _currentStep >= 2,
            ),
            Step(
              title: const Text('Carga'),
              content: _buildCargaTable(),
              isActive: _currentStep >= 3,
            ),
            Step(
              title: const Text('Firmas'),
              content: Form(
                key: _formKeyStep4,
                child: _buildSignatureSection()
              ),
              isActive: _currentStep >= 4,
            ),
            Step(
              title: const Text('Diagrama'),
              content: _buildTrailerDiagram(),
              isActive: _currentStep >= 5,
            ),
            Step(
              title: const Text('Evidencia'),
              content: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Cámara'),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galería'),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_evidencePhotos.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: _evidencePhotos.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(_evidencePhotos[index], fit: BoxFit.cover),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _removePhoto(index),
                                child: Container(
                                  color: Colors.red,
                                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  else
                    const Text('No hay fotos adjuntas.', style: TextStyle(color: Colors.grey)),
                ],
              ),
              isActive: _currentStep >= 6, 
            ),
          ],
        ),
        floatingActionButton: _isLoading ? const CircularProgressIndicator() : null,
      ),
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
                child: Form(
                  key: controllers.formKey,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Producto ${index + 1}',
                              style: Theme.of(context).textTheme.titleMedium),
                          if (_cargaItemControllers.length > 1)
                            IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeCargaItem(index))
                        ],
                      ),
                      TextFormField(
                        controller: controllers.producto,
                        focusNode: controllers.productoNode,
                        decoration: const InputDecoration(labelText: 'Producto'),
                        onEditingComplete: () => controllers.etiquetasNode.requestFocus(),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                      ),
                      TextFormField(
                          controller: controllers.etiquetas,
                          focusNode: controllers.etiquetasNode,
                          decoration: const InputDecoration(labelText: 'Etiquetas'),
                          onEditingComplete: () => controllers.tamanoNode.requestFocus(),
                          textInputAction: TextInputAction.next),
                      TextFormField(
                          controller: controllers.tamano,
                          focusNode: controllers.tamanoNode,
                          decoration: const InputDecoration(labelText: 'Tamaño'),
                          onEditingComplete: () => controllers.palletsNode.requestFocus(),
                          textInputAction: TextInputAction.next),
                      Row(
                        children: [
                          Expanded(
                              child: TextFormField(
                                  controller: controllers.pallets,
                                  focusNode: controllers.palletsNode,
                                  decoration: const InputDecoration(labelText: 'No. Pallets'),
                                  keyboardType: TextInputType.number,
                                  onEditingComplete: () => controllers.cajasPorPalletNode.requestFocus(),
                                  textInputAction: TextInputAction.next,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Obligatorio';
                                    if ((int.tryParse(v) ?? 0) <= 0) return 'Debe ser > 0';
                                    return null;
                                  })),
                          const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text('x')),
                          Expanded(
                              child: TextFormField(
                                  controller: controllers.cajasPorPallet,
                                  focusNode: controllers.cajasPorPalletNode,
                                  decoration: const InputDecoration(labelText: 'Cajas x Pallet'),
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Obligatorio';
                                    if ((int.tryParse(v) ?? 0) <= 0) return 'Debe ser > 0';
                                    return null;
                                  })),
                        ],
                      ),
                      TextFormField(
                          controller: controllers.cajas,
                          decoration: const InputDecoration(labelText: 'Cajas (Total)'),
                          readOnly: true),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Añadir Producto'),
            onPressed: () => _addCargaItem()),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('TOTALES: ', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(
                  width: 80,
                  child: Text('$_totalPallets p.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(
                  width: 80,
                  child: Text('$_totalCajas',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
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
          TextFormField(
              controller: _observacionesController,
              decoration: const InputDecoration(labelText: 'OBSERVACIONES'),
              maxLines: 3),
          const SizedBox(height: 24),
          _buildSignaturePad(
              title: 'EMBARCÓ (Nombre y Firma)',
              nameController: _embarcoNombreController,
              signatureController: _embarcoSignatureController,
              existingUrl: _embarcoFirmaUrl,
              onClearUrl: () {
                setState(() {
                  _embarcoFirmaUrl = null;
                });
              }),
          const SizedBox(height: 24),
          _buildSignaturePad(
              title: 'RECIBIÓ (NOMBRE y FIRMA)',
              nameController: _recibioNombreController,
              signatureController: _recibioSignatureController,
              existingUrl: _recibioFirmaUrl,
              onClearUrl: () {
                setState(() {
                  _recibioFirmaUrl = null;
                });
              }),
        ],
      ),
    );
  }

  Widget _buildSignaturePad({
    required String title,
    required TextEditingController nameController,
    required SignatureController signatureController,
    String? existingUrl,
    VoidCallback? onClearUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8)),
          height: 150,
          width: double.infinity,
          child: existingUrl != null && existingUrl.isNotEmpty
              ? Stack(
                  children: [
                    Center(
                      child: Image.network(
                        existingUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        color: Colors.white.withOpacity(0.7),
                        child: TextButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text("Firmar de nuevo"),
                          onPressed: onClearUrl,
                        ),
                      ),
                    )
                  ],
                )
              : Signature(
                  controller: signatureController,
                  height: 150,
                  backgroundColor: Colors.grey[200]!),
        ),
        if (existingUrl == null || existingUrl.isEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: () => signatureController.undo()),
              IconButton(
                  icon: const Icon(Icons.redo),
                  onPressed: () => signatureController.redo()),
              IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => signatureController.clear()),
            ],
          ),
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nombre'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'El nombre es obligatorio';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTrailerDiagram() {
    return Column(
      children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [Text('DIFUSOR'), Text('PUERTAS')]),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4),
          itemCount: 30,
          itemBuilder: (context, index) {
            return TextFormField(
                controller: _trailerLayoutControllers[index],
                decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: '${index + 1}'),
                textAlign: TextAlign.center);
          },
        ),
      ],
    );
  }
}