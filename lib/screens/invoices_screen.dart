import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db_helper.dart';
import '../models.dart';
import '../utils.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _tabs = ['미발행', '종이', '전자'];

  String _direction = '매출';
  String _start = monthStart();
  String _end   = today();

  List<Invoice> _invoices = [];
  List<Partner> _partners = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _load();
    });
    _loadPartners();
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPartners() async {
    final list = await DbHelper.getPartners();
    setState(() => _partners = list);
  }

  Future<void> _load() async {
    final list = await DbHelper.getInvoices(
      direction: _direction,
      issueType: _tabs[_tabCtrl.index],
      start: _start,
      end: _end,
    );
    setState(() => _invoices = list);
  }

  Future<void> _pickDate(bool isStart) async {
    final init = DateTime.tryParse(isStart ? _start : _end) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _start = fmtDate(picked); else _end = fmtDate(picked);
      });
      await _load();
    }
  }

  Future<void> _showCreateDialog(String direction) async {
    await _loadPartners();
    if (!mounted) return;

    String selType    = '과세';
    String selBill    = '영수';
    int? selPartnerId;
    final memoC       = TextEditingController();

    // Item rows
    final List<Map<String, dynamic>> itemRows = [
      {'name': TextEditingController(), 'qty': TextEditingController(text: '1'), 'price': TextEditingController(text: '0')},
    ];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) {
          int totalSupply = 0, totalTax = 0;
          for (final row in itemRows) {
            final qty   = int.tryParse(row['qty'].text)   ?? 0;
            final price = int.tryParse(row['price'].text) ?? 0;
            final supply = qty * price;
            final tax    = selType == '과세' ? supply ~/ 10 : 0;
            totalSupply += supply;
            totalTax    += tax;
          }

          return AlertDialog(
            title: Text('$direction 세금계산서 작성'),
            content: SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단 필드들
                    Row(children: [
                      Expanded(child: _dlgDropdown('유형', ['과세','영세','면세'], selType,
                          (v) => setDlg(() => selType = v!))),
                      const SizedBox(width: 10),
                      Expanded(child: _dlgDropdown('영수/청구', ['영수','청구'], selBill,
                          (v) => setDlg(() => selBill = v!))),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: '거래처', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                          value: selPartnerId,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('-- 선택 --')),
                            ..._partners.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                          ],
                          onChanged: (v) => setDlg(() => selPartnerId = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: memoC,
                          decoration: const InputDecoration(labelText: '적요', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // 품목 테이블 헤더
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
                          children: ['품목명','수량','단가','공급가액','세액','']
                            .map((h) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                              child: Text(h, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            )).toList(),
                        ),
                        ...itemRows.asMap().entries.map((entry) {
                          final i = entry.key;
                          final row = entry.value;
                          return TableRow(children: [
                            _itemCell(row['name']),
                            _numCell(row['qty'], onChanged: (_) => setDlg(() {})),
                            _numCell(row['price'], onChanged: (_) => setDlg(() {})),
                            _readonlyCell(_calcSupply(row, selType)),
                            _readonlyCell(_calcTax(row, selType)),
                            itemRows.length > 1
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () => setDlg(() => itemRows.removeAt(i)),
                                  padding: EdgeInsets.zero,
                                )
                              : const SizedBox.shrink(),
                          ]);
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('공급가액: ${fmtNum(totalSupply)}  |  세액: ${fmtNum(totalTax)}  |  합계: ${fmtNum(totalSupply + totalTax)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    return InvoiceItem(
                      invoiceId: 0,
                      itemName: row['name'].text,
                      quantity: qty,
                      unitPrice: price,
                      supplyAmount: supply,
                      taxAmount: tax,
                    );
                  }).toList();

                  final inv = Invoice(
                    invoiceDate: today(),
                    type: selType,
                    direction: direction,
                    partnerId: selPartnerId,
                    memo: memoC.text,
                    billType: selBill,
                  );
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

  int _calcSupplyInt(Map<String, dynamic> row, String type) {
    final qty   = int.tryParse(row['qty'].text)   ?? 0;
    final price = int.tryParse(row['price'].text) ?? 0;
    return qty * price;
  }

  String _calcSupply(Map<String, dynamic> row, String type) =>
      fmtNum(_calcSupplyInt(row, type));

  String _calcTax(Map<String, dynamic> row, String type) {
    final supply = _calcSupplyInt(row, type);
    return fmtNum(type == '과세' ? supply ~/ 10 : 0);
  }

  Widget _itemCell(TextEditingController c) => Padding(
    padding: const EdgeInsets.all(4),
    child: TextFormField(
      controller: c,
      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
    ),
  );

  Widget _numCell(TextEditingController c, {ValueChanged<String>? onChanged}) => Padding(
    padding: const EdgeInsets.all(4),
    child: TextFormField(
      controller: c,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
    ),
  );

  Widget _readonlyCell(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    child: Text(text, style: const TextStyle(fontSize: 13)),
  );

  Widget _dlgDropdown(String label, List<String> items, String val, ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
        value: val,
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: onChanged,
      );

  Future<void> _showIssueDialog(Invoice inv) async {
    String selType  = '종이';
    final approvalC = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('발행'),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selType,
                  decoration: const InputDecoration(labelText: '발행 유형', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: '종이', child: Text('종이발행')),
                    DropdownMenuItem(value: '전자', child: Text('전자발행')),
                  ],
                  onChanged: (v) => setDlg(() => selType = v!),
                ),
                if (selType == '전자') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: approvalC,
                    decoration: const InputDecoration(
                      labelText: '국세청 승인번호 (선택)',
                      helperText: '입력 시 완료 처리, 미입력 시 임시 상태',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                await DbHelper.issueInvoice(inv.id!, selType, approvalC.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
              },
              child: const Text('발행'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSupply = _invoices.fold(0, (s, i) => s + i.supplyAmount);
    final totalTax    = _invoices.fold(0, (s, i) => s + i.taxAmount);
    final totalAmt    = _invoices.fold(0, (s, i) => s + i.totalAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: Colors.white,
          child: Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('발행', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('세금/거래/지출 > 세금계산서 > 발행',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateDialog('매출'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('매출 작성'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showCreateDialog('매입'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('매입 작성'),
              ),
            ],
          ),
        ),

        // Filter bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            children: [
              // 매출/매입 토글
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '매출', label: Text('매출')),
                  ButtonSegment(value: '매입', label: Text('매입')),
                ],
                selected: {_direction},
                onSelectionChanged: (s) {
                  setState(() => _direction = s.first);
                  _load();
                },
              ),
              const SizedBox(width: 16),
              // Date range
              InkWell(
                onTap: () => _pickDate(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_start, style: const TextStyle(fontSize: 13)),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('~')),
              InkWell(
                onTap: () => _pickDate(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_end, style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _load, child: const Text('조회')),
            ],
          ),
        ),

        // Tabs + Table
        Expanded(
          child: Column(
            children: [
              TabBar(
                controller: _tabCtrl,
                isScrollable: false,
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
                        DataColumn(label: Text('사업자번호')),
                        DataColumn(label: Text('공급가액'), numeric: true),
                        DataColumn(label: Text('세액'), numeric: true),
                        DataColumn(label: Text('합계'), numeric: true),
                        DataColumn(label: Text('형식')),
                        DataColumn(label: Text('상태')),
                        DataColumn(label: Text('액션')),
                      ],
                      rows: _invoices.isEmpty
                          ? [const DataRow(cells: [
                              DataCell(Text('조회된 내역이 없습니다.',
                                  style: TextStyle(color: Colors.grey))),
                              DataCell(Text('')), DataCell(Text('')), DataCell(Text('')),
                              DataCell(Text('')), DataCell(Text('')), DataCell(Text('')),
                              DataCell(Text('')), DataCell(Text('')), DataCell(Text('')),
                            ])]
                          : _invoices.map((inv) => DataRow(cells: [
                              DataCell(Text(inv.invoiceDate, style: const TextStyle(fontSize: 12))),
                              DataCell(typeBadge(inv.type)),
                              DataCell(Text(inv.partnerName ?? '-', style: const TextStyle(fontSize: 12))),
                              DataCell(Text(inv.businessNo ?? '-', style: const TextStyle(fontSize: 11, color: Colors.grey))),
                              DataCell(Text(fmtNum(inv.supplyAmount), style: const TextStyle(fontSize: 12))),
                              DataCell(Text(fmtNum(inv.taxAmount), style: const TextStyle(fontSize: 12))),
                              DataCell(Text(fmtNum(inv.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataCell(Text(inv.billType, style: const TextStyle(fontSize: 11))),
                              DataCell(Text(inv.txStatus.isEmpty ? '-' : inv.txStatus, style: const TextStyle(fontSize: 11, color: Colors.blueGrey))),
                              DataCell(Row(children: [
                                if (_tabs[_tabCtrl.index] == '미발행')
                                  TextButton(
                                    onPressed: () => _showIssueDialog(inv),
                                    child: const Text('발행', style: TextStyle(fontSize: 12)),
                                  ),
                                TextButton(
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('삭제'),
                                        content: const Text('삭제하시겠습니까?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await DbHelper.deleteInvoice(inv.id!);
                                      await _load();
                                    }
                                  },
                                  child: const Text('삭제', style: TextStyle(fontSize: 12, color: Colors.red)),
                                ),
                              ])),
                            ])).toList(),
                    ),
                  ),
                ),
              ),
              // Footer totals
              if (_invoices.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${_invoices.length}건  |  공급가액 ${fmtNum(totalSupply)}  |  세액 ${fmtNum(totalTax)}  |  합계 ${fmtNum(totalAmt)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
