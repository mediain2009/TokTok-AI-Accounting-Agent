import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../db_helper.dart';
import '../models.dart';

/// 실행파일 디렉토리 아래 images 폴더 경로
String get _imagesDir {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  return p.join(exeDir, 'images');
}

/// images 폴더 생성 후 파일 복사 → 저장된 절대경로 반환
Future<String> _copyToImages(String srcPath, String destName) async {
  final dir = Directory(_imagesDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final dest = File(p.join(dir.path, destName));
  await File(srcPath).copy(dest.path);
  return dest.path;
}

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key});

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saved   = false;

  // Controllers
  final _companyNameC    = TextEditingController();
  final _repNameC        = TextEditingController();
  final _businessNoC     = TextEditingController();
  final _bizTypeC        = TextEditingController();
  final _bizItemC        = TextEditingController();
  final _addressC        = TextEditingController();
  final _currentAddressC = TextEditingController();
  final _phoneC          = TextEditingController();
  final _faxC            = TextEditingController();
  final _emailC          = TextEditingController();
  final _bizStartC       = TextEditingController();
  final _fiscalStartC    = TextEditingController();
  final _fiscalEndC      = TextEditingController();

  // 이미지 경로 (DB 저장용)
  String _logoPath = '';
  String _sealPath = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _companyNameC, _repNameC, _businessNoC, _bizTypeC, _bizItemC,
      _addressC, _currentAddressC, _phoneC, _faxC, _emailC,
      _bizStartC, _fiscalStartC, _fiscalEndC,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final info = await DbHelper.getCompanyInfo();
    if (info != null) {
      _companyNameC.text    = info.companyName;
      _repNameC.text        = info.repName;
      _businessNoC.text     = info.businessNo;
      _bizTypeC.text        = info.bizType;
      _bizItemC.text        = info.bizItem;
      _addressC.text        = info.address;
      _currentAddressC.text = info.currentAddress;
      _phoneC.text          = info.phone;
      _faxC.text            = info.fax;
      _emailC.text          = info.email;
      _logoPath             = info.logoPath;
      _sealPath             = info.sealPath;
      _bizStartC.text       = info.bizStartDate;
      _fiscalStartC.text    = info.fiscalStart;
      _fiscalEndC.text      = info.fiscalEnd;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final info = CompanyInfo(
      companyName:    _companyNameC.text.trim(),
      repName:        _repNameC.text.trim(),
      businessNo:     _businessNoC.text.trim(),
      bizType:        _bizTypeC.text.trim(),
      bizItem:        _bizItemC.text.trim(),
      address:        _addressC.text.trim(),
      currentAddress: _currentAddressC.text.trim(),
      phone:          _phoneC.text.trim(),
      fax:            _faxC.text.trim(),
      email:          _emailC.text.trim(),
      logoPath:       _logoPath,
      sealPath:       _sealPath,
      bizStartDate:   _bizStartC.text.trim(),
      fiscalStart:    _fiscalStartC.text.trim(),
      fiscalEnd:      _fiscalEndC.text.trim(),
    );
    await DbHelper.saveCompanyInfo(info);
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  /// 이미지 파일 선택 → images 폴더로 복사 → 경로 저장
  Future<void> _pickImage({required bool isLogo}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'gif', 'bmp'],
      dialogTitle: isLogo ? '회사 로고 선택' : '사용인감 선택',
    );
    if (result == null || result.files.isEmpty) return;

    final srcPath  = result.files.first.path!;
    final ext      = p.extension(srcPath);                   // .png 등
    final destName = isLogo ? 'logo$ext' : 'seal$ext';

    try {
      final savedPath = await _copyToImages(srcPath, destName);
      setState(() {
        if (isLogo) {
          _logoPath = savedPath;
        } else {
          _sealPath = savedPath;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 저장 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: Colors.white,
          child: Row(
            children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('회사정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('사업자등록증 상의 회사 정보를 입력합니다.',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
              const Spacer(),
              if (_saved)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Row(children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 4),
                    Text('저장되었습니다', style: TextStyle(color: Colors.green, fontSize: 13)),
                  ]),
                ),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('저장'),
              ),
            ],
          ),
        ),

        // Form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 사업자 기본 정보 ────────────────────────────────
                  _section('사업자 기본 정보 (사업자등록증)'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        Row(children: [
                          Expanded(child: _field('상호 *', _companyNameC, required: true)),
                          const SizedBox(width: 16),
                          Expanded(child: _field('대표자 *', _repNameC, required: true)),
                          const SizedBox(width: 16),
                          Expanded(child: _field('사업자등록번호', _businessNoC,
                              hint: '000-00-00000')),
                        ]),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(child: _field('업태', _bizTypeC, hint: '예) 도소매')),
                          const SizedBox(width: 16),
                          Expanded(child: _field('종목', _bizItemC, hint: '예) 컴퓨터 및 주변기기')),
                          const SizedBox(width: 16),
                          Expanded(child: _field('전화', _phoneC)),
                          const SizedBox(width: 16),
                          Expanded(child: _field('팩스', _faxC)),
                        ]),
                        const SizedBox(height: 14),
                        _field('이메일', _emailC),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── 주소 ──────────────────────────────────────────
                  _section('주소'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        _field('사업장 주소 (세금계산서 공급자 주소)', _addressC,
                            hint: '사업자등록증상 주소'),
                        const SizedBox(height: 14),
                        _field('현주소 (거래명세표 공급자 주소)', _currentAddressC,
                            hint: '실제 사업장 주소 (위와 다른 경우)'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.orange),
                            SizedBox(width: 6),
                            Expanded(child: Text(
                              '상단 주소는 세금계산서 공급자 주소로, 현주소는 거래명세표 공급자 주소로 사용됩니다.',
                              style: TextStyle(fontSize: 11, color: Colors.orange),
                            )),
                          ]),
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── 회사 로고 / 사용인감 ───────────────────────────
                  _section('회사 로고 / 사용인감'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 저장 폴더 안내
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F4FD),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(children: [
                              const Icon(Icons.folder, size: 14, color: Colors.blue),
                              const SizedBox(width: 6),
                              Expanded(child: Text(
                                '저장 위치: $_imagesDir',
                                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                              )),
                            ]),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 회사 로고
                              Expanded(
                                child: _ImageUploadTile(
                                  label: '회사 로고',
                                  path: _logoPath,
                                  onPickTap: () => _pickImage(isLogo: true),
                                  onRemove: () => setState(() => _logoPath = ''),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // 사용인감
                              Expanded(
                                child: _ImageUploadTile(
                                  label: '사용인감',
                                  path: _sealPath,
                                  onPickTap: () => _pickImage(isLogo: false),
                                  onRemove: () => setState(() => _sealPath = ''),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '지원 형식: PNG / JPG / JPEG · 견적서·거래명세표 출력 시 함께 인쇄됩니다.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── 회계 설정 ──────────────────────────────────────
                  _section('회계 설정'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(children: [
                        Expanded(child: _datePicker('사업개시일', _bizStartC, context)),
                        const SizedBox(width: 16),
                        Expanded(child: _datePicker('회계 시작일', _fiscalStartC, context)),
                        const SizedBox(width: 16),
                        Expanded(child: _datePicker('회계 종료일', _fiscalEndC, context)),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A2236))),
  );

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
      validator: required ? (v) => (v == null || v.isEmpty) ? '필수 입력' : null : null,
    );
  }

  Widget _datePicker(String label, TextEditingController c, BuildContext ctx) {
    return TextFormField(
      controller: c,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        suffixIcon: const Icon(Icons.calendar_today, size: 16),
      ),
      onTap: () async {
        final init = DateTime.tryParse(c.text) ?? DateTime.now();
        final picked = await showDatePicker(
          context: ctx,
          initialDate: init,
          firstDate: DateTime(2000),
          lastDate: DateTime(2050),
        );
        if (picked != null) {
          setState(() => c.text = picked.toString().substring(0, 10));
        }
      },
    );
  }
}

// ─── 이미지 업로드 타일 ───────────────────────────────────────────────────────
class _ImageUploadTile extends StatelessWidget {
  final String label;
  final String path;
  final VoidCallback onPickTap;
  final VoidCallback onRemove;

  const _ImageUploadTile({
    required this.label,
    required this.path,
    required this.onPickTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = path.isNotEmpty && File(path).existsSync();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),

        // 미리보기 / 업로드 영역
        GestureDetector(
          onTap: onPickTap,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              border: Border.all(
                color: hasImage ? Colors.blue.shade200 : Colors.grey.shade300,
                width: hasImage ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: hasImage
                ? Stack(
                    children: [
                      Center(
                        child: Image.file(
                          File(path),
                          height: 100,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image, size: 40, color: Colors.red),
                        ),
                      ),
                      Positioned(
                        top: 4, right: 4,
                        child: GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file, size: 32, color: Colors.grey),
                      SizedBox(height: 6),
                      Text('클릭하여 이미지 선택',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('PNG / JPG',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
          ),
        ),

        // 파일명 표시
        if (path.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            p.basename(path),
            style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onPickTap,
            icon: const Icon(Icons.folder_open, size: 14),
            label: Text('$label 선택'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
