import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import '../utils.dart';

const _periods = {
  '1기예정': ('01-01', '03-31'),
  '1기확정': ('04-01', '06-30'),
  '2기예정': ('07-01', '09-30'),
  '2기확정': ('10-01', '12-31'),
};

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});
  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  String _year      = DateTime.now().year.toString();
  String _period    = '1기예정';
  String _direction = '매출';
  String _invType   = '세금계산서';
  List<SummaryRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (sm, em) = _periods[_period]!;
    final rows = await DbHelper.getSummary(
      year: _year,
      startMonth: sm,
      endMonth: em,
      direction: _direction,
      invType: _invType,
    );
    setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    final (sm, em) = _periods[_period]!;
    final start = '$_year-$sm';
    final end   = '$_year-$em';

    final totalCnt    = _rows.fold(0, (s, r) => s + r.count);
    final totalSupply = _rows.fold(0, (s, r) => s + r.supplyTotal);
    final totalTax    = _rows.fold(0, (s, r) => s + r.taxTotal);
    final totalGrand  = _rows.fold(0, (s, r) => s + r.grandTotal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: Colors.white,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('합계표', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('세금/거래/지출 > 세금계산서 > 합계표',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),

        // Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFF0F0F0),
          child: Wrap(
            spacing: 12, runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 연도
              SizedBox(
                width: 90,
                child: DropdownButtonFormField<String>(
                  value: _year,
                  decoration: const InputDecoration(labelText: '연도', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), filled: true, fillColor: Colors.white),
                  items: List.generate(10, (i) => (2020 + i).toString())
                      .map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                  onChanged: (v) => setState(() => _year = v!),
                ),
              ),
              // 기수
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<String>(
                  value: _period,
                  decoration: const InputDecoration(labelText: '기수', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), filled: true, fillColor: Colors.white),
                  items: _periods.keys.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) => setState(() => _period = v!),
                ),
              ),
              // 매출/매입
              SizedBox(
                width: 90,
                child: DropdownButtonFormField<String>(
                  value: _direction,
                  decoration: const InputDecoration(labelText: '구분', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), filled: true, fillColor: Colors.white),
                  items: ['매출','매입'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _direction = v!),
                ),
              ),
              // 세금계산서/계산서
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  value: _invType,
                  decoration: const InputDecoration(labelText: '서류', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), filled: true, fillColor: Colors.white),
                  items: ['세금계산서','계산서'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _invType = v!),
                ),
              ),
              ElevatedButton(onPressed: _load, child: const Text('조회')),
            ],
          ),
        ),

        // Period info banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFFF8F9FA),
          child: Text(
            '조회 기간: $start ~ $end  |  $_direction처별 $_invType 합계표  (발행 완료 건 — 종이·전자)',
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
        ),

        // Summary cards
        if (_rows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              _card('$totalCnt건', '총 건수'),
              const SizedBox(width: 8),
              _card(fmtNum(totalSupply), '공급가액 합계'),
              const SizedBox(width: 8),
              _card(fmtNum(totalTax), '세액 합계'),
              const SizedBox(width: 8),
              _card(fmtNum(totalGrand), '합계금액', accent: true),
            ]),
          ),

        // Table
        Expanded(
          child: Card(
            margin: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Table title bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
                  ),
                  child: Text(
                    '$_year년 $_period  $_direction처별 $_invType 합계표',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 16,
                      columns: const [
                        DataColumn(label: Text('거래처명')),
                        DataColumn(label: Text('사업자번호')),
                        DataColumn(label: Text('매수'), numeric: true),
                        DataColumn(label: Text('공급가액 합계'), numeric: true),
                        DataColumn(label: Text('세액 합계'), numeric: true),
                        DataColumn(label: Text('합계금액'), numeric: true),
                      ],
                      rows: [
                        if (_rows.isEmpty)
                          DataRow(cells: [
                            const DataCell(Text('조회된 내역이 없습니다.',
                                style: TextStyle(color: Colors.grey))),
                            ...List.generate(5, (_) => const DataCell(Text(''))),
                          ]),
                        ..._rows.map((r) => DataRow(cells: [
                          DataCell(Text(r.partnerName, style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(Text(r.businessNo.isEmpty ? '-' : r.businessNo,
                              style: const TextStyle(fontSize: 12, color: Colors.grey))),
                          DataCell(Text(r.count.toString())),
                          DataCell(Text(fmtNum(r.supplyTotal))),
                          DataCell(Text(fmtNum(r.taxTotal))),
                          DataCell(Text(fmtNum(r.grandTotal),
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                        ])),
                        // Footer total row
                        if (_rows.isNotEmpty)
                          DataRow(
                            color: WidgetStateProperty.all(const Color(0xFFF0F4FF)),
                            cells: [
                              const DataCell(Text('합계', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataCell(Text('')),
                              DataCell(Text('$totalCnt', style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(fmtNum(totalSupply), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(fmtNum(totalTax), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(fmtNum(totalGrand), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D6EFD)))),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _card(String value, String label, {bool accent = false}) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
              color: accent ? const Color(0xFF0D6EFD) : Colors.black87)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    ),
  );
}
