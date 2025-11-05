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

    final logoAsset = await rootBundle.load('images/logo.png');
    final logoImage = pw.MemoryImage(logoAsset.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        build: (context) {
          return pw.Column(
            children: [
              _buildHeader(context, logoImage, data),
              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 7,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _buildInfoSection(context, data),
                        _buildCargaTable(context, data.carga),
                        pw.SizedBox(height: 5),
                        pw.Text('Observaciones: ${data.observaciones}',
                            style: const pw.TextStyle(fontSize: 8)),
                        pw.SizedBox(height: 10),
                        _buildAdditionalText(),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 15),
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
        pw.Image(logo, width: 100),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('FRUVER, S.A. DE C.V.',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text('R.F.C. FRU-940317-9D0',
                style: const pw.TextStyle(fontSize: 8)),
            pw.Text('BLVD. GARCIA MORALES KM. 6.5 S/N COL. EL LLANO',
                style: const pw.TextStyle(fontSize: 8)),
            pw.Text(
                'TEL. (662) 236 0900   FAX (662) 236 0916 HERMOSILLO, SONORA.',
                style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        pw.SizedBox(
          width: 120,
          child: pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  alignment: pw.Alignment.center,
                  color: PdfColors.lightBlue800,
                  child: pw.Text('TRAILER No.', style: headerTextStyle),
                ),
              ]),
              pw.TableRow(children: [
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  alignment: pw.Alignment.center,
                  child: pw.Text('T-${data.trailerNo}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red)),
                )
              ])
            ],
          ),
        )
      ],
    );
  }

  static pw.Widget _buildInfoSection(pw.Context context, ManifestData data) {
    final labelStyle =
        pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold);
    final valueStyle = const pw.TextStyle(fontSize: 9);
    final headerTextStyle = labelStyle.copyWith(color: PdfColors.white, fontSize: 8);

    pw.Widget buildTitledCell(String title, String value) {
      return pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              color: PdfColors.blue100,
              padding: const pw.EdgeInsets.fromLTRB(4, 2, 4, 2),
              child: pw.Text(title, style: labelStyle),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(4, 4, 4, 4),
              constraints: const pw.BoxConstraints(minHeight: 15),
              child: pw.Text(value, style: valueStyle),
            ),
          ],
        ),
      );
    }

    pw.Widget headerCell(String text) => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(2),
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

  // ✅ TABLA DE CARGA CORREGIDA
  static pw.Widget _buildCargaTable(pw.Context context, List<CargaItem> carga) {
    final headerTextStyle = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white);

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
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
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
              children: [
                _emptyCell(),
                _emptyCell(),
                _totalsCell('TOTALES:'),
                _totalsCell('$totalPallets p.'),
                _totalsCell(totalCajas.toString()),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cell(String text) => pw.Container(
        padding: const pw.EdgeInsets.all(4),
        alignment: pw.Alignment.centerLeft,
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
      );

  static pw.Widget _cellHeader(String text) => pw.Container(
        padding: const pw.EdgeInsets.all(4),
        alignment: pw.Alignment.center,
        child: pw.Text(text,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
      );

  static pw.Widget _emptyCell() => pw.Container(
        height: 18,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.black, width: 0.8),
          ),
        ),
      );

  static pw.Widget _totalsCell(String text) => pw.Container(
        padding: const pw.EdgeInsets.all(4),
        alignment: pw.Alignment.center,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: PdfColors.black, width: 0.8),
            top: pw.BorderSide(color: PdfColors.black, width: 0.8),
            right: pw.BorderSide(color: PdfColors.black, width: 0.8),
            bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
          ),
        ),
        child: pw.Text(text,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
      );

  static pw.Widget _buildAdditionalText() {
    final style = const pw.TextStyle(fontSize: 8);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Recibí la carga descrita anteriormente a [] grados Fahrenheit y me comprometo a mantener la temperatura de la carga a los mismos grados...',
          style: style,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Cualquier daño al producto en el trayecto a su destino corre por cuenta y riesgo de la Línea Transportista...',
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
        _signatureBox(context, 'EMBARCO (NOMBRE Y FIRMA)', data.embarcoNombre, data.embarcoFirmaBytes),
        _signatureBox(context, 'ALMACENISTA (NOMBRE Y FIRMA)', '', null),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _signatureBox(context, 'RECIBIÓ (NOMBRE Y FIRMA)', data.recibioNombre, data.recibioFirmaBytes),
            pw.SizedBox(width: 10),
            pw.Column(
              children: [
                pw.Container(width: 80, height: 1, color: PdfColors.black),
                pw.Text('HORA:', style: const pw.TextStyle(fontSize: 8)),
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
      children: [
        if (signatureBytes != null && signatureBytes.isNotEmpty)
          pw.Image(pw.MemoryImage(signatureBytes), height: 30, width: 120)
        else
          pw.SizedBox(height: 30, width: 120),
        pw.Container(width: 150, child: pw.Divider()),
        pw.Text(name, style: const pw.TextStyle(fontSize: 8)),
        pw.Text(title, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  static pw.Widget _buildTrailerDiagram(pw.Context context, Map<String, String> layout) {
    final rows = <pw.TableRow>[];
    for (int i = 0; i < 15; i++) {
      final index1 = i * 2;
      final index2 = i * 2 + 1;
      rows.add(pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          pw.Container(height: 25, alignment: pw.Alignment.center, child: pw.Text('${index1 + 1}', style: const pw.TextStyle(fontSize: 8))),
          pw.Container(height: 25, alignment: pw.Alignment.center, child: pw.Text(layout[index1.toString()] ?? '', style: const pw.TextStyle(fontSize: 8))),
          pw.Container(height: 25, alignment: pw.Alignment.center, child: pw.Text(layout[index2.toString()] ?? '', style: const pw.TextStyle(fontSize: 8))),
          pw.Container(height: 25, alignment: pw.Alignment.center, child: pw.Text('${index2 + 1}', style: const pw.TextStyle(fontSize: 8))),
        ],
      ));
    }

    return pw.Column(
      children: [
        pw.Text('DIFUSOR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        pw.SizedBox(height: 2),
        pw.Table(
          border: pw.TableBorder.all(),
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
