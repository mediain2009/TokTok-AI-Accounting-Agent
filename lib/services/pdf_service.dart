import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models.dart';

class PdfService {
  static final _numFmt = NumberFormat('#,###', 'ko_KR');
  static String _f(int n) => _numFmt.format(n);

  static Future<void> printDocument({
    required Document doc,
    required List<DocumentItem> items,
    CompanyInfo? company,
  }) async {
    final font     = await PdfGoogleFonts.notoSansKRRegular();
    final fontBold = await PdfGoogleFonts.notoSansKRBold();

    final base    = pw.TextStyle(font: font,     fontSize: 8.5);
    final bold    = pw.TextStyle(font: fontBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold);
    final titleSt = pw.TextStyle(font: fontBold, fontSize: 20, fontWeight: pw.FontWeight.bold);
    final totalSt = pw.TextStyle(font: fontBold, fontSize: 13, fontWeight: pw.FontWeight.bold);

    final pdf = pw.Document();

    if (doc.docType == '입금표') {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(
                child: _buildReceipt(
                  doc: doc, company: company,
                  base: base, bold: bold, titleSt: titleSt,
                  c: PdfColors.blue800,
                  copyLabel: '공급받는자\n보  관  용',
                ),
              ),
              pw.SizedBox(height: 4),
              _dashedLine(),
              pw.SizedBox(height: 4),
              pw.Expanded(
                child: _buildReceipt(
                  doc: doc, company: company,
                  base: base, bold: bold, titleSt: titleSt,
                  c: PdfColors.red800,
                  copyLabel: '공  급  자\n보  관  용',
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(child: pw.Text(doc.docType, style: titleSt)),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text(
                '문서번호: ${doc.docNo}   |   날짜: ${doc.docDate}', style: base)),
              pw.SizedBox(height: 14),
              pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                if (company != null)
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500)),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text('[ 공급자 ]', style: bold),
                        pw.SizedBox(height: 4),
                        _infoRow('상호', company.companyName, base),
                        _infoRow('대표자', company.repName, base),
                        _infoRow('사업자번호', company.businessNo, base),
                        _infoRow('주소', company.address, base),
                        _infoRow('전화', company.phone, base),
                      ]),
                    ),
                  ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500)),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('[ 공급받는자 ]', style: bold),
                      pw.SizedBox(height: 4),
                      _infoRow('상호', doc.customerName, base),
                      if (doc.customerBizNo.isNotEmpty) _infoRow('사업자번호', doc.customerBizNo, base),
                      if (doc.customerContact.isNotEmpty) _infoRow('연락처', doc.customerContact, base),
                      if (doc.customerAddress.isNotEmpty) _infoRow('주소', doc.customerAddress, base),
                    ]),
                  ),
                ),
              ]),
              pw.SizedBox(height: 14),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FixedColumnWidth(40),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: ['품목명','수량','단가','공급가액','세액']
                        .map((t) => _th(t, bold)).toList(),
                  ),
                  ...items.map((it) => pw.TableRow(children: [
                    _td(it.itemName,         base, pw.TextAlign.left),
                    _td('${it.quantity}',    base, pw.TextAlign.center),
                    _td(_f(it.unitPrice),    base, pw.TextAlign.right),
                    _td(_f(it.supplyAmount), base, pw.TextAlign.right),
                    _td(_f(it.taxAmount),    base, pw.TextAlign.right),
                  ])),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Text('공급가액: ${_f(doc.supplyAmount)}원', style: base),
                pw.SizedBox(width: 14),
                pw.Text('세액: ${_f(doc.taxAmount)}원', style: base),
                pw.SizedBox(width: 14),
                pw.Text('합계: ${_f(doc.totalAmount)}원', style: totalSt),
              ]),
              if (doc.note.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text('비고: ${doc.note}', style: base),
              ],
            ],
          ),
        ),
      );
    }

    final pdfBytes = await pdf.save();
    final docsDir  = await getApplicationDocumentsDirectory();
    final dateStr  = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '${doc.docType}_${doc.docNo}_$dateStr.pdf';
    await File('${docsDir.path}\\$fileName').writeAsBytes(pdfBytes);
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: '${doc.docType}_${doc.docNo}',
    );
  }

  // ── 점선 구분선 ─────────────────────────────────────────────────────
  static pw.Widget _dashedLine() {
    return pw.Row(
      children: List.generate(110, (_) => pw.Expanded(
        child: pw.Container(
          height: 1,
          margin: const pw.EdgeInsets.symmetric(horizontal: 1.2),
          color: PdfColors.black,
        ),
      )),
    );
  }

  // ── 입금표 한 장 ──────────────────────────────────────────────────────
  static pw.Widget _buildReceipt({
    required Document doc,
    required CompanyInfo? company,
    required pw.TextStyle base,
    required pw.TextStyle bold,
    required pw.TextStyle titleSt,
    required PdfColor c,
    required String copyLabel,
  }) {
    final side = pw.BorderSide(color: c, width: 0.8);
    final bAll = pw.Border.all(color: c, width: 0.8);
    final bBtm = pw.Border(bottom: side);
    final bRgt = pw.Border(right: side);

    String year = '', month = '', day = '';
    if (doc.docDate.length >= 10) {
      year  = doc.docDate.substring(0, 4);
      month = doc.docDate.substring(5, 7);
      day   = doc.docDate.substring(8, 10);
    }

    pw.Widget vDiv() => pw.Container(width: 0.8, color: c);

    // 셀 래퍼 (라벨용 고정폭)
    pw.Widget lbl(String t, double w, {bool rBorder = true, bool bBorder = false}) =>
        pw.Container(
          width: w,
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              right:  rBorder ? side : pw.BorderSide.none,
              bottom: bBorder ? side : pw.BorderSide.none,
            ),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(t, style: base, textAlign: pw.TextAlign.center),
        );

    // 값 셀 (남은 너비 채움)
    pw.Widget val(String t, {bool rBorder = false, pw.TextAlign align = pw.TextAlign.left}) =>
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: pw.BoxDecoration(border: rBorder ? bRgt : null),
            child: pw.Text(t, style: base, textAlign: align),
          ),
        );

    return pw.Container(
      decoration: pw.BoxDecoration(border: bAll),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [

          // ── 제목 ──────────────────────────────────────────────────
          pw.Container(
            decoration: pw.BoxDecoration(border: bBtm),
            padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
            child: pw.Row(children: [
              pw.Expanded(child: pw.SizedBox()),
              pw.Text('입    금    표', style: titleSt.copyWith(color: c)),
              pw.Expanded(
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('( $copyLabel )',
                      style: base.copyWith(fontSize: 8, color: c)),
                ),
              ),
            ]),
          ),

          // ── 귀하 ──────────────────────────────────────────────────
          pw.Container(
            decoration: pw.BoxDecoration(border: bBtm),
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            child: pw.Center(child: pw.Text('귀    하', style: base)),
          ),

          // ── 공급자 (4행 왼쪽 라벨 세로 병합) ─────────────────────
          pw.SizedBox(
            height: 72,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 공급자 라벨 (우측+하단 테두리)
                pw.Container(
                  width: 38,
                  decoration: pw.BoxDecoration(
                    border: pw.Border(right: side, bottom: side),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text('공 급 자', style: base, textAlign: pw.TextAlign.center),
                ),
                // 공급자 정보 4행
                pw.Expanded(
                  child: pw.Column(children: [
                    // 등록번호
                    pw.Container(
                      height: 18,
                      decoration: pw.BoxDecoration(border: bBtm),
                      child: pw.Row(children: [
                        lbl('등  록  번  호', 68),
                        val(company?.businessNo ?? ''),
                      ]),
                    ),
                    // 상호(법인명) / 성명
                    pw.Container(
                      height: 18,
                      decoration: pw.BoxDecoration(border: bBtm),
                      child: pw.Row(children: [
                        lbl('상호(법인명)', 68),
                        val(company?.companyName ?? '', rBorder: true),
                        lbl('성  명', 34),
                        pw.Container(
                          width: 68,
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                          child: pw.Text('${company?.repName ?? ''}   인', style: base),
                        ),
                      ]),
                    ),
                    // 사업장주소
                    pw.Container(
                      height: 18,
                      decoration: pw.BoxDecoration(border: bBtm),
                      child: pw.Row(children: [
                        lbl('사 업 장 주 소', 68),
                        val(company?.address ?? ''),
                      ]),
                    ),
                    // 업태 / 종목
                    pw.Container(
                      height: 18,
                      decoration: pw.BoxDecoration(border: bBtm),
                      child: pw.Row(children: [
                        lbl('업          태', 68),
                        val(company?.bizType ?? '', rBorder: true),
                        lbl('종  목', 34),
                        pw.Container(
                          width: 68,
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                          child: pw.Text(company?.bizItem ?? '', style: base),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          // ── 작성/공급가액/세액/비고 헤더 ─────────────────────────
          pw.SizedBox(
            height: 36,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 작성 (2단: 상단 "작성" + 하단 "년/월/일")
                pw.Container(
                  width: 108,
                  decoration: pw.BoxDecoration(border: bRgt),
                  child: pw.Column(children: [
                    pw.Container(
                      height: 18,
                      decoration: pw.BoxDecoration(border: bBtm),
                      alignment: pw.Alignment.center,
                      child: pw.Text('작        성', style: base),
                    ),
                    pw.Expanded(
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Expanded(child: pw.Center(child: pw.Text('년', style: base))),
                          vDiv(),
                          pw.Expanded(child: pw.Center(child: pw.Text('월', style: base))),
                          vDiv(),
                          pw.Expanded(child: pw.Center(child: pw.Text('일', style: base))),
                        ],
                      ),
                    ),
                  ]),
                ),
                // 공급가액
                pw.Expanded(
                  flex: 36,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(border: bRgt),
                    alignment: pw.Alignment.center,
                    child: pw.Text('공  급  가  액', style: base),
                  ),
                ),
                // 세액
                pw.Expanded(
                  flex: 27,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(border: bRgt),
                    alignment: pw.Alignment.center,
                    child: pw.Text('세        액', style: base),
                  ),
                ),
                // 비고
                pw.Expanded(
                  flex: 15,
                  child: pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Text('비  고', style: base),
                  ),
                ),
              ],
            ),
          ),

          // ── 날짜/금액 데이터 행 ───────────────────────────────────
          pw.Container(
            height: 22,
            decoration: pw.BoxDecoration(border: bBtm),
            child: pw.Row(children: [
              pw.Container(
                width: 108,
                decoration: pw.BoxDecoration(border: bRgt),
                child: pw.Row(children: [
                  pw.Expanded(child: pw.Center(child: pw.Text(year,  style: base))),
                  vDiv(),
                  pw.Expanded(child: pw.Center(child: pw.Text(month, style: base))),
                  vDiv(),
                  pw.Expanded(child: pw.Center(child: pw.Text(day,   style: base))),
                ]),
              ),
              pw.Expanded(
                flex: 36,
                child: pw.Container(
                  decoration: pw.BoxDecoration(border: bRgt),
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                  child: pw.Text(_f(doc.supplyAmount), style: base),
                ),
              ),
              pw.Expanded(
                flex: 27,
                child: pw.Container(
                  decoration: pw.BoxDecoration(border: bRgt),
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                  child: pw.Text(_f(doc.taxAmount), style: base),
                ),
              ),
              pw.Expanded(flex: 15, child: pw.SizedBox()),
            ]),
          ),

          // ── 합계 ──────────────────────────────────────────────────
          pw.Container(
            height: 22,
            decoration: pw.BoxDecoration(border: bBtm),
            child: pw.Row(children: [
              pw.Container(
                width: 108,
                decoration: pw.BoxDecoration(border: bRgt),
                alignment: pw.Alignment.center,
                child: pw.Text('합        계', style: bold),
              ),
              pw.Expanded(
                flex: 36,
                child: pw.Container(
                  decoration: pw.BoxDecoration(border: bRgt),
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                  child: pw.Text(_f(doc.supplyAmount), style: bold),
                ),
              ),
              pw.Expanded(
                flex: 27,
                child: pw.Container(
                  decoration: pw.BoxDecoration(border: bRgt),
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                  child: pw.Text(_f(doc.taxAmount), style: bold),
                ),
              ),
              pw.Expanded(flex: 15, child: pw.SizedBox()),
            ]),
          ),

          // ── 내용 (남은 공간 채움) ─────────────────────────────────
          pw.Expanded(
            child: pw.Container(
              decoration: pw.BoxDecoration(border: bBtm),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    width: 38,
                    decoration: pw.BoxDecoration(border: bRgt),
                    alignment: pw.Alignment.center,
                    child: pw.Text('내  용', style: base),
                  ),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: pw.Text(doc.note, style: base),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 영수자 ────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: pw.Row(children: [
              pw.Text('영  수  자 :', style: base),
              pw.Expanded(child: pw.SizedBox()),
              pw.Text('(인)', style: base),
            ]),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value, pw.TextStyle style) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.RichText(text: pw.TextSpan(children: [
          pw.TextSpan(text: '$label: ', style: style.copyWith(color: PdfColors.grey700)),
          pw.TextSpan(text: value, style: style),
        ])),
      );

  static pw.Widget _th(String t, pw.TextStyle style) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(t, style: style, textAlign: pw.TextAlign.center),
      );

  static pw.Widget _td(String t, pw.TextStyle style, pw.TextAlign align) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(t, style: style, textAlign: align),
      );
}
