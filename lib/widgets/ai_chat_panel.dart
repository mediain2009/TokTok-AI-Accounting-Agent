import 'dart:convert';
import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import '../services/ai_service.dart';
import '../services/pdf_service.dart';

typedef NavigateCallback = void Function(int topIdx, int sideIdx);
typedef CreateDocCallback = void Function(String docType, String customerName,
    List<Map<String, dynamic>> items);

class AiChatPanel extends StatefulWidget {
  final String currentScreen;
  final NavigateCallback onNavigate;
  final CreateDocCallback? onCreateDoc;
  final VoidCallback? onPartnerCreated;  // 거래처 등록 후 목록 갱신
  final VoidCallback? onDocCreated;      // 문서 등록 후 목록 강제 리로드
  final VoidCallback? onInvoiceCreated;  // 세금계산서 등록 후 발행 목록 갱신

  const AiChatPanel({
    super.key,
    required this.currentScreen,
    required this.onNavigate,
    this.onCreateDoc,
    this.onPartnerCreated,
    this.onDocCreated,
    this.onInvoiceCreated,
  });

  @override
  State<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends State<AiChatPanel> {
  final _inputC    = TextEditingController();
  final _scrollCtl = ScrollController();
  final List<AiMessage> _messages = [];
  AiSettings? _settings;
  bool _thinking = false;
  bool _noSettings = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // 웰컴 메시지
    _messages.add(AiMessage(
      role: 'assistant',
      content: '안녕하세요! 톡톡AI,간편회계 AI 어시스턴트입니다.\n\n화면 이동, 문서 작성, 거래처 등록 등을 자연어로 도와드립니다.\n\n예시:\n• "견적서 화면으로 이동해줘"\n• "ABC회사 노트북 2대 150만원 견적서 작성"\n• "거래처 등록해줘"',
    ));
  }

  @override
  void dispose() {
    _inputC.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final s = await DbHelper.getAiSettings();
    setState(() {
      _settings = s;
      _noSettings = (s == null || (s.apiKey.isEmpty && s.provider != 'ollama'));
    });
  }

  Future<void> _send() async {
    final text = _inputC.text.trim();
    if (text.isEmpty) return;

    _inputC.clear();
    setState(() {
      _messages.add(AiMessage(role: 'user', content: text));
      _thinking = true;
    });
    _scrollToBottom();

    if (_settings == null ||
        (_settings!.apiKey.isEmpty && _settings!.provider != 'ollama')) {
      setState(() {
        _thinking = false;
        _messages.add(AiMessage(
          role: 'assistant',
          content: 'AI 설정이 필요합니다.\n회사정보 > AI설정 메뉴에서 API 키를 등록하세요.',
          isError: true,
        ));
      });
      _scrollToBottom();
      return;
    }

    try {
      final systemPrompt = AiService.buildSystemPrompt(widget.currentScreen);
      final response = await AiService.chat(
        settings: _settings!,
        history: _messages.where((m) => !m.isError).toList(),
        systemPrompt: systemPrompt,
      );

      await _handleResponse(response);
    } catch (e) {
      setState(() {
        _messages.add(AiMessage(
          role: 'assistant',
          content: '오류가 발생했습니다: $e',
          isError: true,
        ));
      });
    } finally {
      setState(() => _thinking = false);
      _scrollToBottom();
    }
  }

  Future<void> _handleResponse(String raw) async {
    // JSON 추출 시도
    String? jsonStr;
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    if (jsonMatch != null) {
      jsonStr = jsonMatch.group(0);
    }

    if (jsonStr != null) {
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final action = data['action'] as String?;

        if (action == 'navigate') {
          final topIdx  = data['topIdx']  as int? ?? 0;
          final sideIdx = data['sideIdx'] as int? ?? 0;
          final screenNames = _screenName(topIdx, sideIdx);
          setState(() {
            _messages.add(AiMessage(
              role: 'assistant',
              content: '[$screenNames] 화면으로 이동합니다.',
            ));
          });
          Future.delayed(const Duration(milliseconds: 300), () {
            widget.onNavigate(topIdx, sideIdx);
          });
          return;
        }

        if (action == 'answer') {
          final text = data['text'] as String? ?? raw;
          setState(() => _messages.add(AiMessage(role: 'assistant', content: text)));
          return;
        }

        if (action == 'print_doc') {
          final docNo         = data['docNo']         as String? ?? '';
          final targetDocType = data['targetDocType'] as String? ?? '';
          setState(() => _messages.add(AiMessage(
            role: 'assistant', content: '🖨️ 문서를 준비 중입니다...',
          )));
          try {
            // 원본 문서 조회
            Document? srcDoc = await DbHelper.getDocumentByNo(docNo);
            if (srcDoc == null) {
              throw Exception('문서번호 $docNo 를 찾을 수 없습니다.');
            }
            final srcItems = await DbHelper.getDocumentItems(srcDoc.id!);

            // 문서 유형이 다르면 새로운 유형으로 복사 등록
            Document printDoc = srcDoc;
            List<DocumentItem> printItems = srcItems;
            if (targetDocType.isNotEmpty && targetDocType != srcDoc.docType) {
              final newDocNo = await DbHelper.nextDocNo(targetDocType);
              final newDoc = Document(
                docType:         targetDocType,
                docNo:           newDocNo,
                docDate:         srcDoc.docDate,
                customerName:    srcDoc.customerName,
                customerBizNo:   srcDoc.customerBizNo,
                customerAddress: srcDoc.customerAddress,
                customerContact: srcDoc.customerContact,
                supplyAmount:    srcDoc.supplyAmount,
                taxAmount:       srcDoc.taxAmount,
                totalAmount:     srcDoc.totalAmount,
                note:            srcDoc.note,
              );
              final newId = await DbHelper.insertDocument(newDoc, srcItems);
              printDoc   = newDoc.copyWith(id: newId);
              printItems = srcItems;

              // 1단계: 해당 화면으로 이동
              final docIdx = ['견적서','거래명세표','입금표'].indexOf(targetDocType);
              widget.onNavigate(1, docIdx < 0 ? 0 : docIdx);

              // 2단계: 목록 강제 갱신 (ValueKey 변경 → initState → _load())
              widget.onDocCreated?.call();
              setState(() => _messages.add(AiMessage(
                role: 'assistant',
                content: '✅ $targetDocType ($newDocNo) 등록 완료\n목록에 반영 중...',
              )));

              // 3단계: 목록 로딩 완료 대기
              await Future.delayed(const Duration(milliseconds: 800));
            }

            setState(() => _messages.add(AiMessage(
              role: 'assistant', content: '🖨️ 인쇄 창을 엽니다...',
            )));
            final company = await DbHelper.getCompanyInfo();
            await PdfService.printDocument(
              doc: printDoc, items: printItems, company: company,
            );
            setState(() => _messages.add(AiMessage(
              role: 'assistant', content: '✅ 인쇄 완료',
            )));
          } catch (e) {
            setState(() => _messages.add(AiMessage(
              role: 'assistant', content: '프린트 오류: $e', isError: true,
            )));
          }
          return;
        }

        if (action == 'create_partner') {
          final partner = Partner(
            name:       (data['name']       as String?) ?? '',
            businessNo: (data['businessNo'] as String?) ?? '',
            repName:    (data['repName']    as String?) ?? '',
            address:    (data['address']    as String?) ?? '',
            phone:      (data['phone']      as String?) ?? '',
            fax:        (data['fax']        as String?) ?? '',
            email:      (data['email']      as String?) ?? '',
          );
          try {
            await DbHelper.insertPartner(partner);
            setState(() {
              _messages.add(AiMessage(
                role: 'assistant',
                content: '✅ 거래처가 등록되었습니다!\n\n'
                    '상호: ${partner.name}\n'
                    '사업자번호: ${partner.businessNo}\n'
                    '대표자: ${partner.repName}\n'
                    '주소: ${partner.address}\n'
                    '전화: ${partner.phone}',
              ));
            });
            // 거래처 관리 화면으로 이동 (고객관리 탭) + 목록 갱신
            widget.onPartnerCreated?.call();
            widget.onNavigate(3, 0);
          } catch (e) {
            setState(() {
              _messages.add(AiMessage(
                role: 'assistant',
                content: '거래처 등록 중 오류가 발생했습니다: $e',
                isError: true,
              ));
            });
          }
          return;
        }

        if (action == 'register_invoice') {
          final docNo     = data['docNo']     as String? ?? '';
          final direction = data['direction'] as String? ?? '매출';
          setState(() => _messages.add(AiMessage(
            role: 'assistant', content: '📋 $docNo → $direction 등록 중...',
          )));
          try {
            // 1. 원본 문서 조회
            final srcDoc = await DbHelper.getDocumentByNo(docNo);
            if (srcDoc == null) {
              throw Exception('문서번호 $docNo 를 찾을 수 없습니다.');
            }
            final srcItems = await DbHelper.getDocumentItems(srcDoc.id!);

            // 2. 거래처 조회 (이름으로 검색, 없으면 null)
            int? partnerId;
            if (srcDoc.customerName.isNotEmpty) {
              final partners = await DbHelper.getPartners();
              final found = partners.where(
                (p) => p.name.contains(srcDoc.customerName) ||
                       srcDoc.customerName.contains(p.name),
              ).toList();
              if (found.isNotEmpty) {
                partnerId = found.first.id;
              } else {
                // 거래처 없으면 자동 등록
                final newPartnerId = await DbHelper.insertPartner(Partner(
                  name:       srcDoc.customerName,
                  businessNo: srcDoc.customerBizNo,
                  address:    srcDoc.customerAddress,
                  phone:      srcDoc.customerContact,
                ));
                partnerId = newPartnerId;
              }
            }

            // 3. Invoice 생성
            final invoice = Invoice(
              invoiceDate: srcDoc.docDate,
              direction:   direction,
              type:        '과세',
              partnerId:   partnerId,
              billType:    '영수',
              issueType:   '미발행',
              txStatus:    '',
              memo:        srcDoc.note,
            );

            // 4. InvoiceItems 변환
            final invoiceItems = srcItems.map((di) => InvoiceItem(
              invoiceId:    0, // insertInvoice 내부에서 설정됨
              itemName:     di.itemName,
              quantity:     di.quantity,
              unitPrice:    di.unitPrice,
              supplyAmount: di.supplyAmount,
              taxAmount:    di.taxAmount,
            )).toList();

            await DbHelper.insertInvoice(invoice, invoiceItems);

            // 5. 발행 화면으로 이동 + 목록 갱신
            widget.onNavigate(0, 0);
            widget.onInvoiceCreated?.call();

            setState(() => _messages.add(AiMessage(
              role: 'assistant',
              content: '✅ $direction 등록 완료!\n'
                  '문서: $docNo\n'
                  '거래처: ${srcDoc.customerName}\n'
                  '공급가: ${_fmtAmount(srcDoc.supplyAmount)}원\n'
                  '세액: ${_fmtAmount(srcDoc.taxAmount)}원\n'
                  '합계: ${_fmtAmount(srcDoc.totalAmount)}원\n\n'
                  '계산서 > 발행 > 미발행 목록에서 확인하세요.',
            )));
          } catch (e) {
            setState(() => _messages.add(AiMessage(
              role: 'assistant', content: '등록 오류: $e', isError: true,
            )));
          }
          return;
        }

        if (action == 'create_doc') {
          final docType      = data['docType']      as String? ?? '견적서';
          final customerName = data['customerName'] as String? ?? '';
          final rawItems     = data['items'] as List? ?? [];
          final items = rawItems.cast<Map<String, dynamic>>();

          setState(() => _messages.add(AiMessage(
            role: 'assistant',
            content: '$docType 작성 중...',
          )));

          try {
            final docNo = await DbHelper.nextDocNo(docType);
            final today = DateTime.now().toString().substring(0, 10);

            // 품목 변환 (공급가 = qty × price, 세액 = 공급가 × 10%)
            final docItems = items.map((it) {
              final qty    = (it['qty']   as num?)?.toInt() ?? 1;
              final price  = (it['price'] as num?)?.toInt() ?? 0;
              final supply = qty * price;
              final tax    = (supply * 0.1).round();
              return DocumentItem(
                docId:        0,
                itemName:     (it['name'] as String?) ?? '',
                quantity:     qty,
                unitPrice:    price,
                supplyAmount: supply,
                taxAmount:    tax,
              );
            }).toList();

            final doc = Document(
              docType:      docType,
              docNo:        docNo,
              docDate:      today,
              customerName: customerName,
            );

            await DbHelper.insertDocument(doc, docItems);

            // 해당 화면으로 이동 + 목록 강제 갱신
            final docIdx = ['견적서','거래명세표','입금표'].indexOf(docType);
            widget.onNavigate(1, docIdx < 0 ? 0 : docIdx);
            widget.onDocCreated?.call();

            final totalSupply = docItems.fold(0, (s, i) => s + i.supplyAmount);
            final totalTax    = docItems.fold(0, (s, i) => s + i.taxAmount);

            setState(() => _messages.add(AiMessage(
              role: 'assistant',
              content: '✅ $docType 등록 완료!\n'
                  '문서번호: $docNo\n'
                  '거래처: $customerName\n'
                  '품목: ${docItems.length}개\n'
                  '공급가액: ${_fmtAmount(totalSupply)}원\n'
                  '세액: ${_fmtAmount(totalTax)}원\n'
                  '합계: ${_fmtAmount(totalSupply + totalTax)}원',
            )));
          } catch (e) {
            setState(() => _messages.add(AiMessage(
              role: 'assistant',
              content: '문서 등록 오류: $e',
              isError: true,
            )));
          }
          return;
        }
      } catch (_) {
        // JSON 파싱 실패 → 일반 텍스트로
      }
    }

    // JSON이 아닌 텍스트 응답
    setState(() => _messages.add(AiMessage(role: 'assistant', content: raw)));
  }

  String _fmtAmount(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _screenName(int t, int s) {
    const screens = [
      ['발행','매출조회','매입조회','합계표'],
      ['견적서','거래명세표','입금표'],
      ['창고설정','품목관리','입고','출고','창고간이동','재고현황'],
      ['거래처관리'],
      ['회사정보','AI설정','메신저설정'],
    ];
    if (t < screens.length && s < screens[t].length) return screens[t][s];
    return '알 수 없음';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtl.hasClients) {
        _scrollCtl.animateTo(
          _scrollCtl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: Container(
        width: 360,
        color: const Color(0xFFF8F9FA),
        child: Column(
          children: [
            // ── 패널 헤더 ────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF0D1B33),
              child: Row(children: [
                const Icon(Icons.psychology, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                const Text('AI 어시스턴트',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_noSettings)
                  const Tooltip(
                    message: 'AI 설정이 필요합니다',
                    child: Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                  ),
              ]),
            ),

            // ── 메시지 목록 ──────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: _scrollCtl,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length + (_thinking ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (_thinking && i == _messages.length) {
                    return _ThinkingBubble();
                  }
                  return _MessageBubble(msg: _messages[i]);
                },
              ),
            ),

            // ── 빠른 명령어 칩 ───────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(children: [
                for (final cmd in [
                  '견적서 열어줘',
                  '매출조회 이동',
                  '거래처 관리',
                  'AI 설정',
                  '사용법 알려줘',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(cmd, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        _inputC.text = cmd;
                        _send();
                      },
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
              ]),
            ),

            // ── 입력창 ───────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _inputC,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _thinking ? null : _send(),
                    decoration: InputDecoration(
                      hintText: '메시지를 입력하세요...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _thinking ? null : _send,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6EFD),
                    foregroundColor: Colors.white,
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 메시지 말풍선 ─────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final AiMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: msg.isError
                  ? Colors.red.shade100
                  : const Color(0xFF0D1B33),
              child: Icon(
                msg.isError ? Icons.error : Icons.psychology,
                size: 14,
                color: msg.isError ? Colors.red : Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF0D6EFD)
                    : msg.isError
                        ? const Color(0xFFFFEBEE)
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft:     Radius.circular(isUser ? 12 : 2),
                  topRight:    Radius.circular(isUser ? 2  : 12),
                  bottomLeft:  const Radius.circular(12),
                  bottomRight: const Radius.circular(12),
                ),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )],
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                  fontSize: 13,
                  color: isUser
                      ? Colors.white
                      : msg.isError
                          ? Colors.red.shade800
                          : Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── 생각 중 애니메이션 ─────────────────────────────────────────────────────────
class _ThinkingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        const CircleAvatar(
          radius: 14,
          backgroundColor: Color(0xFF0D1B33),
          child: Icon(Icons.psychology, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )],
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            _Dot(delay: 0),
            SizedBox(width: 4),
            _Dot(delay: 200),
            SizedBox(width: 4),
            _Dot(delay: 400),
          ]),
        ),
      ]),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _anim =
      Tween<double>(begin: 0, end: 1).animate(_ctrl);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B33),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
