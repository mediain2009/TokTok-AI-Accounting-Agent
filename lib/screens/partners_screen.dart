import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  List<Partner> _partners = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DbHelper.getPartners();
    setState(() => _partners = list);
  }

  Future<void> _showForm({Partner? edit}) async {
    final nameC   = TextEditingController(text: edit?.name ?? '');
    final bizC    = TextEditingController(text: edit?.businessNo ?? '');
    final repC    = TextEditingController(text: edit?.repName ?? '');
    final addrC   = TextEditingController(text: edit?.address ?? '');
    final emailC  = TextEditingController(text: edit?.email ?? '');
    final phoneC  = TextEditingController(text: edit?.phone ?? '');
    final faxC    = TextEditingController(text: edit?.fax ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(edit == null ? '거래처 등록' : '거래처 수정'),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(child: _field('상호 *', nameC, required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('사업자번호', bizC, hint: '000-00-00000')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field('대표자명', repC)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('전화', phoneC)),
                ]),
                const SizedBox(height: 10),
                _field('주소', addrC),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field('이메일', emailC)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('팩스', faxC)),
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final p = Partner(
                id: edit?.id,
                name: nameC.text.trim(),
                businessNo: bizC.text.trim(),
                repName: repC.text.trim(),
                address: addrC.text.trim(),
                email: emailC.text.trim(),
                phone: phoneC.text.trim(),
                fax: faxC.text.trim(),
              );
              if (edit == null) {
                await DbHelper.insertPartner(p);
              } else {
                await DbHelper.updatePartner(p);
              }
              if (mounted) Navigator.pop(context);
              await _load();
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {bool required = false, String? hint}) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      validator: required ? (v) => v == null || v.isEmpty ? '필수 입력' : null : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: Color(0xFF0D6EFD), width: 4)),
          ),
          child: Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('거래처 관리', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('기초정보 > 거래처 관리', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('거래처 등록'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Table
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('상호')),
                  DataColumn(label: Text('사업자번호')),
                  DataColumn(label: Text('대표자')),
                  DataColumn(label: Text('전화')),
                  DataColumn(label: Text('이메일')),
                  DataColumn(label: Text('관리')),
                ],
                rows: _partners.isEmpty
                    ? [
                        const DataRow(cells: [
                          DataCell(Text('등록된 거래처가 없습니다.',
                              style: TextStyle(color: Colors.grey))),
                          DataCell(Text('')), DataCell(Text('')),
                          DataCell(Text('')), DataCell(Text('')),
                          DataCell(Text('')),
                        ])
                      ]
                    : _partners.map((p) => DataRow(cells: [
                          DataCell(Text(p.name,
                              style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(p.businessNo.isEmpty ? '-' : p.businessNo,
                              style: const TextStyle(color: Colors.grey, fontSize: 12))),
                          DataCell(Text(p.repName.isEmpty ? '-' : p.repName)),
                          DataCell(Text(p.phone.isEmpty ? '-' : p.phone)),
                          DataCell(Text(p.email.isEmpty ? '-' : p.email)),
                          DataCell(Row(children: [
                            TextButton(
                              onPressed: () => _showForm(edit: p),
                              child: const Text('수정', style: TextStyle(fontSize: 12)),
                            ),
                            TextButton(
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('삭제 확인'),
                                    content: Text('${p.name}을(를) 삭제하시겠습니까?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await DbHelper.deletePartner(p.id!);
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
        const SizedBox(height: 16),
      ],
    );
  }
}
