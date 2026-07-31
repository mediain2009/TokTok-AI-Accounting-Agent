import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';

class WarehouseSettingsScreen extends StatefulWidget {
  const WarehouseSettingsScreen({super.key});

  @override
  State<WarehouseSettingsScreen> createState() => _WarehouseSettingsScreenState();
}

class _WarehouseSettingsScreenState extends State<WarehouseSettingsScreen> {
  List<Warehouse> _warehouses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _warehouses = await DbHelper.getWarehouses();
    setState(() => _loading = false);
  }

  Future<void> _showDialog({Warehouse? w}) async {
    final nameCtrl    = TextEditingController(text: w?.name    ?? '');
    final locationCtrl= TextEditingController(text: w?.location ?? '');
    final managerCtrl = TextEditingController(text: w?.manager  ?? '');
    final phoneCtrl   = TextEditingController(text: w?.phone    ?? '');
    final noteCtrl    = TextEditingController(text: w?.note     ?? '');
    bool isActive = w?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(w == null ? '창고 등록' : '창고 수정'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '창고명 *', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? '창고명을 입력하세요' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(labelText: '위치/주소', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: managerCtrl,
                    decoration: const InputDecoration(labelText: '담당자', border: OutlineInputBorder()),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: '연락처', border: OutlineInputBorder()),
                  )),
                ]),
                const SizedBox(height: 10),
                TextFormField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: '비고', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('사용 여부'),
                  value: isActive,
                  onChanged: (v) => ss(() => isActive = v),
                  contentPadding: EdgeInsets.zero,
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
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final updated = Warehouse(
      id:       w?.id,
      name:     nameCtrl.text.trim(),
      location: locationCtrl.text.trim(),
      manager:  managerCtrl.text.trim(),
      phone:    phoneCtrl.text.trim(),
      note:     noteCtrl.text.trim(),
      isActive: isActive,
    );
    if (w == null) {
      await DbHelper.insertWarehouse(updated);
    } else {
      await DbHelper.updateWarehouse(updated);
    }
    await _load();
  }

  Future<void> _delete(Warehouse w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('창고 삭제'),
        content: Text('"${w.name}" 창고를 삭제하시겠습니까?\n입출고 이력이 있으면 재고 현황에 영향을 줍니다.'),
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
      await DbHelper.deleteWarehouse(w.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('창고 설정', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('창고를 등록하고 관리합니다.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ]),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showDialog(),
              icon: const Icon(Icons.add),
              label: const Text('창고 등록'),
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
                : _warehouses.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.warehouse_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('등록된 창고가 없습니다.', style: TextStyle(color: Colors.grey[500])),
                          const SizedBox(height: 8),
                          ElevatedButton(onPressed: () => _showDialog(), child: const Text('첫 번째 창고 등록')),
                        ]),
                      )
                    : Card(
                        child: SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(label: Text('창고명')),
                              DataColumn(label: Text('위치')),
                              DataColumn(label: Text('담당자')),
                              DataColumn(label: Text('연락처')),
                              DataColumn(label: Text('상태')),
                              DataColumn(label: Text('관리')),
                            ],
                            rows: _warehouses.map((w) => DataRow(cells: [
                              DataCell(Text(w.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(Text(w.location.isNotEmpty ? w.location : '-')),
                              DataCell(Text(w.manager.isNotEmpty ? w.manager : '-')),
                              DataCell(Text(w.phone.isNotEmpty ? w.phone : '-')),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: w.isActive ? Colors.green[50] : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: w.isActive ? Colors.green : Colors.grey),
                                ),
                                child: Text(w.isActive ? '사용' : '미사용',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: w.isActive ? Colors.green[700] : Colors.grey[600],
                                    )),
                              )),
                              DataCell(Row(children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  tooltip: '수정',
                                  onPressed: () => _showDialog(w: w),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  tooltip: '삭제',
                                  onPressed: () => _delete(w),
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
