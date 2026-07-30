import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db_helper.dart';
import '../models.dart';
import '../services/ai_service.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  bool _loading   = true;
  bool _testing   = false;
  bool _saved     = false;
  String? _testResult;
  bool _testOk    = false;

  String _provider = 'claude';
  final _apiKeyC   = TextEditingController();
  final _baseUrlC  = TextEditingController();
  final _modelC    = TextEditingController();
  bool _obscureKey = true;

  static const _providers = [
    {'id': 'claude', 'name': 'Claude (Anthropic)', 'icon': '🤖'},
    {'id': 'openai', 'name': 'OpenAI (GPT)',        'icon': '🟢'},
    {'id': 'gemini', 'name': 'Gemini (Google)',     'icon': '💎'},
    {'id': 'ollama', 'name': 'Ollama (로컬)',        'icon': '🦙'},
    {'id': 'custom', 'name': 'Custom (OpenAI 호환)', 'icon': '⚙️'},
  ];

  // ── 제공자별 상세 정보 ─────────────────────────────────────────────
  static const _providerInfo = {
    'claude': {
      'summary': '가장 높은 품질의 한국어 이해, 복잡한 추론에 강함',
      'keyUrl':  'https://console.anthropic.com/settings/keys',
      'keyLabel':'Anthropic Console에서 발급',
      'steps': [
        'console.anthropic.com 접속 → 회원가입/로그인',
        'Settings → API Keys → Create Key 클릭',
        '키 이름 입력 후 생성 → sk-ant-... 복사',
        '결제 수단 등록 필요 (Plans & Billing)',
      ],
      'pricing': [
        {'model': 'claude-haiku-4-5',  'input': '\$0.80',  'output': '\$4.00',  'note': '빠르고 저렴'},
        {'model': 'claude-sonnet-4-6', 'input': '\$3.00',  'output': '\$15.00', 'note': '균형 잡힌 성능'},
        {'model': 'claude-opus-5',     'input': '\$15.00', 'output': '\$75.00', 'note': '최고 성능'},
      ],
      'minCost': '최소 충전 \$5 (약 7,000원) · 무료 크레딧 없음',
      'free': false,
    },
    'openai': {
      'summary': '범용적이고 안정적, GPT-4o 계열로 코드·문서 작업에 강함',
      'keyUrl':  'https://platform.openai.com/api-keys',
      'keyLabel':'OpenAI Platform에서 발급',
      'steps': [
        'platform.openai.com 접속 → 로그인',
        'Dashboard → API keys → Create new secret key',
        'sk-... 형태의 키 복사 (한 번만 표시)',
        '결제 수단 등록 (Billing → Add payment method)',
      ],
      'pricing': [
        {'model': 'gpt-4o-mini',  'input': '\$0.15', 'output': '\$0.60',  'note': '가성비 최고'},
        {'model': 'gpt-4o',       'input': '\$2.50', 'output': '\$10.00', 'note': '고성능'},
        {'model': 'o4-mini',      'input': '\$1.10', 'output': '\$4.40',  'note': '추론 특화'},
      ],
      'minCost': '최소 충전 \$5 (약 7,000원) · 신규 계정 \$5 무료 크레딧 제공 (90일)',
      'free': false,
    },
    'gemini': {
      'summary': '구글의 AI · 무료 티어 제공 · 빠른 응답 속도 · 한국어 양호',
      'keyUrl':  'https://aistudio.google.com/apikey',
      'keyLabel':'Google AI Studio에서 발급 (무료)',
      'steps': [
        'aistudio.google.com/apikey 접속 → 구글 로그인',
        'Create API key 클릭',
        'AQ... 형태의 키 복사 (프로젝트 기반 새 형식)',
        '무료 티어로 바로 사용 가능 (카드 불필요)',
      ],
      'pricing': [
        {'model': 'gemini-3.5-flash', 'input': '무료 (분당 10req)', 'output': '무료', 'note': '추천 · 최신 (AQ. 키)'},
        {'model': 'gemini-2.5-flash', 'input': '무료 (분당 10req)', 'output': '무료', 'note': '안정'},
        {'model': 'gemini-2.0-flash', 'input': '무료 (분당 15req)', 'output': '무료', 'note': '구버전 키 호환'},
      ],
      'minCost': '무료 사용 가능 (gemini-3.5-flash 기준 분당 10회, 일 1,500회 무료)',
      'free': true,
    },
    'ollama': {
      'summary': '완전 무료 · 인터넷 불필요 · 개인 정보 보호 · PC에서 직접 실행',
      'keyUrl':  'https://ollama.com/download',
      'keyLabel':'Ollama 공식 사이트에서 무료 설치',
      'steps': [
        'ollama.com/download 에서 Windows 설치',
        'CMD에서: ollama pull llama3.2  (모델 다운로드)',
        'CMD에서: ollama serve  (서버 실행)',
        'Base URL: http://localhost:11434 로 설정',
      ],
      'pricing': [
        {'model': 'llama3.2',    'input': '무료', 'output': '무료', 'note': '경량 · 추천'},
        {'model': 'mistral',     'input': '무료', 'output': '무료', 'note': '균형'},
        {'model': 'qwen2.5:14b', 'input': '무료', 'output': '무료', 'note': '한국어 우수'},
      ],
      'minCost': '완전 무료 · API Key 불필요 · PC 사양에 따라 속도 차이',
      'free': true,
    },
    'custom': {
      'summary': 'OpenAI 호환 API면 모두 연결 가능 (LM Studio, Together AI, Perplexity 등)',
      'keyUrl':  '',
      'keyLabel':'제공자 사이트에서 발급',
      'steps': [
        '사용할 서비스에서 API Key 발급',
        'Base URL: 서비스의 /chat/completions 직전 경로 입력',
        '예) LM Studio: http://localhost:1234/v1',
        '예) Together AI: https://api.together.xyz/v1',
      ],
      'pricing': [
        {'model': 'LM Studio',    'input': '무료', 'output': '무료',      'note': '로컬 · 무료'},
        {'model': 'Together AI',  'input': '저렴', 'output': '저렴',      'note': '다양한 모델'},
        {'model': 'Perplexity',   'input': '\$1+', 'output': '\$1+',      'note': '검색 특화'},
      ],
      'minCost': '제공자마다 다름 · 로컬(LM Studio) 사용 시 완전 무료',
      'free': null,
    },
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyC.dispose();
    _baseUrlC.dispose();
    _modelC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await DbHelper.getAiSettings();
    if (s != null) {
      setState(() {
        _provider      = s.provider;
        _apiKeyC.text  = s.apiKey;
        _baseUrlC.text = s.baseUrl;
        _modelC.text   = s.model;
      });
    } else {
      _applyProviderDefaults('claude');
    }
    setState(() => _loading = false);
  }

  void _applyProviderDefaults(String p) {
    setState(() {
      _provider      = p;
      _baseUrlC.text = AiSettings.defaultBaseUrl(p);
      _modelC.text   = AiSettings.defaultModel(p);
    });
  }

  Future<void> _save() async {
    final s = AiSettings(
      provider: _provider,
      apiKey:   _apiKeyC.text.trim(),
      baseUrl:  _baseUrlC.text.trim(),
      model:    _modelC.text.trim(),
    );
    await DbHelper.saveAiSettings(s);
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _testConnection() async {
    await _save();
    setState(() { _testing = true; _testResult = null; });
    try {
      final s = AiSettings(
        provider: _provider,
        apiKey:   _apiKeyC.text.trim(),
        baseUrl:  _baseUrlC.text.trim(),
        model:    _modelC.text.trim(),
      );
      final res = await AiService.testConnection(s);
      setState(() { _testOk = true; _testResult = '✅ 연결 성공: $res'; });
    } catch (e) {
      setState(() { _testOk = false; _testResult = '❌ 오류: $e'; });
    } finally {
      setState(() => _testing = false);
    }
  }

  bool get _needsApiKey =>
      _provider == 'claude' || _provider == 'openai' ||
      _provider == 'gemini' || _provider == 'custom';
  bool get _isLocal => _provider == 'ollama';

  // 제공자별 추천 모델 목록
  static const _recommendedModels = {
    'claude': ['claude-haiku-4-5', 'claude-sonnet-4-6', 'claude-opus-5'],
    'openai': ['gpt-4o-mini', 'gpt-4o', 'o4-mini'],
    'gemini': ['gemini-flash-latest', 'gemini-3.5-flash', 'gemini-1.5-flash'],
    'ollama': ['llama3.2', 'mistral', 'qwen2.5:14b'],
    'custom': [],
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final info = _providerInfo[_provider]!;

    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: Colors.white,
          child: Row(children: [
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('AI 제공자를 선택하고 연결 정보를 입력합니다.',
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
            OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_tethering, size: 16),
              label: const Text('연결 테스트'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, size: 16),
              label: const Text('저장'),
            ),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── 제공자 선택 ─────────────────────────────────────
              _sectionLabel('AI 제공자 선택'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 12, runSpacing: 12,
                    children: _providers.map((p) {
                      final selected = _provider == p['id'];
                      final isFree   = _providerInfo[p['id']]!['free'];
                      return InkWell(
                        onTap: () => _applyProviderDefaults(p['id']!),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? const Color(0xFF0D6EFD) : Colors.grey.shade300,
                              width: selected ? 2 : 1,
                            ),
                            color: selected ? const Color(0xFFEBF3FF) : Colors.white,
                          ),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(p['icon']!, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 6),
                            Text(p['name']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                  color: selected ? const Color(0xFF0D6EFD) : Colors.black87,
                                )),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isFree == true
                                    ? Colors.green.shade50
                                    : isFree == false
                                        ? Colors.orange.shade50
                                        : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isFree == true ? '무료' : isFree == false ? '유료' : '선택',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isFree == true
                                      ? Colors.green.shade700
                                      : isFree == false
                                          ? Colors.orange.shade700
                                          : Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── 제공자 상세 정보 카드 ──────────────────────────
              _sectionLabel('제공자 안내'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // 요약
                    Row(children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFF0D6EFD)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(info['summary'] as String,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    ]),
                    const Divider(height: 24),

                    // API Key 발급 방법
                    Row(children: [
                      const Icon(Icons.vpn_key, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('API Key 발급 방법',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700)),
                    ]),
                    const SizedBox(height: 8),
                    for (int i = 0; i < (info['steps'] as List).length; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D6EFD).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text('${i+1}',
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF0D6EFD),
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text((info['steps'] as List)[i] as String,
                              style: const TextStyle(fontSize: 12))),
                        ]),
                      ),

                    if ((info['keyUrl'] as String).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: info['keyUrl'] as String));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('링크가 클립보드에 복사됐습니다'), duration: Duration(seconds: 2)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEBF3FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(children: [
                            const Icon(Icons.link, size: 14, color: Color(0xFF0D6EFD)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(info['keyUrl'] as String,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF0D6EFD)))),
                            const Icon(Icons.copy, size: 14, color: Color(0xFF0D6EFD)),
                          ]),
                        ),
                      ),
                    ],

                    const Divider(height: 24),

                    // 요금 안내
                    Row(children: [
                      const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('요금 안내 (1M = 100만 토큰 ≈ 75만 단어)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700)),
                    ]),
                    const SizedBox(height: 10),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.5),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(2),
                      },
                      border: TableBorder.all(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFFF8F9FA)),
                          children: ['모델', '입력', '출력', '특징']
                              .map((h) => Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(h, style: const TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.bold)),
                                  ))
                              .toList(),
                        ),
                        for (final p in (info['pricing'] as List))
                          TableRow(children: [
                            _ptd(p['model'] as String, bold: true),
                            _ptd(p['input'] as String),
                            _ptd(p['output'] as String),
                            _ptd(p['note'] as String,
                                color: (p['note'] as String).contains('무료')
                                    ? Colors.green.shade700 : null),
                          ]),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (info['free'] as bool?) == true
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(children: [
                        Icon(
                          (info['free'] as bool?) == true
                              ? Icons.check_circle_outline
                              : Icons.account_balance_wallet_outlined,
                          size: 16,
                          color: (info['free'] as bool?) == true
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(info['minCost'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: (info['free'] as bool?) == true
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ))),
                      ]),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 16),

              // ── 연결 정보 입력 ──────────────────────────────────
              _sectionLabel('연결 정보'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    if (_needsApiKey) ...[
                      TextFormField(
                        controller: _apiKeyC,
                        obscureText: _obscureKey,
                        decoration: InputDecoration(
                          labelText: _isLocal ? 'API Key (선택)' : 'API Key *',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off, size: 18),
                            onPressed: () => setState(() => _obscureKey = !_obscureKey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _baseUrlC,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _modelC,
                      decoration: const InputDecoration(
                        labelText: '모델명',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                    // 추천 모델 칩
                    if ((_recommendedModels[_provider] ?? []).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          const Text('추천: ',
                              style: TextStyle(fontSize: 11, color: Colors.grey)),
                          for (final m in _recommendedModels[_provider]!)
                            ActionChip(
                              label: Text(m, style: const TextStyle(fontSize: 11)),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: _modelC.text == m
                                  ? const Color(0xFFEBF3FF)
                                  : null,
                              side: _modelC.text == m
                                  ? const BorderSide(color: Color(0xFF0D6EFD))
                                  : null,
                              onPressed: () => setState(() => _modelC.text = m),
                            ),
                        ],
                      ),
                    ],
                  ]),
                ),
              ),

              // ── 테스트 결과 ─────────────────────────────────────
              if (_testResult != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: _testOk ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(_testOk ? Icons.check_circle : Icons.error,
                          color: _testOk ? Colors.green : Colors.red),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_testResult!,
                          style: TextStyle(
                              color: _testOk ? Colors.green.shade800 : Colors.red.shade800))),
                    ]),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
            color: Color(0xFF1A2236))),
  );

  Widget _ptd(String text, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text(text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color,
        )),
  );
}
