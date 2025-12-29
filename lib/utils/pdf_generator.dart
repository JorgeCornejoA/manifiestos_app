import 'package:flutter/services.dart';
import 'package:manifiestos_app/models/manifest_data.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfGenerator {
  static Future<Uint8List> generatePdfBytes(ManifestData data) async {
    final pdf = pw.Document();

    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final boldFont = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");

    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(font),
      bold: pw.Font.ttf(boldFont),
    );

    final logoAsset = await rootBundle.load('assets/images/logo.png');
    final logoImage = pw.MemoryImage(logoAsset.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.letter,
        // Reducimos un poco el margen vertical para ganar espacio arriba y abajo
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 20),
        build: (context) {
          return pw.Column(
            children: [
              _buildHeader(context, logoImage, data),
              pw.SizedBox(height: 5), // Menos espacio aquí
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 7,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _buildInfoSection(context, data),
                        
                        // Iteramos sobre las secciones de carga (Tablas compactas)
                        ...data.carga.map((seccion) {
                           return pw.Padding(
                             padding: const pw.EdgeInsets.only(top: 5),
                             child: _buildCargaTable(context, seccion)
                           );
                        }),

                        pw.SizedBox(height: 4),
                        pw.Text('Observaciones: ${data.observaciones}',
                            style: const pw.TextStyle(fontSize: 8)), // Letra un poco más chica
                        pw.SizedBox(height: 10),
                        _buildAdditionalText(),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    flex: 3,
                    child: _buildTrailerDiagram(context, data.trailerLayout),
                  ),
                ],
              ),
              pw.Spacer(),
              _buildSignatureSection(context, data),
            ],
          );
        },
      ),
    );

    // Páginas de Fotos
    if (data.evidencePhotosBytes != null) {
      for (var photoBytes in data.evidencePhotosBytes!) {
        final image = pw.MemoryImage(photoBytes);
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.letter,
            margin: const pw.EdgeInsets.all(24),
            build: (context) {
              return pw.Center(
                child: pw.Image(
                  image,
                  fit: pw.BoxFit.contain,
                ),
              );
            },
          ),
        );
      }
    }
    
    return pdf.save();
  }

  static pw.Widget _buildHeader(
      pw.Context context, pw.ImageProvider logo, ManifestData data) {
    final headerTextStyle = pw.TextStyle(
        color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8);

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Image(logo, width: 90), // Logo un poco más pequeño
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('FRUVER, S.A. DE C.V.',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.Text('R.F.C. FRU-940317-9D0',
                style: const pw.TextStyle(fontSize: 7)),
            pw.Text('BLVD. GARCIA MORALES KM. 6.5 S/N COL. EL LLANO',
                style: const pw.TextStyle(fontSize: 7)),
            pw.Text(
                'TEL. (662) 236 0900   FAX (662) 236 0916 HERMOSILLO, SONORA.',
                style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
        pw.SizedBox(
          width: 110,
          child: pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(1),
                  alignment: pw.Alignment.center,
                  color: PdfColors.lightBlue800,
                  child: pw.Text('TRAILER No.', style: headerTextStyle),
                ),
              ]),
              pw.TableRow(children: [
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  alignment: pw.Alignment.center,
                  child: pw.Text('T-${data.trailerNo}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red, fontSize: 9)),
                )
              ])
            ],
          ),
        )
      ],
    );
  }

  static pw.Widget _buildInfoSection(pw.Context context, ManifestData data) {
    // Reducimos tamaños de fuente y padding para compactar info
    final labelStyle =
        pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold);
    final valueStyle = const pw.TextStyle(fontSize: 8);
    final headerTextStyle = labelStyle.copyWith(color: PdfColors.white, fontSize: 7);

    pw.Widget buildTitledCell(String title, String value) {
      return pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              color: PdfColors.blue100,
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1), // Padding reducido
              child: pw.Text(title, style: labelStyle),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5), // Padding reducido
              constraints: const pw.BoxConstraints(minHeight: 11), // Altura mínima reducida
              child: pw.Text(value, style: valueStyle),
            ),
          ],
        ),
      );
    }

    pw.Widget headerCell(String text) => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(1),
          alignment: pw.Alignment.center,
          color: PdfColors.lightBlue800,
          child: pw.Text(text, style: headerTextStyle),
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        buildTitledCell('PRODUCTOR:', data.productor),
        buildTitledCell('CERTIFICADO DE ORIGEN:', data.certificadoOrigen),
        pw.Row(children: [
          pw.Expanded(flex: 2, child: buildTitledCell('GUÍA FITOSANITARIA:', data.guiaFitosanitaria)),
          pw.Expanded(flex: 1, child: buildTitledCell('FECHA:', data.fecha)),
        ]),
        headerCell('DATOS DEL DESTINO'),
        pw.Row(children: [
          pw.Expanded(flex: 2, child: buildTitledCell('CONSIGNADO A:', data.consignadoA)),
          pw.Expanded(flex: 1, child: buildTitledCell('FACTURA:', data.factura)),
        ]),
        buildTitledCell('DOMICILIO:', data.domicilio),
        pw.Row(children: [
          pw.Expanded(child: buildTitledCell('CIUDAD:', data.ciudad)),
          pw.Expanded(child: buildTitledCell('CONDICIONES:', data.condiciones)),
        ]),
        headerCell('DATOS DEL TRANSPORTISTA'),
        pw.Row(children: [
          pw.Expanded(flex: 2, child: buildTitledCell('OPERADOR:', data.operador)),
          pw.Expanded(flex: 2, child: buildTitledCell('TRAILER:', data.trailer)),
          pw.Expanded(flex: 1, child: buildTitledCell('PLACAS:', data.placas)),
          pw.Expanded(flex: 1, child: buildTitledCell('CAJA:', data.caja)),
        ]),
        pw.Row(children: [
          pw.Expanded(child: buildTitledCell('LINEA TRANSPORTISTA:', data.lineaTransportista)),
          pw.Expanded(child: buildTitledCell('TEL (INCLUIR LADA):', data.tel)),
        ]),
        pw.Row(children: [
          pw.Expanded(child: buildTitledCell('IMPORTE DEL FLETE:', '\$${data.importeFlete}')),
          pw.Expanded(child: buildTitledCell('ANTICIPO DEL FLETE:', '\$${data.anticipoFlete}')),
          pw.Expanded(child: buildTitledCell('CARTA PORTE No.:', data.cartaPorteNo)),
          pw.Expanded(child: buildTitledCell('No. CTA CHEQUES:', data.ctaChequesTransportista)),
        ]),
      ],
    );
  }

  static pw.Widget _buildCargaTable(pw.Context context, List<CargaItem> carga) {
    final headerTextStyle = pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white);

    final totalPallets = carga.fold<int>(0, (sum, item) => sum + item.pallets);
    final totalCajas = carga.fold<int>(0, (sum, item) => sum + item.cajas);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(1),
          alignment: pw.Alignment.center,
          color: PdfColors.lightBlue800,
          child: pw.Text("DATOS DE LA CARGA", style: headerTextStyle),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(3),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(2),
            4: pw.FlexColumnWidth(2),
          },
          children: [
            // Encabezados
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.lightBlue100),
              children: [
                _cellHeader('PRODUCTO'),
                _cellHeader('ETIQUETAS'),
                _cellHeader('TAMAÑO'),
                _cellHeader('No. PALLETS'),
                _cellHeader('CAJAS'),
              ],
            ),
            // Filas de datos
            ...carga.map((item) {
              return pw.TableRow(
                children: [
                  _cell(item.producto),
                  _cell(item.etiquetas),
                  _cell(item.tamano),
                  _cell('${item.pallets} x ${item.cajasPorPallet}'),
                  _cell(item.cajas.toString()),
                ],
              );
            }).toList(),
            // Fila de totales
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _emptyCell(),
                _emptyCell(),
                _totalsCell('SUBTOTAL:'),
                _totalsCell('$totalPallets p.'),
                _totalsCell(totalCajas.toString()),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // --- CELDAS COMPACTAS (AQUÍ ESTÁ LA MAGIA DEL AHORRO) ---
  static pw.Widget _cell(String text) => pw.Container(
        // Relleno reducido: Vertical 1.5, Horizontal 2
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 2),
        alignment: pw.Alignment.centerLeft,
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
      );

  static pw.Widget _cellHeader(String text) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 2),
        alignment: pw.Alignment.center,
        child: pw.Text(text,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
      );

  static pw.Widget _emptyCell() => pw.Container(
        height: 10, // Altura reducida para celdas vacías
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.black, width: 0.5),
          ),
        ),
      );

  static pw.Widget _totalsCell(String text) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.3, horizontal: 2),
        alignment: pw.Alignment.center,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: PdfColors.black, width: 0.5),
            top: pw.BorderSide(color: PdfColors.black, width: 0.5),
            right: pw.BorderSide(color: PdfColors.black, width: 0.5),
            bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
          ),
        ),
        child: pw.Text(text,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
      );

  static pw.Widget _buildAdditionalText() {
    final style = const pw.TextStyle(fontSize: 7); // Fuente más chica
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Cualquier daño al producto en el trayecto a su destino corre por cuenta y riesgo de la Línea Transportista. También indico mi conformidad de que el importe del flete se depositará a la cuenta indicada anteriormente una vez que sea entregada la carga completa y de conformidad.',
          style: style,
        ),
      ],
    );
  }

  static pw.Widget _buildSignatureSection(pw.Context context, ManifestData data) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _signatureBox(context, 'EMBARCÓ (NOMBRE Y FIRMA)', data.embarcoNombre, data.embarcoFirmaBytes),
        
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _signatureBox(context, 'RECIBIÓ (NOMBRE Y FIRMA)', data.recibioNombre, data.recibioFirmaBytes),
            
            pw.SizedBox(width: 10),
            
            pw.Column(
              children: [
                pw.Container(width: 80, height: 1, color: PdfColors.black),
                pw.SizedBox(height: 2),
                pw.Text('HORA:', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 25), 
              ],
            )
          ],
        )
      ],
    );
  }

  static pw.Widget _signatureBox(
      pw.Context context, String title, String name, Uint8List? signatureBytes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (signatureBytes != null && signatureBytes.isNotEmpty)
          pw.Image(pw.MemoryImage(signatureBytes), height: 35, width: 90)
        else
          pw.SizedBox(height: 35, width: 90),
        
        pw.Container(width: 140, child: pw.Divider()),
        
        pw.Text(name, 
          style: const pw.TextStyle(fontSize: 7), 
          textAlign: pw.TextAlign.center
        ),
        pw.Text(title, 
          style: const pw.TextStyle(fontSize: 7), 
          textAlign: pw.TextAlign.center
        ),
      ],
    );
  }

  static pw.Widget _buildTrailerDiagram(pw.Context context, Map<String, String> layout) {
    final rows = <pw.TableRow>[];
    for (int i = 0; i < 15; i++) {
      final index1 = i * 2;
      final index2 = i * 2 + 1;
      // Diagrama compactado
      rows.add(pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          pw.Container(height: 25, alignment: pw.Alignment.center, child: pw.Text('${index1 + 1}', style: const pw.TextStyle(fontSize: 7))),
          pw.Container(height: 25, alignment: pw.Alignment.center, child: pw.Text(layout[index1.toString()] ?? '', style: const pw.TextStyle(fontSize: 7))),
          pw.Container(height: 25, alignment: pw.Alignment.center, child: pw.Text(layout[index2.toString()] ?? '', style: const pw.TextStyle(fontSize: 7))),
          pw.Container(height: 25, alignment: pw.Alignment.center, child: pw.Text('${index2 + 1}', style: const pw.TextStyle(fontSize: 7))),
        ],
      ));
    }

    return pw.Column(
      children: [
        pw.Text('DIFUSOR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        pw.SizedBox(height: 2),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: const {
            0: pw.IntrinsicColumnWidth(),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
            3: pw.IntrinsicColumnWidth(),
          },
          children: rows,
        ),
        pw.SizedBox(height: 2),
        pw.Text('PUERTAS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
      ],
    );
  }
}