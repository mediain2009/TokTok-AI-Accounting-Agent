import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db_helper.dart';
import '../models.dart';

class InventoryItemsScreen extends StatefulWidget {
  const InventoryItemsScreen({super.key});

  @override
  State<InventoryItemsScreen> createState() => _InventoryItemsScreenState();
}

class _InventoryItemsScreenState extends State<InventoryItemsScreen> {
  List<InventoryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _items = await DbHelper.getInventoryItems();
    setState(() => _loading = false);
  }

  Future<void> _showDialog({InventoryItem? item}) async {
    final codeCtrl     = TextEditingController(text: item?.code     ?? '');
    final nameCtrl     = TextEditingController(text: item?.name     ?? '');
    final categoryCtrl = TextEditingController(text: item?.category ?? '');
    final unitCtrl     = TextEditingController(text: item?.unit     ?? '개');
    final costCtrl     = TextEditingController(text: item?.costPrice.toString()   ?? '0');
    final sellCtrl     = TextEditingController(text: item?.sellPrice.toString()   ?? '0');
    final safetyCtrl   = TextEditingController(text: item?.safetyStock.toString() ?? '0');
    final noteCtrl     = TextEditingController(text: item?.note ?? '');
    bool isActive = item?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(item == null ? '품목 등록' : '품목 수정'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(labelText: '품목코드', border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: '품목명 *', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? '품목명 필수' : null,
                    )),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(labelText: '분류', border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(labelText: '단위', border: OutlineInputBorder()),
                    )),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: costCtrl,
                      decoration: const InputDecoration(labelText: '원가', border: OutlineInputBorder(), suffixText: '원'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(
                      controller: sellCtrl,
                      decoration: const InputDecoration(labelText: '판매가', border: OutlineInputBorder(), suffixText: '원'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(
                      controller: safetyCtrl,
                      decoration: const InputDecoration(labelText: '안전재고', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    )),
                  ]),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: '비고', border: OutlineInputBorder()),
                  ),
                  SwitchListTile(
                    title: const Text('사용 여부'),
                    value: isActive,
                    onChanged: (v) => ss(() => isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final updated = InventoryItem(
      id:          item?.id,
      code:        codeCtrl.text.trim(),
      name:        nameCtrl.text.trim(),
      category:    categoryCtrl.text.trim(),
      unit:        unitCtrl.text.trim().isEmpty ? '개' : unitCtrl.text.trim(),
      costPrice:   int.tryParse(costCtrl.text) ?? 0,
      sellPrice:   int.tryParse(sellCtrl.text) ?? 0,
      safetyStock: int.tryParse(safetyCtrl.text) ?? 0,
      note:        noteCtrl.text.trim(),
      isActive:    isActive,
    );
    if (item == null) {
      await DbHelper.insertInventoryItem(updated);
    } else {
      await DbHelper.updateInventoryItem(updated);
    }
    await _load();
  }

  Future<void> _delete(InventoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('품목 삭제'),
        content: Text('"${item.name}" 품목을 삭제하시겠습니까?\n입출고 이력이 남아 있으면 재고현황에 영향이 있습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DbHelper.deleteInventoryItem(item.id!);
      await _load();
    }
  }

  String _fmt(int v) => v == 0 ? '-' : v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('품목 관리', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('재고 관리 대상 품목을 등록합니다.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ]),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showDialog(),
              icon: const Icon(Icons.add),
              label: const Text('품목 등록'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6EFD),
                foregroundColor: Colors.white,
              ),
            ),
          ]),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('등록된 품목이 없습니다.', style: TextStyle(color: Colors.grey[500])),
                          const SizedBox(height: 8),
                          ElevatedButton(onPressed: () => _showDialog(), child: const Text('첫 번째 품목 등록')),
                        ]),
                      )
                    : Card(
                        child: SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('코드')),
                              DataColumn(label: Text('품목명')),
                              DataColumn(label: Text('분류')),
                              DataColumn(label: Text('단위')),
                              DataColumn(label: Text('원가'), numeric: true),
                              DataColumn(label: Text('판매가'), numeric: true),
                              DataColumn(label: Text('안전재고'), numeric: true),
                              DataColumn(label: Text('상태')),
                              DataColumn(label: Text('관리')),
                            ],
                            rows: _items.map((it) => DataRow(cells: [
                              DataCell(Text(it.code.isNotEmpty ? it.code : '-',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                              DataCell(Text(it.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(Text(it.category.isNotEmpty ? it.category : '-')),
                              DataCell(Text(it.unit)),
                              DataCell(Text(_fmt(it.costPrice))),
                              DataCell(Text(_fmt(it.sellPrice))),
                              DataCell(it.safetyStock > 0
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[50],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.orange),
                                      ),
                                      child: Text('${it.safetyStock}',
                                          style: TextStyle(color: Colors.orange[700], fontSize: 12)),
                                    )
                                  : const Text('-')),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: it.isActive ? Colors.green[50] : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: it.isActive ? Colors.green : Colors.grey),
                                ),
                                child: Text(it.isActive ? '사용' : '미사용',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: it.isActive ? Colors.green[700] : Colors.grey[600],
                                    )),
                              )),
                              DataCell(Row(children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  tooltip: '수정',
                                  onPressed: () => _showDialog(item: it),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  tooltip: '삭제',
                                  onPressed: () => _delete(it),
                                ),
                              ])),
                            ])).toList(),
                          ),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}
