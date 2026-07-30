import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../models.dart';
import '../services/pdf_service.dart';

final _numFmt = NumberFormat('#,###', 'ko_KR');
String _f(int n) => _numFmt.format(n);

// ─── DocumentsScreen ──────────────────────────────────────────────────────────
class DocumentsScreen extends StatefulWidget {
  final String docType; // 견적서 | 거래명세표 | 계산서 | 입금표
  final Map<String, dynamic>? pendingCreate; // AI 자동 입력 데이터
  final VoidCallback? onPendingConsumed;

  const DocumentsScreen({
    super.key,
    required this.docType,
    this.pendingCreate,
    this.onPendingConsumed,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<Document> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DocumentsScreen old) {
    super.didUpdateWidget(old);
    if (old.docType != widget.docType) _load();
    // AI 데이터로 폼 자동 열기
    if (widget.pendingCreate != null && widget.pendingCreate != old.pendingCreate) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openFormWithData(widget.pendingCreate!));
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final docs = await DbHelper.getDocuments(widget.docType);
    setState(() { _docs = docs; _loading = false; });
  }

  Future<void> _delete(Document doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('${doc.docNo} 을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await DbHelper.deleteDocument(doc.id!);
      _load();
    }
  }

  Future<void> _openForm([Document? doc]) async {
    final company = await DbHelper.getCompanyInfo();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DocumentFormDialog(
        docType: widget.docType,
        company: company,
        existing: doc,
      ),
    );
    if (result == true) _load();
  }

  // AI 데이터로 폼 열기
  Future<void> _openFormWithData(Map<String, dynamic> data) async {
    widget.onPendingConsumed?.call();
    final company = await DbHelper.getCompanyInfo();
    if (!mounted) return;
    final customerName = data['customerName'] as String? ?? '';
    final rawItems = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DocumentFormDialog(
        docType: widget.docType,
        company: company,
        initialCustomerName: customerName,
        initialItems: rawItems,
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: Colors.white,
          child: Row(
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.docType,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${widget.docType} 목록을 조회합니다.',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 16),
                label: Text('${widget.docType} 작성'),
              ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _docs.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.description_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('${widget.docType}이(가) 없습니다.',
                            style: const TextStyle(color: Colors.grey)),
                      ]),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('문서번호')),
                            DataColumn(label: Text('날짜')),
                            DataColumn(label: Text('거래처')),
                            DataColumn(label: Text('공급가액'), numeric: true),
                            DataColumn(label: Text('세액'), numeric: true),
                            DataColumn(label: Text('합계'), numeric: true),
                            DataColumn(label: Text('상태')),
                            DataColumn(label: Text('관리')),
                          ],
                          rows: _docs.map((d) => DataRow(cells: [
                            DataCell(Text(d.docNo, style: const TextStyle(fontSize: 12))),
                            DataCell(Text(d.docDate)),
                            DataCell(Text(d.customerName)),
                            DataCell(Text(_f(d.supplyAmount))),
                            DataCell(Text(_f(d.taxAmount))),
                            DataCell(Text(_f(d.totalAmount),
                                style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(_StatusBadge(d.status)),
                            DataCell(Row(children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 18),
                                tooltip: '상세',
                                onPressed: () => _showDetail(d),
                              ),
                              IconButton(
                                icon: const Icon(Icons.publish, size: 18, color: Colors.blue),
                                tooltip: '발행',
                                onPressed: d.status == '발행' ? null : () async {
                                  await DbHelper.updateDocumentStatus(d.id!, '발행');
                                  _load();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.print, size: 18, color: Colors.teal),
                                tooltip: '프린트',
                                onPressed: () => _print(d),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                tooltip: '삭제',
                                onPressed: () => _delete(d),
                              ),
                            ])),
                          ])).toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Future<void> _print(Document doc) async {
    try {
      final items   = await DbHelper.getDocumentItems(doc.id!);
      final company = await DbHelper.getCompanyInfo();
      await PdfService.printDocument(doc: doc, items: items, company: company);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('인쇄 오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showDetail(Document doc) async {
    final items = await DbHelper.getDocumentItems(doc.id!);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => _DocumentDetailDialog(doc: doc, items: items),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final color = status == '발행' ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Document Form Dialog ─────────────────────────────────────────────────────
class _DocumentFormDialog extends StatefulWidget {
  final String docType;
  final CompanyInfo? company;
  final Document? existing;
  final String initialCustomerName;
  final List<Map<String, dynamic>> initialItems; // [{name, qty, price}]

  const _DocumentFormDialog({
    required this.docType,
    required this.company,
    this.existing,
    this.initialCustomerName = '',
    this.initialItems = const [],
  });

  @override
  State<_DocumentFormDialog> createState() => _DocumentFormDialogState();
}

class _DocumentFormDialogState extends State<_DocumentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _customerName    = TextEditingController();
  late final TextEditingController _customerBizNo   = TextEditingController();
  late final TextEditingController _customerAddress = TextEditingController();
  late final TextEditingController _customerContact = TextEditingController();
  late final TextEditingController _note            = TextEditingController();
  late final TextEditingController _docDate         = TextEditingController(
      text: DateTime.now().toString().substring(0, 10));

  // Item rows
  final List<_ItemRow> _items = [];

  bool _saving = false;
  bool _includeTax = true; // 과세 여부

  @override
  void initState() {
    super.initState();
    // AI 초기 데이터 적용
    if (widget.initialItems.isNotEmpty) {
      for (final item in widget.initialItems) {
        final row = _ItemRow();
        row.nameC.text  = (item['name']  ?? '').toString();
        row.qtyC.text   = (item['qty']   ?? 1).toString();
        row.priceC.text = (item['price'] ?? 0).toString();
        row.recalc(_includeTax);
        _items.add(row);
      }
    } else {
      _items.add(_ItemRow());
    }
    if (widget.initialCustomerName.isNotEmpty) {
      _customerName.text = widget.initialCustomerName;
    }
  }

  @override
  void dispose() {
    for (final c in [_customerName, _customerBizNo, _customerAddress, _customerContact, _note, _docDate]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(_ItemRow()));
  void _removeItem(int i) { if (_items.length > 1) setState(() => _items.removeAt(i)); }

  int get _supplyTotal => _items.fold(0, (s, r) => s + r.supplyAmount);
  int get _taxTotal    => _includeTax ? _items.fold(0, (s, r) => s + r.taxAmount) : 0;
  int get _grandTotal  => _supplyTotal + _taxTotal;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final docNo = await DbHelper.nextDocNo(widget.docType);
    final doc = Document(
      docType:         widget.docType,
      docNo:           docNo,
      docDate:         _docDate.text,
      customerName:    _customerName.text.trim(),
      customerBizNo:   _customerBizNo.text.trim(),
      customerAddress: _customerAddress.text.trim(),
      customerContact: _customerContact.text.trim(),
      supplyAmount:    _supplyTotal,
      taxAmount:       _taxTotal,
      totalAmount:     _grandTotal,
      note:            _note.text.trim(),
    );

    final docItems = _items.map((r) => DocumentItem(
      docId:        0,
      itemName:     r.nameC.text.trim(),
      quantity:     int.tryParse(r.qtyC.text) ?? 0,
      unitPrice:    int.tryParse(r.priceC.text.replaceAll(',', '')) ?? 0,
      supplyAmount: r.supplyAmount,
      taxAmount:    _includeTax ? r.taxAmount : 0,
    )).toList();

    await DbHelper.insertDocument(doc, docItems);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.company;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(children: [
                  Text('${widget.docType} 작성',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ]),
                const Divider(),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // ── 공급자 정보 (회사 정보에서 자동 입력) ──
                      if (company != null) ...[
                        _sectionLabel('공급자 (자동)'),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(children: [
                            _infoChip('상호', company.companyName),
                            const SizedBox(width: 20),
                            _infoChip('대표자', company.repName),
                            const SizedBox(width: 20),
                            _infoChip('사업자번호', company.businessNo),
                            const SizedBox(width: 20),
                            Flexible(child: _infoChip('주소',
                                widget.docType == '거래명세표'
                                    ? company.currentAddress
                                    : company.address)),
                          ]),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── 공급받는자 ──
                      _sectionLabel('공급받는자'),
                      Row(children: [
                        Expanded(child: _tf('거래처명 *', _customerName, required: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _tf('사업자등록번호', _customerBizNo)),
                        const SizedBox(width: 12),
                        Expanded(child: _tf('연락처', _customerContact)),
                        const SizedBox(width: 12),
                        Expanded(child: _tf('주소', _customerAddress)),
                      ]),
                      const SizedBox(height: 12),

                      // ── 문서 기본 ──
                      _sectionLabel('문서 정보'),
                      Row(children: [
                        SizedBox(
                          width: 180,
                          child: TextFormField(
                            controller: _docDate,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: '날짜',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              suffixIcon: Icon(Icons.calendar_today, size: 16),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.tryParse(_docDate.text) ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2099),
                              );
                              if (picked != null) {
                                setState(() => _docDate.text = picked.toString().substring(0, 10));
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Row(children: [
                          const Text('부가세 포함', style: TextStyle(fontSize: 13)),
                          Switch(value: _includeTax,
                              onChanged: (v) => setState(() => _includeTax = v)),
                        ]),
                      ]),
                      const SizedBox(height: 16),

                      // ── 품목 ──
                      Row(children: [
                        _sectionLabel('품목'),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('행 추가'),
                        ),
                      ]),
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(3),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(2),
                          3: FlexColumnWidth(2),
                          4: FlexColumnWidth(2),
                          5: FixedColumnWidth(40),
                        },
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(color: Color(0xFFF8F9FA)),
                            children: [
                              _th('품목명'), _th('수량'), _th('단가'),
                              _th('공급가액'), _th('세액'), _th(''),
                            ],
                          ),
                          for (int i = 0; i < _items.length; i++)
                            TableRow(children: [
                              _cell(_items[i].nameC),
                              _cell(_items[i].qtyC, onChanged: (_) => setState(() => _items[i].recalc(_includeTax))),
                              _cell(_items[i].priceC, onChanged: (_) => setState(() => _items[i].recalc(_includeTax))),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: Text(_f(_items[i].supplyAmount),
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: Text(_f(_items[i].taxAmount),
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                                onPressed: () => _removeItem(i),
                                padding: EdgeInsets.zero,
                              ),
                            ]),
                        ],
                      ),

                      const Divider(height: 24),

                      // ── 합계 ──
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        _totalChip('공급가액', _supplyTotal),
                        const SizedBox(width: 16),
                        _totalChip('세액', _taxTotal),
                        const SizedBox(width: 16),
                        _totalChip('합계', _grandTotal, highlight: true),
                      ]),
                      const SizedBox(height: 12),

                      // ── 비고 ──
                      _tf('비고', _note),
                    ]),
                  ),
                ),

                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save, size: 16),
                    label: const Text('저장'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A2236))),
  );

  Widget _tf(String label, TextEditingController c, {bool required = false}) =>
      TextFormField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        validator: required ? (v) => (v == null || v.isEmpty) ? '필수 입력' : null : null,
      );

  Widget _infoChip(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
      Text(value.isEmpty ? '-' : value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    ],
  );

  TableCell _th(String t) => TableCell(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    ),
  );

  TableCell _cell(TextEditingController c, {ValueChanged<String>? onChanged}) => TableCell(
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: TextField(
        controller: c,
        onChanged: onChanged,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    ),
  );

  Widget _totalChip(String label, int val, {bool highlight = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text(_f(val),
          style: TextStyle(
            fontSize: highlight ? 18 : 14,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: highlight ? const Color(0xFF0D1B33) : Colors.black87,
          )),
    ],
  );
}

// ─── Item Row State ───────────────────────────────────────────────────────────
class _ItemRow {
  final nameC  = TextEditingController();
  final qtyC   = TextEditingController(text: '1');
  final priceC = TextEditingController(text: '0');

  int supplyAmount = 0;
  int taxAmount    = 0;

  void recalc(bool includeTax) {
    final qty   = int.tryParse(qtyC.text) ?? 0;
    final price = int.tryParse(priceC.text.replaceAll(',', '')) ?? 0;
    supplyAmount = qty * price;
    taxAmount    = includeTax ? (supplyAmount * 0.1).round() : 0;
  }

  void dispose() {
    nameC.dispose();
    qtyC.dispose();
    priceC.dispose();
  }
}

// ─── Document Detail Dialog ───────────────────────────────────────────────────
class _DocumentDetailDialog extends StatelessWidget {
  final Document doc;
  final List<DocumentItem> items;

  const _DocumentDetailDialog({required this.doc, required this.items});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('${doc.docType} 상세 — ${doc.docNo}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
              const Divider(),

              // 기본 정보
              Wrap(spacing: 24, runSpacing: 8, children: [
                _field('날짜', doc.docDate),
                _field('거래처', doc.customerName),
                if (doc.customerBizNo.isNotEmpty) _field('사업자번호', doc.customerBizNo),
                if (doc.customerContact.isNotEmpty) _field('연락처', doc.customerContact),
                if (doc.customerAddress.isNotEmpty) _field('주소', doc.customerAddress),
                _field('상태', doc.status),
              ]),
              const SizedBox(height: 16),

              // 품목 테이블
              const Text('품목', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(2),
                      3: FlexColumnWidth(2),
                      4: FlexColumnWidth(2),
                    },
                    border: TableBorder.all(color: Colors.grey.shade200),
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: Color(0xFFF8F9FA)),
                        children: ['품목명', '수량', '단가', '공급가액', '세액']
                            .map((t) => Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ))
                            .toList(),
                      ),
                      ...items.map((it) => TableRow(
                        children: [
                          _td(it.itemName),
                          _td('${it.quantity}'),
                          _td(_f(it.unitPrice)),
                          _td(_f(it.supplyAmount)),
                          _td(_f(it.taxAmount)),
                        ],
                      )),
                    ],
                  ),
                ),
              ),

              const Divider(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('공급가액: ${_f(doc.supplyAmount)}   세액: ${_f(doc.taxAmount)}   ',
                    style: const TextStyle(fontSize: 13)),
                Text('합계: ${_f(doc.totalAmount)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),

              if (doc.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('비고: ${doc.note}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      Text(value, style: const TextStyle(fontSize: 13)),
    ],
  );

  Widget _td(String t) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text(t, style: const TextStyle(fontSize: 12)),
  );
}
