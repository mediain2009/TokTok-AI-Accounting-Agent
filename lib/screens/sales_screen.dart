import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import '../utils.dart';

const _modifyReasons = [
  '착오에 의한 이중발급',
  '환입',
  '계약의 해제',
  '공급가액의 변동',
  '기재사항의 착오·정정',
  '내국신용장 사후 개설',
];

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _tabs = ['전체', '전자', '종이'];

  String _start = monthStart();
  String _end   = today();
  List<Invoice> _invoices = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) _load(); });
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final issueType = _tabs[_tabCtrl.index];
    final list = await DbHelper.getInvoices(
      direction: '매출',
      issueType: issueType,
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

  Future<void> _showModifyDialog(Invoice inv) async {
    String selReason = _modifyReasons[0];
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('수정발행'),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('마이너스(-) 수정세금계산서가 발행탭에 생성됩니다.',
                    style: TextStyle(color: Colors.orange, fontSize: 12)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selReason,
                  decoration: const InputDecoration(labelText: '수정 사유', border: OutlineInputBorder()),
                  items: _modifyReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setDlg(() => selReason = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                await DbHelper.modifyIssue(inv, selReason);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('수정세금계산서가 발행탭에 생성되었습니다. (사유: $selReason)')),
                  );
                }
                await _load();
              },
              child: const Text('수정발행'),
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
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: Colors.white,
          child: const Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('매출조회', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('세금/거래/지출 > 세금계산서 > 매출조회',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),

        // Summary cards
        if (_invoices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              _SummaryCard(label: '총 건수', value: '${_invoices.length}건'),
              const SizedBox(width: 8),
              _SummaryCard(label: '공급가액 합계', value: fmtNum(totalSupply)),
              const SizedBox(width: 8),
              _SummaryCard(label: '세액 합계', value: fmtNum(totalTax)),
              const SizedBox(width: 8),
              _SummaryCard(label: '합계금액', value: fmtNum(totalAmt), accent: true),
            ]),
          ),

        // Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              InkWell(onTap: () => _pickDate(true),
                child: _dateBox(_start)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('~')),
              InkWell(onTap: () => _pickDate(false),
                child: _dateBox(_end)),
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
                        DataColumn(label: Text('발행유형')),
                        DataColumn(label: Text('전송상태')),
                        DataColumn(label: Text('승인번호')),
                        DataColumn(label: Text('액션')),
                      ],
                      rows: _invoices.isEmpty
                          ? [DataRow(cells: List.generate(11, (i) => DataCell(
                              i == 0 ? const Text('조회된 내역이 없습니다.',
                                  style: TextStyle(color: Colors.grey)) : const Text(''))))]
                          : _invoices.map((inv) => DataRow(cells: [
                              DataCell(Text(inv.invoiceDate, style: const TextStyle(fontSize: 12))),
                              DataCell(typeBadge(inv.type)),
                              DataCell(Text(inv.partnerName ?? '-', style: const TextStyle(fontSize: 12))),
                              DataCell(Text(inv.businessNo ?? '-', style: const TextStyle(fontSize: 11, color: Colors.grey))),
                              DataCell(Text(fmtNum(inv.supplyAmount), style: const TextStyle(fontSize: 12))),
                              DataCell(Text(fmtNum(inv.taxAmount), style: const TextStyle(fontSize: 12))),
                              DataCell(Text(fmtNum(inv.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataCell(issueBadge(inv.issueType)),
                              DataCell(Text(inv.txStatus.isEmpty ? '-' : inv.txStatus, style: const TextStyle(fontSize: 11))),
                              DataCell(Text(inv.approvalNo.isEmpty ? '-' : inv.approvalNo, style: const TextStyle(fontSize: 11, color: Colors.grey))),
                              DataCell(inv.issueType == '전자'
                                ? TextButton(
                                    onPressed: () => _showModifyDialog(inv),
                                    child: const Text('수정발행', style: TextStyle(fontSize: 12)),
                                  )
                                : const Text('-', style: TextStyle(fontSize: 12))),
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

  Widget _dateBox(String date) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
    child: Text(date, style: const TextStyle(fontSize: 13)),
  );
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  const _SummaryCard({required this.label, required this.value, this.accent = false});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Text(value,
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold,
                color: accent ? const Color(0xFF198754) : const Color(0xFF0D6EFD),
              )),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    ),
  );
}
