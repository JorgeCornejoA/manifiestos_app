import 'package:flutter/services.dart';
import 'package:manifiestos_app/models/manifest_data.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfGenerator {
  static Future<Uint8List> generatePdfBytes(ManifestData data, {String? nombreUsuario}) async {
    final pdf = pw.Document();

    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final boldFont = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");

    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(font),
      bold: pw.Font.ttf(boldFont),
    );

    final logoAsset = await rootBundle.load('assets/images/logo.png');
    final logoImage = pw.MemoryImage(logoAsset.buffer.asUint8List());

    final horaSalidaStr = (data.horaSalida != null && data.horaSalida!.isNotEmpty) ? data.horaSalida! : '--:--';

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        build: (context) {
          return [
            _buildHeader(context, logoImage, data),
            pw.SizedBox(height: 8),

            pw.Row(
              children: [
                pw.Expanded(
                  flex: 7,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Hora de salida: $horaSalidaStr',
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Generado por: ${nombreUsuario ?? data.embarcoNombre}',
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Expanded(flex: 3, child: pw.SizedBox()),
              ],
            ),
            pw.SizedBox(height: 5),

            pw.Partitions(children: [
              pw.Partition(
                flex: 7,
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _buildInfoSection(context, data),
                      pw.SizedBox(height: 4), // <--- ESPACIO REDUCIDO DE 10 a 4

                      ...data.carga.asMap().entries.map((entry) {
                        int index = entry.key;
                        List<CargaItem> seccion = entry.value;
                        
                        String productorName = "";
                        if (index < data.sectionProducers.length) {
                          productorName = data.sectionProducers[index];
                        }

                        int destIndex = 0;
                        if (index < data.sectionDestinos.length) {
                          destIndex = data.sectionDestinos[index];
                        }
                        
                        String consignadoA = '';
                        if (destIndex >= 0 && destIndex < data.destinos.length) {
                          consignadoA = data.destinos[destIndex].consignadoA;
                        }
                        
                        String finalTitle = productorName.toUpperCase();
                        if (consignadoA.isNotEmpty) {
                          finalTitle += " -> DESTINO: ${consignadoA.toUpperCase()}";
                        }

                        return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6), // <--- PADDING REDUCIDO
                            child: _buildCargaTable(context, seccion, finalTitle));
                      }).toList(),

                      pw.SizedBox(height: 2),
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: 'Observaciones: ',
                              style: const pw.TextStyle(fontSize: 9), 
                            ),
                            pw.TextSpan(
                              text: data.observaciones,
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold, 
                                color: PdfColors.red,           
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 8), // <--- ESPACIO REDUCIDO ANTES DE LA FIRMA
                      _buildAdditionalText(),
                    ]),
              ),

              pw.Partition(
                  flex: 3,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 15), 
                    child: _buildTrailerDiagram(context, data.trailerLayout),
                  )),
            ]),

            pw.SizedBox(height: 8), // <--- ESPACIO REDUCIDO ANTES DE LAS FIRMAS
            pw.Container(child: _buildSignatureSection(context, data)),
          ];
        },
      ),
    );

    if (data.evidencePhotosBytes != null) {
      for (var photoBytes in data.evidencePhotosBytes!) {
        final image = pw.MemoryImage(photoBytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.letter,
            margin: const pw.EdgeInsets.all(24),
            build: (context) {
              return pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
            },
          ),
        );
      }
    }

    return pdf.save();
  }

  static pw.Widget _buildHeader(pw.Context context, pw.ImageProvider logo, ManifestData data) {
    final headerTextStyle = pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10);
    final folioString = (data.folio == null || data.folio == 0) ? 'PENDIENTE' : data.folio!.toString().padLeft(5, '0');
    final isTrailer = data.tipo == 'T';
    final labelText = isTrailer ? 'TRAILER No.' : 'ENTRADA ALM. No.';
    final valuePrefix = isTrailer ? 'T-' : 'EA-';

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Image(logo, width: 100),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('FRUVER, S.A. DE C.V.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text('R.F.C. FRU-940317-9D0', style: const pw.TextStyle(fontSize: 8)),
            pw.Text('BLVD. GARCIA MORALES KM. 6.5 S/N COL. EL LLANO', style: const pw.TextStyle(fontSize: 8)),
            pw.Text('TEL. (662) 236 0900   FAX (662) 236 0916 HERMOSILLO, SONORA.', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 120,
              child: pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(children: [
                    pw.Container(padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2), alignment: pw.Alignment.center, color: PdfColors.lightBlue800, child: pw.Text('NOTA DE REMISIÓN', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7))),
                  ]),
                  pw.TableRow(children: [
                    pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4), alignment: pw.Alignment.center, child: pw.Text('Nº $folioString', style: pw.TextStyle(font: pw.Font.courierBold(), color: PdfColors.red, fontSize: 12, fontWeight: pw.FontWeight.bold)))
                  ])
                ],
              ),
            ),
            pw.SizedBox(height: 5),
            pw.SizedBox(
              width: 120,
              child: pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(children: [
                    pw.Container(padding: const pw.EdgeInsets.all(2), alignment: pw.Alignment.center, color: PdfColors.lightBlue800, child: pw.Text(labelText, style: headerTextStyle)),
                  ]),
                  pw.TableRow(children: [
                    pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), alignment: pw.Alignment.center, child: pw.Text('$valuePrefix${data.trailerNo}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red, fontSize: 10)))
                  ])
                ],
              ),
            ),
          ],
        )
      ],
    );
  }

  static pw.Widget _buildInfoSection(pw.Context context, ManifestData data) {
    final labelStyle = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);
    final valueStyle = const pw.TextStyle(fontSize: 9);
    final headerTextStyle = labelStyle.copyWith(color: PdfColors.white, fontSize: 9);

    pw.Widget buildTitledCell(String title, String value) {
      return pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(color: PdfColors.blue100, padding: const pw.EdgeInsets.fromLTRB(4, 2, 4, 2), child: pw.Text(title, style: labelStyle)),
            pw.Container(padding: const pw.EdgeInsets.fromLTRB(4, 4, 4, 4), constraints: const pw.BoxConstraints(minHeight: 15), child: pw.Text(value, style: valueStyle)),
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

    List<pw.Widget> destinosWidgets = [];
    for (int i = 0; i < data.destinos.length; i++) {
      final dest = data.destinos[i];
      final title = data.destinos.length > 1 ? 'DATOS DEL DESTINO ${i + 1}' : 'DATOS DEL DESTINO';
      
      destinosWidgets.add(headerCell(title));
      destinosWidgets.add(
        pw.Row(children: [
          pw.Expanded(flex: 2, child: buildTitledCell('CONSIGNADO A:', dest.consignadoA)),
          pw.Expanded(flex: 3, child: buildTitledCell('DOMICILIO:', dest.domicilio)),
        ])
      );
      destinosWidgets.add(
        pw.Row(children: [
          pw.Expanded(child: buildTitledCell('CIUDAD:', dest.ciudad)),
          pw.Expanded(child: buildTitledCell('CONDICIONES:', dest.condiciones)),
        ])
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(children: [
          pw.Expanded(flex: 2, child: buildTitledCell('PRODUCTOR:', data.productor)),
          pw.Expanded(flex: 1, child: buildTitledCell('FECHA:', data.fecha)),
        ]),
        
        ...destinosWidgets,
        
        headerCell('DATOS DEL TRANSPORTISTA'),
        buildTitledCell('OPERADOR:', data.operador),
        pw.Row(children: [
          pw.Expanded(child: buildTitledCell('TRAILER:', data.trailer)),
          pw.Expanded(child: buildTitledCell('PLACAS:', data.placas)),
          pw.Expanded(child: buildTitledCell('CAJA:', data.caja)),
        ]),
        pw.Row(children: [
          pw.Expanded(child: buildTitledCell('LINEA TRANSPORTISTA:', data.lineaTransportista)),
          pw.Expanded(child: buildTitledCell('TEL (INCLUIR LADA):', data.tel)),
        ]),
        // ¡FILA DE FLETES ELIMINADA DE AQUÍ PARA AHORRAR ESPACIO!
      ],
    );
  }

  static pw.Widget _buildCargaTable(pw.Context context, List<CargaItem> carga, String titleText) {
    final headerTextStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white);

    final totalPallets = carga.fold<int>(0, (sum, item) => sum + item.pallets);
    final totalCajas = carga.fold<int>(0, (sum, item) => sum + item.cajas);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          alignment: pw.Alignment.center,
          color: PdfColors.lightBlue800,
          child: pw.Text("DATOS DE LA CARGA - $titleText", style: headerTextStyle),
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
            pw.TableRow(
              repeat: true, 
              decoration: const pw.BoxDecoration(color: PdfColors.lightBlue100),
              children: [
                _cellHeader('PRODUCTO'),
                _cellHeader('ETIQUETAS'),
                _cellHeader('TAMAÑO'),
                _cellHeader('No. PALLETS'),
                _cellHeader('CAJAS'),
              ],
            ),
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

  static pw.Widget _cell(String text) => pw.Container(
        padding: const pw.EdgeInsets.all(4),
        alignment: pw.Alignment.centerLeft,
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
      );

  static pw.Widget _cellHeader(String text) => pw.Container(
        padding: const pw.EdgeInsets.all(4),
        alignment: pw.Alignment.center,
        child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
      );

  static pw.Widget _emptyCell() => pw.Container(
        height: 18,
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.8))),
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
        child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      );

  static pw.Widget _buildAdditionalText() {
    final style = const pw.TextStyle(fontSize: 8);
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
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround, 
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _signatureBox(context, 'EMBARCÓ (NOMBRE Y FIRMA)', data.embarcoNombre, data.embarcoFirmaBytes),
        _signatureBox(context, 'RECIBIÓ (NOMBRE Y FIRMA)', data.recibioNombre, data.recibioFirmaBytes),
      ],
    );
  }

  static pw.Widget _signatureBox(pw.Context context, String title, String name, Uint8List? signatureBytes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (signatureBytes != null && signatureBytes.isNotEmpty)
          pw.Transform.translate(
            offset: const PdfPoint(0, -5),
            // --- FIRMA MÁS PEQUEÑA PARA AHORRAR ESPACIO (de 65 a 45) ---
            child: pw.Image(pw.MemoryImage(signatureBytes), height: 45, width: 130, fit: pw.BoxFit.contain),
          )
        else
          pw.SizedBox(height: 45, width: 130), // <--- REDUCIDO AQUÍ TAMBIÉN
        pw.Container(width: 160, height: 1, color: PdfColors.black),
        pw.SizedBox(height: 3),
        pw.Text(name, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
        pw.Text(title, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
      ],
    );
  }

  static pw.Widget _buildTrailerDiagram(pw.Context context, Map<String, String> layout) {
    final rows = <pw.TableRow>[];
    const double cellHeight = 35.0; // <--- ALTURA DEL DIAGRAMA REDUCIDA DE 35 A 28 PARA REGALAR ESPACIO

    for (int i = 0; i < 15; i++) {
      final index1 = i * 2;
      final index2 = i * 2 + 1;

      rows.add(pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          pw.Container(height: cellHeight, alignment: pw.Alignment.center, child: pw.Text('${index1 + 1}', style: const pw.TextStyle(fontSize: 8))),
          pw.Container(
              height: cellHeight,
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              alignment: pw.Alignment.center,
              child: pw.Text(layout[index1.toString()] ?? '', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center, maxLines: 3)),
          pw.Container(
              height: cellHeight,
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              alignment: pw.Alignment.center,
              child: pw.Text(layout[index2.toString()] ?? '', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center, maxLines: 3)),
          pw.Container(height: cellHeight, alignment: pw.Alignment.center, child: pw.Text('${index2 + 1}', style: const pw.TextStyle(fontSize: 8))),
        ],
      ));
    }

    return pw.Column(
      children: [
        pw.Text('DIFUSOR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: const {0: pw.IntrinsicColumnWidth(), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1), 3: pw.IntrinsicColumnWidth()},
          children: rows,
        ),
        pw.SizedBox(height: 4),
        pw.Text('PUERTAS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
      ],
    );
  }
}