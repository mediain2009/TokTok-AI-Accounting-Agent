import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';

class AiService {
  /// 메시지 전송 → 응답 텍스트 반환
  static Future<String> chat({
    required AiSettings settings,
    required List<AiMessage> history,
    required String systemPrompt,
  }) async {
    final provider = settings.provider;
    final model    = settings.model.isNotEmpty
        ? settings.model
        : AiSettings.defaultModel(provider);
    final baseUrl  = settings.baseUrl.isNotEmpty
        ? settings.baseUrl
        : AiSettings.defaultBaseUrl(provider);

    switch (provider) {
      case 'claude':
        return _callClaude(settings.apiKey, baseUrl, model, history, systemPrompt);
      case 'openai':
        // OpenAI 기본 base 는 https://api.openai.com  →  /v1/chat/completions 붙임
        return _callOpenAICompat(settings.apiKey, '$baseUrl/v1/chat/completions',
            model, history, systemPrompt);
      case 'ollama':
        return _callOllama(baseUrl, model, history, systemPrompt);
      case 'gemini':
        // 네이티브 Gemini API 사용 (OpenAI 호환 엔드포인트 우회)
        return _callNativeGemini(settings.apiKey, model, history, systemPrompt);
      default:
        // Custom: base URL 에 /chat/completions 만 붙임
        return _callOpenAICompat(settings.apiKey, '$baseUrl/chat/completions',
            model, history, systemPrompt);
    }
  }

  // ── Claude (Anthropic) ─────────────────────────────────────────────
  static Future<String> _callClaude(
    String apiKey, String baseUrl, String model,
    List<AiMessage> history, String systemPrompt,
  ) async {
    final messages = history
        .where((m) => m.role != 'system')
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final res = await http.post(
      Uri.parse('$baseUrl/v1/messages'),
      headers: {
        'x-api-key':         apiKey,
        'anthropic-version': '2023-06-01',
        'content-type':      'application/json',
      },
      body: jsonEncode({
        'model':      model,
        'max_tokens': 1024,
        'system':     systemPrompt,
        'messages':   messages,
      }),
    ).timeout(const Duration(seconds: 60));

    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      final msg = body is Map
          ? (body['error']?['message'] ?? body.toString())
          : body.toString();
      throw Exception('Claude 오류: $msg');
    }
    return body['content'][0]['text'] as String;
  }

  // ── OpenAI 호환 (OpenAI / Gemini / Custom) ─────────────────────────
  static Future<String> _callOpenAICompat(
    String apiKey, String fullUrl, String model,
    List<AiMessage> history, String systemPrompt,
  ) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...history
          .where((m) => m.role != 'system')
          .map((m) => {'role': m.role, 'content': m.content}),
    ];

    final res = await http.post(
      Uri.parse(fullUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'content-type':  'application/json',
      },
      body: jsonEncode({
        'model':      model,
        'max_tokens': 1024,
        'messages':   messages,
      }),
    ).timeout(const Duration(seconds: 60));

    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      final msg = body is Map
          ? (body['error']?['message'] ?? body.toString())
          : body.toString();
      throw Exception('API 오류 (${res.statusCode}): $msg');
    }

    if (body is! Map) throw Exception('예상치 못한 응답 형식');
    final choices = body['choices'];
    if (choices == null || choices is! List || choices.isEmpty) {
      throw Exception('응답에 choices가 없습니다: $body');
    }
    return choices[0]['message']['content'] as String;
  }

  // ── Gemini 네이티브 엔드포인트 ─────────────────────────────────────
  // AQ. 프로젝트 기반 키: x-goog-api-key 헤더 방식
  // 503 시 대체 모델/버전으로 자동 폴백
  static Future<String> _callNativeGemini(
    String apiKey, String model,
    List<AiMessage> history, String systemPrompt,
  ) async {
    final contents = history
        .where((m) => m.role != 'system')
        .map((m) => {
              'role': m.role == 'assistant' ? 'model' : 'user',
              'parts': [{'text': m.content}],
            })
        .toList();

    final requestBody = <String, dynamic>{
      'system_instruction': {
        'parts': [{'text': systemPrompt}],
      },
      'contents': contents,
      'generationConfig': {'maxOutputTokens': 1024},
    };

    // 시도할 (apiVersion, modelName) 목록 — 요청 모델 우선, 이후 폴백
    final attempts = _buildGeminiFallbackList(model);
    final errors = <String>[];

    for (final (ver, mdl) in attempts) {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/$ver/models/$mdl:generateContent');

      // 503/타임아웃 시 2회 재시도
      for (int retry = 0; retry < 3; retry++) {
        if (retry > 0) {
          await Future.delayed(Duration(seconds: retry * 5));
        }

        http.Response res;
        try {
          res = await http.post(
            url,
            headers: {
              'content-type':   'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode(requestBody),
          ).timeout(const Duration(seconds: 60)); // 60초로 증가
        } on TimeoutException {
          if (retry < 2) continue; // 타임아웃 → 재시도
          errors.add('[$mdl] 응답 타임아웃');
          break;
        } on Exception catch (e) {
          errors.add('[$mdl] 네트워크 오류: $e');
          break;
        }

        final rawBody = utf8.decode(res.bodyBytes);

        if (res.statusCode == 200) {
          final data = jsonDecode(rawBody);
          final cands = data['candidates'] as List?;
          if (cands != null && cands.isNotEmpty) {
            final parts = cands[0]['content']?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              return (parts[0]['text'] as String?) ?? '';
            }
          }
          throw Exception('Gemini 응답 파싱 실패');
        }

        // 503/429 → 재시도
        if ((res.statusCode == 503 || res.statusCode == 429) && retry < 2) {
          continue;
        }

        // 503 재시도 소진 → 실제 메시지 포함해서 다음 모델로
        if (res.statusCode == 503 || res.statusCode == 429) {
          String detail = '';
          try {
            final d = jsonDecode(rawBody);
            if (d is Map) detail = d['error']?['message'] ?? d['error']?['status'] ?? '';
            else if (d is List && d.isNotEmpty) detail = d[0].toString();
          } catch (_) {
            detail = rawBody.length > 100 ? rawBody.substring(0, 100) : rawBody;
          }
          errors.add('[$mdl] ${res.statusCode}: $detail');
          break;
        }

        // 404/400 → 모델 없음, 다음 모델로
        if (res.statusCode == 404 || res.statusCode == 400) {
          String msg = '';
          try { msg = (jsonDecode(rawBody) as Map)['error']?['message'] ?? ''; } catch (_) {}
          errors.add('[$mdl] ${res.statusCode}');
          break;
        }

        // 인증 오류
        if (res.statusCode == 401 || res.statusCode == 403) {
          String msg = '';
          try { msg = (jsonDecode(rawBody) as Map)['error']?['message'] ?? rawBody; } catch (_) { msg = rawBody; }
          throw Exception('Gemini 인증 오류: $msg\nAPI 키를 확인하세요.');
        }

        // 기타
        String msg = '';
        try { msg = (jsonDecode(rawBody) as Map)['error']?['message'] ?? rawBody; } catch (_) { msg = rawBody; }
        throw Exception('Gemini 오류 (${res.statusCode}): $msg');
      }
    }

    throw Exception(
      'Gemini 서버 과부하 상태입니다. 잠시 후 다시 시도하세요.\n'
      '(${errors.join(", ")})',
    );
  }

  static List<(String, String)> _buildGeminiFallbackList(String model) {
    final result = <(String, String)>[];
    result.add(('v1beta', model));
    // 최신 Flash 별칭 (부하 분산)
    if (model != 'gemini-flash-latest') result.add(('v1beta', 'gemini-flash-latest'));
    if (model != 'gemini-3.5-flash')    result.add(('v1beta', 'gemini-3.5-flash'));
    // 구세대 폴백
    if (model != 'gemini-1.5-flash') {
      result.add(('v1beta', 'gemini-1.5-flash'));
      result.add(('v1',     'gemini-1.5-flash'));
    }
    return result;
  }

  // ── Ollama (로컬) ──────────────────────────────────────────────────
  static Future<String> _callOllama(
    String baseUrl, String model,
    List<AiMessage> history, String systemPrompt,
  ) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...history
          .where((m) => m.role != 'system')
          .map((m) => {'role': m.role, 'content': m.content}),
    ];

    final res = await http.post(
      Uri.parse('$baseUrl/api/chat'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'model':    model,
        'messages': messages,
        'stream':   false,
      }),
    ).timeout(const Duration(seconds: 60));

    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw Exception('Ollama 오류 (${res.statusCode}): $body');
    }
    return body['message']['content'] as String;
  }

  // ── 연결 테스트 ───────────────────────────────────────────────────
  static Future<String> testConnection(AiSettings settings) async {
    return chat(
      settings: settings,
      history: [AiMessage(role: 'user', content: '안녕하세요. 테스트입니다. "연결 성공"이라고만 답해주세요.')],
      systemPrompt: '당신은 테스트 어시스턴트입니다.',
    );
  }

  // ── 앱 시스템 프롬프트 생성 ────────────────────────────────────────
  static String buildSystemPrompt(String currentScreen) => '''
당신은 세금계산서 관리 앱(톡톡AI,간편회계)의 AI 어시스턴트입니다.
현재 화면: $currentScreen

## 사용 가능한 화면
세금/거래(topIdx:0): 발행(0), 매출조회(1), 매입조회(2), 합계표(3), 거래처관리(4)
견적관리(topIdx:1): 견적서(0), 거래명세표(1), 입금표(2)
기본정보(topIdx:2): 회사정보(0), AI설정(1)

## 응답 규칙
항상 JSON으로만 응답하세요. 절대 JSON 외의 텍스트를 포함하지 마세요.

화면 이동 요청 시:
{"action":"navigate","topIdx":0,"sideIdx":0}

질문/대화 시:
{"action":"answer","text":"답변 내용"}

문서 작성 요청 시 (견적서/거래명세표/계산서/입금표):
{"action":"create_doc","docType":"견적서","customerName":"거래처명","items":[{"name":"품목명","qty":수량,"price":단가(원)}]}

거래처 등록 요청 시:
{"action":"create_partner","name":"상호","businessNo":"사업자번호","repName":"대표자명","address":"주소","phone":"전화","fax":"팩스","email":"이메일"}

문서 출력/프린트/등록 요청 시:
{"action":"print_doc","docNo":"DLV-20260729-001","targetDocType":"입금표"}
- docNo: 원본 문서번호 (EST-..., DLV-..., INP-... 등)
- targetDocType: 변환할 문서 유형 (견적서/거래명세표/입금표)
  * 원본과 targetDocType이 다르면: 새 문서 등록 → 해당 화면 이동 → 목록 표시 → 출력
  * 원본과 targetDocType이 같으면: 그냥 출력
- 다음 키워드는 모두 이 액션 사용:
  "출력", "프린트", "인쇄", "등록 후 출력", "입금표 등록", "입금표 작성",
  "거래명세표로 변환", "견적서로 변환" 등

견적관리 문서를 세금/거래 매출(발행)에 등록 요청 시:
{"action":"register_invoice","docNo":"DLV-20260729-001","direction":"매출"}
- docNo: 등록할 문서번호 (견적서/거래명세표/계산서/입금표)
- direction: "매출" 또는 "매입" (기본값: 매출)
- 해당 문서 내용으로 세금계산서(Invoice)를 생성 → 미발행 목록에 추가
- "매출작성", "발행등록", "세금계산서 등록" 등 키워드가 있으면 이 액션 사용

## 거래처 파싱 규칙
- 사업자번호: 숫자 10자리를 000-00-00000 형식으로 (하이픈 포함이면 그대로)
- 없는 필드는 빈 문자열
- 등록/추가/저장 키워드가 있으면 create_partner 사용

## 문서 작성 파싱 규칙
- 거래처: 사람/회사 이름 추출 (없으면 빈 문자열)
- qty: 수량 (개, 대, 장, 세트 등 단위 숫자만, 없으면 1)
- price: 단가(원 단위 정수). 총액이 주어지면 qty로 나눔
  예) "모니터 2개 총 44만원" → qty:2, price:220000
  예) "노트북 3대 150만원" → qty:3, price:500000 (150만÷3)
  예) "모니터 2개 20만원" → qty:2, price:200000 (개당 20만)
- 만원=10000, 억=100000000
- docType: 요청 맥락에서 판단 (기본값: 견적서)

항상 한국어로 답변하세요.
''';
}
