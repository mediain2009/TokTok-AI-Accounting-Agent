import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';

class InventoryStatusScreen extends StatefulWidget {
  const InventoryStatusScreen({super.key});

  @override
  State<InventoryStatusScreen> createState() => _InventoryStatusScreenState();
}

class _InventoryStatusScreenState extends State<InventoryStatusScreen> {
  List<StockRow> _rows = [];
  List<Warehouse> _warehouses = [];
  bool _loading = true;
  int? _filterWarehouseId;
  bool _showLowOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _warehouses = await DbHelper.getWarehouses(activeOnly: true);
    _rows = await DbHelper.getStockStatus(warehouseId: _filterWarehouseId);
    setState(() => _loading = false);
  }

  List<StockRow> get _filtered {
    var list = _rows;
    if (_showLowOnly) list = list.where((r) => r.safetyStock > 0 && r.stock < r.safetyStock).toList();
    return list;
  }

  String _fmt(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  bool _isLow(StockRow r) => r.safetyStock > 0 && r.stock < r.safetyStock;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final lowCount = _rows.where(_isLow).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 헤더
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('재고 현황', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('창고별 실시간 재고를 확인합니다.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ]),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('새로고침'),
            ),
          ]),
          const SizedBox(height: 16),

          // 요약 카드
          if (!_loading) Row(children: [
            _card('총 품목수', '${_rows.length}건', Colors.blue),
            const SizedBox(width: 12),
            _card('창고수', '${_warehouses.length}개', Colors.green),
            const SizedBox(width: 12),
            _card('안전재고 미달', '$lowCount건', Colors.red),
          ]),
          const SizedBox(height: 12),

          // 필터
          Row(children: [
            DropdownButton<int?>(
              value: _filterWarehouseId,
              hint: const Text('전체 창고'),
              items: [
                const DropdownMenuItem(value: null, child: Text('전체 창고')),
                ..._warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))),
              ],
              onChanged: (v) {
                setState(() => _filterWarehouseId = v);
                _load();
              },
            ),
            const SizedBox(width: 16),
            FilterChip(
              label: const Text('안전재고 미달만'),
              selected: _showLowOnly,
              onSelected: (v) => setState(() => _showLowOnly = v),
              selectedColor: Colors.red[100],
              checkmarkColor: Colors.red,
            ),
            if (lowCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.warning_amber, size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text('$lowCount개 품목 안전재고 미달',
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ]),
              ),
            ],
          ]),
          const SizedBox(height: 12),

          // 테이블
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.inventory_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            _rows.isEmpty ? '입출고 내역이 없습니다.' : '안전재고 미달 품목이 없습니다.',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ]),
                      )
                    : Card(
                        child: SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('창고')),
                              DataColumn(label: Text('코드')),
                              DataColumn(label: Text('품목명')),
                              DataColumn(label: Text('단위')),
                              DataColumn(label: Text('입고'), numeric: true),
                              DataColumn(label: Text('출고'), numeric: true),
                              DataColumn(label: Text('이동(+)'), numeric: true),
                              DataColumn(label: Text('이동(-)'), numeric: true),
                              DataColumn(label: Text('현재고'), numeric: true),
                              DataColumn(label: Text('안전재고'), numeric: true),
                              DataColumn(label: Text('상태')),
                            ],
                            rows: filtered.map((r) {
                              final low = _isLow(r);
                              return DataRow(
                                color: WidgetStatePropertyAll(
                                  low ? Colors.red[50] : null,
                                ),
                                cells: [
                                  DataCell(Text(r.warehouseName,
                                      style: const TextStyle(fontWeight: FontWeight.w500))),
                                  DataCell(Text(r.itemCode.isNotEmpty ? r.itemCode : '-',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                                  DataCell(Text(r.itemName)),
                                  DataCell(Text(r.itemUnit)),
                                  DataCell(Text(_fmt(r.inQty),
                                      style: const TextStyle(color: Colors.green))),
                                  DataCell(Text(_fmt(r.outQty),
                                      style: const TextStyle(color: Colors.red))),
                                  DataCell(Text(r.transferIn > 0 ? '+${_fmt(r.transferIn)}' : '-',
                                      style: const TextStyle(color: Colors.blue))),
                                  DataCell(Text(r.transferOut > 0 ? '-${_fmt(r.transferOut)}' : '-',
                                      style: const TextStyle(color: Colors.orange))),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: r.stock > 0
                                          ? (low ? Colors.red[100] : Colors.blue[50])
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _fmt(r.stock),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: r.stock > 0
                                            ? (low ? Colors.red[700] : Colors.blue[700])
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  )),
                                  DataCell(Text(
                                    r.safetyStock > 0 ? _fmt(r.safetyStock) : '-',
                                    style: TextStyle(color: Colors.orange[700]),
                                  )),
                                  DataCell(low
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Text('미달', style: TextStyle(color: Colors.white, fontSize: 11)),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green[100],
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text('정상', style: TextStyle(color: Colors.green[700], fontSize: 11)),
                                        )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _card(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }
}
