import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db_helper.dart';
import '../models.dart';

class WarehouseTransferScreen extends StatefulWidget {
  const WarehouseTransferScreen({super.key});

  @override
  State<WarehouseTransferScreen> createState() => _WarehouseTransferScreenState();
}

class _WarehouseTransferScreenState extends State<WarehouseTransferScreen> {
  List<InventoryTransfer> _rows = [];
  List<Warehouse> _warehouses = [];
  List<InventoryItem> _items = [];
  bool _loading = true;

  String _start = '';
  String _end   = '';

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
    _rows = await DbHelper.getTransfers(start: _start, end: _end);
    setState(() => _loading = false);
  }

  Future<void> _showDialog() async {
    if (_warehouses.length < 2) { _alert('창고가 2개 이상 등록되어야 이동이 가능합니다.'); return; }
    if (_items.isEmpty)         { _alert('품목을 먼저 등록해 주세요.'); return; }

    int? fromId = _warehouses[0].id;
    int? toId   = _warehouses[1].id;
    int? itemId = _items.first.id;
    final dateCtrl = TextEditingController(text: DateTime.now().toString().substring(0, 10));
    final qtyCtrl  = TextEditingController(text: '1');
    final noteCtrl = TextEditingController(text: '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('창고간 이동 등록'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(labelText: '이동일 *', border: OutlineInputBorder()),
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
                Row(children: [
                  Expanded(child: DropdownButtonFormField<int>(
                    value: fromId,
                    decoration: const InputDecoration(labelText: '출발 창고 *', border: OutlineInputBorder()),
                    items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                    onChanged: (v) => ss(() => fromId = v),
                  )),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.arrow_forward)),
                  Expanded(child: DropdownButtonFormField<int>(
                    value: toId,
                    decoration: const InputDecoration(labelText: '도착 창고 *', border: OutlineInputBorder()),
                    items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                    onChanged: (v) => ss(() => toId = v),
                  )),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: itemId,
                  decoration: const InputDecoration(labelText: '품목 *', border: OutlineInputBorder()),
                  items: _items.map((i) => DropdownMenuItem(value: i.id, child: Text(i.name))).toList(),
                  onChanged: (v) => ss(() => itemId = v),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: '수량 *', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return (n == null || n <= 0) ? '수량 > 0' : null;
                  },
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
                if (fromId == toId) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('출발과 도착 창고가 같습니다.')));
                  return;
                }
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('이동 등록'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final tr = InventoryTransfer(
      transferDate:    dateCtrl.text,
      fromWarehouseId: fromId!,
      toWarehouseId:   toId!,
      itemId:          itemId!,
      quantity:        int.tryParse(qtyCtrl.text) ?? 1,
      note:            noteCtrl.text.trim(),
    );
    await DbHelper.insertTransfer(tr);
    await _load();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이동이 등록되었습니다.')),
      );
    }
  }

  Future<void> _delete(InventoryTransfer r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이동 삭제'),
        content: Text('${r.transferNo} 이동 내역을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await DbHelper.deleteTransfer(r.id!);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('창고간 이동', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('창고 간 재고를 이동합니다.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ]),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _showDialog,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('이동 등록'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F42C1),
                foregroundColor: Colors.white,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _dateField('시작일', _start, (d) => setState(() => _start = d)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('~')),
            _dateField('종료일', _end, (d) => setState(() => _end = d)),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _load, child: const Text('조회')),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? Center(child: Text('이동 내역이 없습니다.', style: TextStyle(color: Colors.grey[500])))
                    : Card(
                        child: SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('이동번호')),
                              DataColumn(label: Text('이동일')),
                              DataColumn(label: Text('출발 창고')),
                              DataColumn(label: Text('')),
                              DataColumn(label: Text('도착 창고')),
                              DataColumn(label: Text('품목')),
                              DataColumn(label: Text('수량'), numeric: true),
                              DataColumn(label: Text('비고')),
                              DataColumn(label: Text('관리')),
                            ],
                            rows: _rows.map((r) => DataRow(cells: [
                              DataCell(Text(r.transferNo, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                              DataCell(Text(r.transferDate)),
                              DataCell(Text(r.fromWarehouseName,
                                  style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.red))),
                              DataCell(const Icon(Icons.arrow_forward, size: 16, color: Colors.grey)),
                              DataCell(Text(r.toWarehouseName,
                                  style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.green))),
                              DataCell(Text(r.itemName)),
                              DataCell(Text('${_fmt(r.quantity)} ${r.itemUnit}')),
                              DataCell(Text(r.note.isNotEmpty ? r.note : '-')),
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
}
