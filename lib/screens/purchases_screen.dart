import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db_helper.dart';
import '../models.dart';
import '../utils.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _tabs = ['전체', '전자', '종이'];

  String _start = monthStart();
  String _end   = today();
  List<Invoice>  _invoices = [];
  List<Partner>  _partners = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) _load(); });
    _loadPartners();
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadPartners() async {
    final list = await DbHelper.getPartners();
    setState(() => _partners = list);
  }

  Future<void> _load() async {
    final tab = _tabs[_tabCtrl.index];
    final list = await DbHelper.getInvoices(
      direction: '매입',
      issueType: tab,
      start: _start,
      end: _end,
    );
    setState(() => _invoices = list);
  }

  Future<void> _pickDate(bool isStart) async {
    final init = DateTime.tryParse(isStart ? _start : _end) ?? DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: init,
        firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) {
      setState(() { if (isStart) _start = fmtDate(picked); else _end = fmtDate(picked); });
      await _load();
    }
  }

  Future<void> _showCreateDialog() async {
    await _loadPartners();
    if (!mounted) return;

    String selType = '과세';
    String selBill = '영수';
    int? selPartnerId;
    final memoC = TextEditingController();

    final List<Map<String, dynamic>> itemRows = [
      {'name': TextEditingController(), 'qty': TextEditingController(text: '1'), 'price': TextEditingController(text: '0')},
    ];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) {
          return AlertDialog(
            title: const Text('매입 세금계산서 작성'),
            content: SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: DropdownButtonFormField<String>(
                        value: selType,
                        decoration: const InputDecoration(labelText: '유형', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                        items: ['과세','영세','면세'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setDlg(() => selType = v!),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: DropdownButtonFormField<String>(
                        value: selBill,
                        decoration: const InputDecoration(labelText: '영수/청구', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                        items: ['영수','청구'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setDlg(() => selBill = v!),
                      )),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: DropdownButtonFormField<int>(
                        value: selPartnerId,
                        decoration: const InputDecoration(labelText: '거래처(공급자)', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('-- 선택 --')),
                          ..._partners.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                        ],
                        onChanged: (v) => setDlg(() => selPartnerId = v),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(
                        controller: memoC,
                        decoration: const InputDecoration(labelText: '적요', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                      )),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      const Text('품목', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => setDlg(() => itemRows.add({
                          'name': TextEditingController(),
                          'qty': TextEditingController(text: '1'),
                          'price': TextEditingController(text: '0'),
                        })),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('품목 추가'),
                      ),
                    ]),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(3), 1: FlexColumnWidth(1),
                        2: FlexColumnWidth(2), 3: FlexColumnWidth(2),
                        4: FlexColumnWidth(2), 5: FixedColumnWidth(40),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFFF8F9FA)),
                          children: ['품목명','수량','단가','공급가액','세액',''].map((h) =>
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                              child: Text(h, style: const TextStyle(fontSize: 12, color: Colors.grey)))).toList(),
                        ),
                        ...itemRows.asMap().entries.map((e) {
                          final i = e.key;
                          final row = e.value;
                          final qty   = int.tryParse(row['qty'].text)   ?? 0;
                          final price = int.tryParse(row['price'].text) ?? 0;
                          final supply = qty * price;
                          final tax    = selType == '과세' ? supply ~/ 10 : 0;
                          return TableRow(children: [
                            Padding(padding: const EdgeInsets.all(4), child: TextFormField(
                              controller: row['name'],
                              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
                            )),
                            Padding(padding: const EdgeInsets.all(4), child: TextFormField(
                              controller: row['qty'],
                              onChanged: (_) => setDlg(() {}),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
                            )),
                            Padding(padding: const EdgeInsets.all(4), child: TextFormField(
                              controller: row['price'],
                              onChanged: (_) => setDlg(() {}),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
                            )),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                              child: Text(fmtNum(supply))),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                              child: Text(fmtNum(tax))),
                            itemRows.length > 1
                              ? IconButton(icon: const Icon(Icons.close, size: 16), padding: EdgeInsets.zero,
                                  onPressed: () => setDlg(() => itemRows.removeAt(i)))
                              : const SizedBox.shrink(),
                          ]);
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                onPressed: () async {
                  final items = itemRows.map((row) {
                    final qty   = int.tryParse(row['qty'].text)   ?? 0;
                    final price = int.tryParse(row['price'].text) ?? 0;
                    final supply = qty * price;
                    final tax    = selType == '과세' ? supply ~/ 10 : 0;
                    return InvoiceItem(invoiceId: 0, itemName: row['name'].text,
                        quantity: qty, unitPrice: price, supplyAmount: supply, taxAmount: tax);
                  }).toList();
                  final inv = Invoice(invoiceDate: today(), type: selType, direction: '매입',
                      partnerId: selPartnerId, memo: memoC.text, billType: selBill);
                  await DbHelper.insertInvoice(inv, items);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                },
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSupply = _invoices.fold(0, (s, i) => s + i.supplyAmount);
    final totalTax    = _invoices.fold(0, (s, i) => s + i.taxAmount);
    final totalAmt    = _invoices.fold(0, (s, i) => s + i.totalAmount);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: Colors.white,
          child: Row(
            children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('매입조회', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('세금/거래/지출 > 세금계산서 > 매입조회',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('매입 작성'),
              ),
            ],
          ),
        ),

        if (_invoices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              _card('${_invoices.length}건', '총 건수'),
              const SizedBox(width: 8),
              _card(fmtNum(totalSupply), '공급가액 합계'),
              const SizedBox(width: 8),
              _card(fmtNum(totalTax), '세액 합계'),
              const SizedBox(width: 8),
              _card(fmtNum(totalAmt), '합계금액', red: true),
            ]),
          ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            InkWell(onTap: () => _pickDate(true), child: _dateBox(_start)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('~')),
            InkWell(onTap: () => _pickDate(false), child: _dateBox(_end)),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _load, child: const Text('조회')),
          ]),
        ),

        Expanded(
          child: Column(
            children: [
              TabBar(
                controller: _tabCtrl,
                labelColor: const Color(0xFF0D6EFD),
                indicatorColor: const Color(0xFF0D6EFD),
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
              Expanded(
                child: Card(
                  margin: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 12,
                      columns: const [
                        DataColumn(label: Text('작성일자')),
                        DataColumn(label: Text('유형')),
                        DataColumn(label: Text('거래처')),
                        DataColumn(label: Text('공급가액'), numeric: true),
                        DataColumn(label: Text('세액'), numeric: true),
                        DataColumn(label: Text('합계'), numeric: true),
                        DataColumn(label: Text('발행유형')),
                        DataColumn(label: Text('적요')),
                        DataColumn(label: Text('분류')),
                      ],
                      rows: _invoices.isEmpty
                          ? [DataRow(cells: List.generate(9, (i) => DataCell(
                              i == 0 ? const Text('조회된 내역이 없습니다.',
                                  style: TextStyle(color: Colors.grey)) : const Text(''))))]
                          : _invoices.map((inv) => DataRow(cells: [
                              DataCell(Text(inv.invoiceDate, style: const TextStyle(fontSize: 12))),
                              DataCell(typeBadge(inv.type)),
                              DataCell(Text(inv.partnerName ?? '-', style: const TextStyle(fontSize: 12))),
                              DataCell(Text(fmtNum(inv.supplyAmount), style: const TextStyle(fontSize: 12))),
                              DataCell(Text(fmtNum(inv.taxAmount), style: const TextStyle(fontSize: 12))),
                              DataCell(Text(fmtNum(inv.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataCell(issueBadge(inv.issueType)),
                              DataCell(Text(inv.memo.isEmpty ? '-' : inv.memo, style: const TextStyle(fontSize: 11))),
                              DataCell(Row(children: [
                                TextButton(
                                  onPressed: () async {
                                    await DbHelper.classifyPurchase(inv.id!, '전자');
                                    await _load();
                                  },
                                  child: const Text('전자저장', style: TextStyle(fontSize: 11)),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await DbHelper.classifyPurchase(inv.id!, '종이');
                                    await _load();
                                  },
                                  child: const Text('종이저장', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ),
                              ])),
                            ])).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(String value, String label, {bool red = false}) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
              color: red ? const Color(0xFFDC3545) : const Color(0xFF0D6EFD))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    ),
  );

  Widget _dateBox(String date) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
    child: Text(date, style: const TextStyle(fontSize: 13)),
  );
}
