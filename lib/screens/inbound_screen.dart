import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db_helper.dart';
import '../models.dart';

class InboundScreen extends StatefulWidget {
  const InboundScreen({super.key});

  @override
  State<InboundScreen> createState() => _InboundScreenState();
}

class _InboundScreenState extends State<InboundScreen> {
  List<InventoryInbound> _rows = [];
  List<Warehouse> _warehouses = [];
  List<InventoryItem> _items = [];
  bool _loading = true;

  String _start = '';
  String _end   = '';
  int? _filterWarehouseId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    _end   = now.toString().substring(0, 10);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _warehouses = await DbHelper.getWarehouses(activeOnly: true);
    _items      = await DbHelper.getInventoryItems(activeOnly: true);
    _rows = await DbHelper.getInbounds(start: _start, end: _end, warehouseId: _filterWarehouseId);
    setState(() => _loading = false);
  }

  Future<void> _showDialog() async {
    if (_warehouses.isEmpty) {
      _alert('창고를 먼저 등록해 주세요.');
      return;
    }
    if (_items.isEmpty) {
      _alert('품목을 먼저 등록해 주세요.');
      return;
    }

    int? selectedWarehouseId = _warehouses.first.id;
    int? selectedItemId      = _items.first.id;
    final dateCtrl     = TextEditingController(text: DateTime.now().toString().substring(0, 10));
    final qtyCtrl      = TextEditingController(text: '1');
    final priceCtrl    = TextEditingController(text: '0');
    final supplierCtrl = TextEditingController(text: '');
    final noteCtrl     = TextEditingController(text: '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('입고 등록'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // 날짜
                TextFormField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(labelText: '입고일 *', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? '날짜 필수' : null,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2099),
                    );
                    if (d != null) dateCtrl.text = d.toString().substring(0, 10);
                  },
                  readOnly: true,
                ),
                const SizedBox(height: 10),
                // 창고
                DropdownButtonFormField<int>(
                  value: selectedWarehouseId,
                  decoration: const InputDecoration(labelText: '창고 *', border: OutlineInputBorder()),
                  items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                  onChanged: (v) => ss(() => selectedWarehouseId = v),
                ),
                const SizedBox(height: 10),
                // 품목
                DropdownButtonFormField<int>(
                  value: selectedItemId,
                  decoration: const InputDecoration(labelText: '품목 *', border: OutlineInputBorder()),
                  items: _items.map((i) => DropdownMenuItem(value: i.id, child: Text(i.name))).toList(),
                  onChanged: (v) => ss(() => selectedItemId = v),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: qtyCtrl,
                    decoration: const InputDecoration(labelText: '수량 *', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n <= 0) ? '수량 > 0' : null;
                    },
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(labelText: '단가', border: OutlineInputBorder(), suffixText: '원'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  )),
                ]),
                const SizedBox(height: 10),
                TextFormField(
                  controller: supplierCtrl,
                  decoration: const InputDecoration(labelText: '공급처', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: '비고', border: OutlineInputBorder()),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('입고 등록'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final ib = InventoryInbound(
      inboundDate: dateCtrl.text,
      warehouseId: selectedWarehouseId!,
      itemId:      selectedItemId!,
      quantity:    int.tryParse(qtyCtrl.text) ?? 1,
      unitPrice:   int.tryParse(priceCtrl.text) ?? 0,
      supplier:    supplierCtrl.text.trim(),
      note:        noteCtrl.text.trim(),
    );
    await DbHelper.insertInbound(ib);
    await _load();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입고가 등록되었습니다.')),
      );
    }
  }

  Future<void> _delete(InventoryInbound r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('입고 삭제'),
        content: Text('${r.inboundNo} 입고 내역을 삭제하시겠습니까?\n재고 수량에 반영됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await DbHelper.deleteInbound(r.id!);
      await _load();
    }
  }

  void _alert(String msg) => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(msg),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))],
    ),
  );

  String _fmt(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  int get _totalQty => _rows.fold(0, (s, r) => s + r.quantity);
  int get _totalAmt => _rows.fold(0, (s, r) => s + r.quantity * r.unitPrice);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 헤더
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('입고 관리', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('창고별 입고 내역을 기록합니다.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ]),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _showDialog,
              icon: const Icon(Icons.add),
              label: const Text('입고 등록'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF198754),
                foregroundColor: Colors.white,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          // 필터
          Row(children: [
            _dateField('시작일', _start, (d) => setState(() => _start = d)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('~')),
            _dateField('종료일', _end, (d) => setState(() => _end = d)),
            const SizedBox(width: 12),
            DropdownButton<int?>(
              value: _filterWarehouseId,
              hint: const Text('전체 창고'),
              items: [
                const DropdownMenuItem(value: null, child: Text('전체 창고')),
                ..._warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))),
              ],
              onChanged: (v) => setState(() => _filterWarehouseId = v),
            ),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _load, child: const Text('조회')),
          ]),
          const SizedBox(height: 12),
          // 요약 카드
          if (!_loading) Row(children: [
            _statCard('총 입고건', '${_rows.length}건', Colors.green),
            const SizedBox(width: 12),
            _statCard('총 수량', '${_fmt(_totalQty)}', Colors.blue),
            const SizedBox(width: 12),
            _statCard('총 금액', '${_fmt(_totalAmt)}원', Colors.purple),
          ]),
          const SizedBox(height: 12),
          // 테이블
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? Center(child: Text('입고 내역이 없습니다.', style: TextStyle(color: Colors.grey[500])))
                    : Card(
                        child: SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('입고번호')),
                              DataColumn(label: Text('입고일')),
                              DataColumn(label: Text('창고')),
                              DataColumn(label: Text('품목')),
                              DataColumn(label: Text('수량'), numeric: true),
                              DataColumn(label: Text('단가'), numeric: true),
                              DataColumn(label: Text('금액'), numeric: true),
                              DataColumn(label: Text('공급처')),
                              DataColumn(label: Text('관리')),
                            ],
                            rows: _rows.map((r) => DataRow(cells: [
                              DataCell(Text(r.inboundNo, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                              DataCell(Text(r.inboundDate)),
                              DataCell(Text(r.warehouseName,
                                  style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(Text(r.itemName)),
                              DataCell(Text('${_fmt(r.quantity)} ${r.itemUnit}')),
                              DataCell(Text(r.unitPrice > 0 ? _fmt(r.unitPrice) : '-')),
                              DataCell(Text(r.unitPrice > 0 ? _fmt(r.quantity * r.unitPrice) : '-')),
                              DataCell(Text(r.supplier.isNotEmpty ? r.supplier : '-')),
                              DataCell(IconButton(
                                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                tooltip: '삭제',
                                onPressed: () => _delete(r),
                              )),
                            ])).toList(),
                          ),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _dateField(String label, String value, void Function(String) onChanged) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(value) ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2099),
        );
        if (d != null) onChanged(d.toString().substring(0, 10));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(value, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
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
