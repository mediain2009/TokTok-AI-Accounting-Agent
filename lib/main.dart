import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/invoices_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/purchases_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/partners_screen.dart';
import 'screens/company_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/ai_settings_screen.dart';
import 'screens/messenger_settings_screen.dart';
import 'screens/warehouse_settings_screen.dart';
import 'screens/inventory_items_screen.dart';
import 'screens/inbound_screen.dart';
import 'screens/outbound_screen.dart';
import 'screens/warehouse_transfer_screen.dart';
import 'screens/inventory_status_screen.dart';
import 'widgets/ai_chat_panel.dart';
import 'services/telegram_service.dart';

void main() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const TaxInvoiceApp());
}

class TaxInvoiceApp extends StatelessWidget {
  const TaxInvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TokTok AI; Accounting Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D6EFD)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        dataTableTheme: const DataTableThemeData(
          headingRowColor: WidgetStatePropertyAll(Color(0xFFF8F9FA)),
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
        ),
      ),
      home: const HomeShell(),
    );
  }
}

// ─── Nav item model ────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  final String section;
  const _NavItem({required this.icon, required this.label, this.section = ''});
}

// ─── Top-level groups ──────────────────────────────────────────────────────
const _topMenus = ['계산서', '견적관리', '재고관리', '고객관리', '기초설정'];

const List<List<_NavItem>> _sideNavGroups = [
  // 세금/거래
  [
    _NavItem(icon: Icons.edit_note,      label: '발행',    section: '계산서'),
    _NavItem(icon: Icons.arrow_upward,   label: '매출조회'),
    _NavItem(icon: Icons.arrow_downward, label: '매입조회'),
    _NavItem(icon: Icons.table_chart,    label: '합계표'),
  ],
  // 견적관리
  [
    _NavItem(icon: Icons.request_quote,  label: '견적서',    section: '견적관리'),
    _NavItem(icon: Icons.local_shipping, label: '거래명세표'),
    _NavItem(icon: Icons.savings,        label: '입금표'),
  ],
  // 창고관리
  [
    _NavItem(icon: Icons.warehouse,      label: '창고 설정',  section: '재고관리'),
    _NavItem(icon: Icons.inventory_2,    label: '품목 관리'),
    _NavItem(icon: Icons.move_to_inbox,  label: '입고',        section: '입출고'),
    _NavItem(icon: Icons.outbox,         label: '출고'),
    _NavItem(icon: Icons.swap_horiz,     label: '창고간 이동'),
    _NavItem(icon: Icons.bar_chart,      label: '재고 현황',   section: '현황'),
  ],
  // 고객관리 (거래처 관리 이동)
  [
    _NavItem(icon: Icons.business,       label: '거래처 관리', section: '고객'),
  ],
  // 기본정보
  [
    _NavItem(icon: Icons.business_center, label: '회사정보',   section: '기초설정'),
    _NavItem(icon: Icons.psychology,      label: 'AI 설정'),
    _NavItem(icon: Icons.message,         label: '메신저 설정'),
  ],
];

// ─── HomeShell ─────────────────────────────────────────────────────────────
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int  _topIdx         = 0;
  int  _sideIdx        = 0;
  bool _chatOpen       = false;
  Map<String, dynamic>? _pendingDoc;   // AI가 요청한 문서 자동생성 데이터
  int  _partnerVersion = 0;            // 거래처 등록 시 증가 → PartnersScreen 강제 리로드
  int  _docVersion     = 0;            // AI 문서 등록 시 증가 → DocumentsScreen 강제 리로드
  int  _invoiceVersion = 0;            // AI 세금계산서 등록 시 증가 → InvoicesScreen 강제 리로드

  @override
  void initState() {
    super.initState();
    // 텔레그램 폴링 시작 + UI 갱신 콜백 등록
    TelegramService.onDocCreated      = () { if (mounted) setState(() => _docVersion++); };
    TelegramService.onInvoiceCreated  = () { if (mounted) setState(() => _invoiceVersion++); };
    TelegramService.start();
  }

  @override
  void dispose() {
    TelegramService.stop();
    super.dispose();
  }

  String get _currentScreenName {
    const names = [
      ['발행','매출조회','매입조회','합계표'],
      ['견적서','거래명세표','입금표'],
      ['창고설정','품목관리','입고','출고','창고간이동','재고현황'],
      ['거래처관리'],
      ['회사정보','AI설정','메신저설정'],
    ];
    // 상단 메뉴 이름 변경 반영: 세금/거래→계산서, 창고관리→재고관리, 기본정보→기초설정
    final t = _topIdx.clamp(0, 4);
    final s = _sideIdx.clamp(0, names[t].length - 1);
    return '${_topMenus[t]} > ${names[t][s]}';
  }

  void _navigateTo(int topIdx, int sideIdx) {
    setState(() {
      _topIdx  = topIdx.clamp(0, 4);
      _sideIdx = sideIdx;
    });
  }

  Widget _buildScreen() {
    if (_topIdx == 0) {
      return [
        InvoicesScreen(key: ValueKey('invoices_$_invoiceVersion')),
        const SalesScreen(),
        const PurchasesScreen(),
        const SummaryScreen(),
      ][_sideIdx.clamp(0, 3)];
    }
    if (_topIdx == 1) {
      const types = ['견적서', '거래명세표', '입금표'];
      return DocumentsScreen(
        key: ValueKey('docs_${types[_sideIdx.clamp(0, 2)]}_$_docVersion'),
        docType: types[_sideIdx.clamp(0, 2)],
        pendingCreate: _pendingDoc,
        onPendingConsumed: () => setState(() => _pendingDoc = null),
      );
    }
    if (_topIdx == 2) {
      return [
        const WarehouseSettingsScreen(),
        const InventoryItemsScreen(),
        const InboundScreen(),
        const OutboundScreen(),
        const WarehouseTransferScreen(),
        const InventoryStatusScreen(),
      ][_sideIdx.clamp(0, 5)];
    }
    if (_topIdx == 3) {
      // 고객관리 — 거래처 관리
      return PartnersScreen(key: ValueKey('partners_$_partnerVersion'));
    }
    // 기본정보
    return [
      const CompanyScreen(),
      const AiSettingsScreen(),
      const MessengerSettingsScreen(),
    ][_sideIdx.clamp(0, 2)];
  }

  @override
  Widget build(BuildContext context) {
    final sideNavs = _sideNavGroups[_topIdx];

    return Scaffold(
      body: Column(
        children: [
          // ── Top Navigation Bar ───────────────────────────────────────
          Container(
            height: 46,
            color: const Color(0xFF0D1B33),
            child: Row(
              children: [
                // Brand
                Container(
                  width: 200,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(children: [
                    Icon(Icons.receipt_long, color: Colors.white60, size: 18),
                    SizedBox(width: 8),
                    Text('톡톡AI,간편회계',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ]),
                ),
                // Top menu items
                for (int i = 0; i < _topMenus.length; i++)
                  _TopMenuBtn(
                    label: _topMenus[i],
                    selected: _topIdx == i,
                    onTap: () => setState(() {
                      _topIdx  = i;
                      _sideIdx = 0;
                    }),
                  ),
                const Spacer(),
                // AI 채팅 토글 버튼
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message: _chatOpen ? 'AI 닫기' : 'AI 어시스턴트 열기',
                    child: InkWell(
                      onTap: () => setState(() => _chatOpen = !_chatOpen),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _chatOpen
                              ? const Color(0xFF0D6EFD)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _chatOpen
                                ? const Color(0xFF0D6EFD)
                                : Colors.white30,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.psychology, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _chatOpen ? 'AI 닫기' : 'AI 어시스턴트',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body: Sidebar + Content + AI Panel ──────────────────────
          Expanded(
            child: Row(
              children: [
                // Sidebar
                if (sideNavs.isNotEmpty)
                  Container(
                    width: 200,
                    color: const Color(0xFF1A2236),
                    child: _buildSidebar(sideNavs),
                  ),

                // Main content
                Expanded(child: _buildScreen()),

                // AI 채팅 패널 (슬라이드 인)
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _chatOpen
                      ? AiChatPanel(
                          currentScreen: _currentScreenName,
                          onNavigate: _navigateTo,
                          onCreateDoc: (docType, customer, items) {
                            setState(() {
                              _pendingDoc = {
                                'customerName': customer,
                                'items': items,
                              };
                            });
                          },
                          onPartnerCreated: () {
                            setState(() => _partnerVersion++);
                          },
                          onDocCreated: () {
                            setState(() => _docVersion++);
                          },
                          onInvoiceCreated: () {
                            setState(() => _invoiceVersion++);
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(List<_NavItem> items) {
    String? lastSection;
    final children = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.section.isNotEmpty && item.section != lastSection) {
        lastSection = item.section;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(item.section,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              )),
        ));
      }
      final idx = i;
      children.add(_NavTile(
        item: item,
        selected: _sideIdx == idx,
        onTap: () => setState(() => _sideIdx = idx),
      ));
    }
    return ListView(children: children);
  }
}

// ─── Top Menu Button ───────────────────────────────────────────────────────
class _TopMenuBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TopMenuBtn(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
        height: 46,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFF4D9EFF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─── Sidebar Tile ──────────────────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile(
      {required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: selected ? const Color(0xFF2D3A52) : Colors.transparent,
        child: Row(
          children: [
            Icon(item.icon,
                size: 18,
                color: selected ? Colors.white : Colors.white60),
            const SizedBox(width: 10),
            Text(item.label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white60,
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }
}
