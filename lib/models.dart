class Partner {
  final int? id;
  final String name;
  final String businessNo;
  final String repName;
  final String address;
  final String email;
  final String phone;
  final String fax;

  const Partner({
    this.id,
    required this.name,
    this.businessNo = '',
    this.repName = '',
    this.address = '',
    this.email = '',
    this.phone = '',
    this.fax = '',
  });

  factory Partner.fromMap(Map<String, dynamic> m) => Partner(
        id: m['id'] as int?,
        name: m['name'] as String,
        businessNo: (m['business_no'] as String?) ?? '',
        repName: (m['rep_name'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        fax: (m['fax'] as String?) ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'business_no': businessNo,
        'rep_name': repName,
        'address': address,
        'email': email,
        'phone': phone,
        'fax': fax,
      };
}

class Invoice {
  final int? id;
  final String invoiceDate;
  final String type;       // 과세/영세/면세
  final String direction;  // 매출/매입
  final int? partnerId;
  final int supplyAmount;
  final int taxAmount;
  final int totalAmount;
  final String memo;
  final String billType;   // 영수/청구
  final String issueType;  // 미발행/종이/전자
  final String txStatus;
  final String approvalNo;
  // Joined fields
  final String? partnerName;
  final String? businessNo;

  const Invoice({
    this.id,
    required this.invoiceDate,
    this.type = '과세',
    this.direction = '매출',
    this.partnerId,
    this.supplyAmount = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.memo = '',
    this.billType = '영수',
    this.issueType = '미발행',
    this.txStatus = '',
    this.approvalNo = '',
    this.partnerName,
    this.businessNo,
  });

  factory Invoice.fromMap(Map<String, dynamic> m) => Invoice(
        id: m['id'] as int?,
        invoiceDate: m['invoice_date'] as String,
        type: (m['type'] as String?) ?? '과세',
        direction: (m['direction'] as String?) ?? '매출',
        partnerId: m['partner_id'] as int?,
        supplyAmount: m['supply_amount'] as int? ?? 0,
        taxAmount: m['tax_amount'] as int? ?? 0,
        totalAmount: m['total_amount'] as int? ?? 0,
        memo: (m['memo'] as String?) ?? '',
        billType: (m['bill_type'] as String?) ?? '영수',
        issueType: (m['issue_type'] as String?) ?? '미발행',
        txStatus: (m['tx_status'] as String?) ?? '',
        approvalNo: (m['approval_no'] as String?) ?? '',
        partnerName: m['partner_name'] as String?,
        businessNo: m['business_no'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'invoice_date': invoiceDate,
        'type': type,
        'direction': direction,
        'partner_id': partnerId,
        'supply_amount': supplyAmount,
        'tax_amount': taxAmount,
        'total_amount': totalAmount,
        'memo': memo,
        'bill_type': billType,
        'issue_type': issueType,
        'tx_status': txStatus,
        'approval_no': approvalNo,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
}

class InvoiceItem {
  final int? id;
  final int invoiceId;
  final String itemName;
  final int quantity;
  final int unitPrice;
  final int supplyAmount;
  final int taxAmount;

  const InvoiceItem({
    this.id,
    required this.invoiceId,
    this.itemName = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.supplyAmount = 0,
    this.taxAmount = 0,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> m) => InvoiceItem(
        id: m['id'] as int?,
        invoiceId: m['invoice_id'] as int,
        itemName: (m['item_name'] as String?) ?? '',
        quantity: m['quantity'] as int? ?? 1,
        unitPrice: m['unit_price'] as int? ?? 0,
        supplyAmount: m['supply_amount'] as int? ?? 0,
        taxAmount: m['tax_amount'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'invoice_id': invoiceId,
        'item_name': itemName,
        'quantity': quantity,
        'unit_price': unitPrice,
        'supply_amount': supplyAmount,
        'tax_amount': taxAmount,
      };
}

// ─── Company Info ─────────────────────────────────────────────────────────
class CompanyInfo {
  final int? id;
  final String companyName;
  final String repName;
  final String businessNo;
  final String bizType;
  final String bizItem;
  final String address;
  final String currentAddress;
  final String phone;
  final String fax;
  final String email;
  final String logoPath;
  final String sealPath;
  final String bizStartDate;
  final String fiscalStart;
  final String fiscalEnd;

  const CompanyInfo({
    this.id,
    this.companyName = '',
    this.repName = '',
    this.businessNo = '',
    this.bizType = '',
    this.bizItem = '',
    this.address = '',
    this.currentAddress = '',
    this.phone = '',
    this.fax = '',
    this.email = '',
    this.logoPath = '',
    this.sealPath = '',
    this.bizStartDate = '',
    this.fiscalStart = '',
    this.fiscalEnd = '',
  });

  factory CompanyInfo.fromMap(Map<String, dynamic> m) => CompanyInfo(
    id: m['id'] as int?,
    companyName:    (m['company_name']    as String?) ?? '',
    repName:        (m['rep_name']        as String?) ?? '',
    businessNo:     (m['business_no']     as String?) ?? '',
    bizType:        (m['biz_type']        as String?) ?? '',
    bizItem:        (m['biz_item']        as String?) ?? '',
    address:        (m['address']         as String?) ?? '',
    currentAddress: (m['current_address'] as String?) ?? '',
    phone:          (m['phone']           as String?) ?? '',
    fax:            (m['fax']             as String?) ?? '',
    email:          (m['email']           as String?) ?? '',
    logoPath:       (m['logo_path']       as String?) ?? '',
    sealPath:       (m['seal_path']       as String?) ?? '',
    bizStartDate:   (m['biz_start_date']  as String?) ?? '',
    fiscalStart:    (m['fiscal_start']    as String?) ?? '',
    fiscalEnd:      (m['fiscal_end']      as String?) ?? '',
  );

  Map<String, dynamic> toMap() => {
    'company_name':    companyName,
    'rep_name':        repName,
    'business_no':     businessNo,
    'biz_type':        bizType,
    'biz_item':        bizItem,
    'address':         address,
    'current_address': currentAddress,
    'phone':           phone,
    'fax':             fax,
    'email':           email,
    'logo_path':       logoPath,
    'seal_path':       sealPath,
    'biz_start_date':  bizStartDate,
    'fiscal_start':    fiscalStart,
    'fiscal_end':      fiscalEnd,
  };
}

// ─── Document (견적서/거래명세표/계산서/입금표) ─────────────────────────────
class Document {
  final int? id;
  final String docType;     // 견적서/거래명세표/계산서/입금표
  final String docNo;
  final String docDate;
  final String customerName;
  final String customerBizNo;
  final String customerAddress;
  final String customerContact;
  final int supplyAmount;
  final int taxAmount;
  final int totalAmount;
  final String note;
  final String status;      // 작성/발행

  const Document({
    this.id,
    required this.docType,
    this.docNo = '',
    required this.docDate,
    this.customerName = '',
    this.customerBizNo = '',
    this.customerAddress = '',
    this.customerContact = '',
    this.supplyAmount = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.note = '',
    this.status = '작성',
  });

  factory Document.fromMap(Map<String, dynamic> m) => Document(
    id: m['id'] as int?,
    docType:         (m['doc_type']          as String?) ?? '',
    docNo:           (m['doc_no']            as String?) ?? '',
    docDate:         (m['doc_date']          as String?) ?? '',
    customerName:    (m['customer_name']     as String?) ?? '',
    customerBizNo:   (m['customer_biz_no']   as String?) ?? '',
    customerAddress: (m['customer_address']  as String?) ?? '',
    customerContact: (m['customer_contact']  as String?) ?? '',
    supplyAmount:    m['supply_amount']  as int? ?? 0,
    taxAmount:       m['tax_amount']     as int? ?? 0,
    totalAmount:     m['total_amount']   as int? ?? 0,
    note:            (m['note']             as String?) ?? '',
    status:          (m['status']           as String?) ?? '작성',
  );

  Document copyWith({int? id}) => Document(
    id:              id ?? this.id,
    docType:         docType,
    docNo:           docNo,
    docDate:         docDate,
    customerName:    customerName,
    customerBizNo:   customerBizNo,
    customerAddress: customerAddress,
    customerContact: customerContact,
    supplyAmount:    supplyAmount,
    taxAmount:       taxAmount,
    totalAmount:     totalAmount,
    note:            note,
    status:          status,
  );

  Map<String, dynamic> toMap() => {
    'doc_type':         docType,
    'doc_no':           docNo,
    'doc_date':         docDate,
    'customer_name':    customerName,
    'customer_biz_no':  customerBizNo,
    'customer_address': customerAddress,
    'customer_contact': customerContact,
    'supply_amount':    supplyAmount,
    'tax_amount':       taxAmount,
    'total_amount':     totalAmount,
    'note':             note,
    'status':           status,
  };
}

class DocumentItem {
  final int? id;
  final int docId;
  final String itemName;
  final int quantity;
  final int unitPrice;
  final int supplyAmount;
  final int taxAmount;

  const DocumentItem({
    this.id,
    required this.docId,
    this.itemName = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.supplyAmount = 0,
    this.taxAmount = 0,
  });

  factory DocumentItem.fromMap(Map<String, dynamic> m) => DocumentItem(
    id: m['id'] as int?,
    docId:        m['doc_id']        as int,
    itemName:     (m['item_name']    as String?) ?? '',
    quantity:     m['quantity']      as int? ?? 1,
    unitPrice:    m['unit_price']    as int? ?? 0,
    supplyAmount: m['supply_amount'] as int? ?? 0,
    taxAmount:    m['tax_amount']    as int? ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'doc_id':        docId,
    'item_name':     itemName,
    'quantity':      quantity,
    'unit_price':    unitPrice,
    'supply_amount': supplyAmount,
    'tax_amount':    taxAmount,
  };
}

// ─── AI Settings ──────────────────────────────────────────────────────────────
class AiSettings {
  final int? id;
  final String provider; // claude | openai | ollama | custom
  final String apiKey;
  final String baseUrl;
  final String model;

  const AiSettings({
    this.id,
    this.provider = 'claude',
    this.apiKey   = '',
    this.baseUrl  = '',
    this.model    = '',
  });

  factory AiSettings.fromMap(Map<String, dynamic> m) => AiSettings(
    id:       m['id'] as int?,
    provider: (m['provider'] as String?) ?? 'claude',
    apiKey:   (m['api_key']  as String?) ?? '',
    baseUrl:  (m['base_url'] as String?) ?? '',
    model:    (m['model']    as String?) ?? '',
  );

  Map<String, dynamic> toMap() => {
    'provider': provider,
    'api_key':  apiKey,
    'base_url': baseUrl,
    'model':    model,
  };

  // 프로바이더별 기본 URL
  static String defaultBaseUrl(String provider) => {
    'claude':  'https://api.anthropic.com',
    'openai':  'https://api.openai.com',
    'ollama':  'http://localhost:11434',
    'gemini':  'https://generativelanguage.googleapis.com',
    'custom':  '',
  }[provider] ?? '';

  // 프로바이더별 기본 모델
  static String defaultModel(String provider) => {
    'claude':  'claude-sonnet-4-6',
    'openai':  'gpt-4o-mini',
    'ollama':  'llama3.2',
    'gemini':  'gemini-flash-latest',  // AQ. 키 지원 최신 Flash 별칭
    'custom':  '',
  }[provider] ?? '';
}

// ─── Messenger Settings ───────────────────────────────────────────────────────
class MessengerSettings {
  final int? id;
  // Telegram
  final String telegramBotToken;
  final String telegramChatId;
  final bool telegramEnabled;
  // KakaoTalk 릴레이 (수신 — openclaw relay)
  final String kakaoRelayUrl;    // 기본값: https://k.tess.dev
  final String kakaoRelayToken;  // 페어링 후 발급된 세션 토큰
  final bool kakaoEnabled;
  // KakaoTalk PlayMCP (발신 — 나와의 채팅방 알림)
  final String kakaoPlayMcpAccessToken;
  final String kakaoPlayMcpRefreshToken;
  final bool   kakaoPlayMcpNotify;  // 이벤트 발생 시 나와의채팅방으로 알림
  // KakaoTalk 직접 연결 (자체 채널 + REST API, 외부 릴레이 불필요)
  final String kakaoDirectAccessToken;   // OAuth 액세스 토큰 (나에게 보내기)
  final String kakaoDirectRefreshToken;  // 갱신 토큰
  final bool   kakaoDirectNotify;        // 이벤트 알림 ON/OFF
  final bool   kakaoDirectBotEnabled;    // 채팅봇(수신) ON/OFF
  final int    kakaoDirectPort;          // 내장 웹훅 서버 포트 (기본 18080)
  // KakaoTalk PHP 릴레이 서버 (VPS — 1:1 송수신)
  final String kakaoPhpServerUrl;        // PHP 릴레이 서버 URL (예: https://yourdomain.com/kakao_relay)
  final String kakaoPhpApiKey;           // API 인증 키 (config.php 의 API_KEY)
  final bool   kakaoPhpEnabled;          // PHP 릴레이 활성화
  final String kakaoPhpSendUserId;       // 특정 1명에게 보내기 — 카카오 UUID

  const MessengerSettings({
    this.id,
    this.telegramBotToken        = '',
    this.telegramChatId          = '',
    this.telegramEnabled         = false,
    this.kakaoRelayUrl           = 'https://k.tess.dev',
    this.kakaoRelayToken         = '',
    this.kakaoEnabled            = false,
    this.kakaoPlayMcpAccessToken  = '',
    this.kakaoPlayMcpRefreshToken = '',
    this.kakaoPlayMcpNotify       = false,
    this.kakaoDirectAccessToken   = '',
    this.kakaoDirectRefreshToken  = '',
    this.kakaoDirectNotify        = false,
    this.kakaoDirectBotEnabled    = false,
    this.kakaoDirectPort          = 18080,
    this.kakaoPhpServerUrl        = '',
    this.kakaoPhpApiKey           = '',
    this.kakaoPhpEnabled          = false,
    this.kakaoPhpSendUserId       = '',
  });

  factory MessengerSettings.fromMap(Map<String, dynamic> m) => MessengerSettings(
    id:               m['id'] as int?,
    telegramBotToken: (m['telegram_bot_token'] as String?) ?? '',
    telegramChatId:   (m['telegram_chat_id']   as String?) ?? '',
    telegramEnabled:  (m['telegram_enabled']   as int?) == 1,
    kakaoRelayUrl:    (m['kakao_relay_url']     as String?)?.isNotEmpty == true
                          ? m['kakao_relay_url'] as String
                          : 'https://k.tess.dev',
    kakaoRelayToken:          (m['kakao_relay_token']           as String?) ?? '',
    kakaoEnabled:             (m['kakao_enabled']               as int?) == 1,
    kakaoPlayMcpAccessToken:  (m['kakao_play_mcp_access_token'] as String?) ?? '',
    kakaoPlayMcpRefreshToken: (m['kakao_play_mcp_refresh_token'] as String?) ?? '',
    kakaoPlayMcpNotify:       (m['kakao_play_mcp_notify']       as int?) == 1,
    kakaoDirectAccessToken:  (m['kakao_direct_access_token']  as String?) ?? '',
    kakaoDirectRefreshToken: (m['kakao_direct_refresh_token'] as String?) ?? '',
    kakaoDirectNotify:       (m['kakao_direct_notify']        as int?) == 1,
    kakaoDirectBotEnabled:   (m['kakao_direct_bot_enabled']   as int?) == 1,
    kakaoDirectPort:         (m['kakao_direct_port']          as int?) ?? 18080,
    kakaoPhpServerUrl:       (m['kakao_php_server_url']       as String?) ?? '',
    kakaoPhpApiKey:          (m['kakao_php_api_key']          as String?) ?? '',
    kakaoPhpEnabled:         (m['kakao_php_enabled']          as int?) == 1,
    kakaoPhpSendUserId:      (m['kakao_php_send_user_id']     as String?) ?? '',
  );

  Map<String, dynamic> toMap() => {
    'telegram_bot_token':          telegramBotToken,
    'telegram_chat_id':            telegramChatId,
    'telegram_enabled':            telegramEnabled ? 1 : 0,
    'kakao_relay_url':             kakaoRelayUrl,
    'kakao_relay_token':           kakaoRelayToken,
    'kakao_enabled':               kakaoEnabled ? 1 : 0,
    'kakao_play_mcp_access_token':  kakaoPlayMcpAccessToken,
    'kakao_play_mcp_refresh_token': kakaoPlayMcpRefreshToken,
    'kakao_play_mcp_notify':        kakaoPlayMcpNotify ? 1 : 0,
    'kakao_direct_access_token':  kakaoDirectAccessToken,
    'kakao_direct_refresh_token': kakaoDirectRefreshToken,
    'kakao_direct_notify':        kakaoDirectNotify ? 1 : 0,
    'kakao_direct_bot_enabled':   kakaoDirectBotEnabled ? 1 : 0,
    'kakao_direct_port':          kakaoDirectPort,
    'kakao_php_server_url':       kakaoPhpServerUrl,
    'kakao_php_api_key':          kakaoPhpApiKey,
    'kakao_php_enabled':          kakaoPhpEnabled ? 1 : 0,
    'kakao_php_send_user_id':     kakaoPhpSendUserId,
  };
}

// ─── AI Chat Message ───────────────────────────────────────────────────────────
class AiMessage {
  final String role;    // user | assistant | system
  final String content;
  final DateTime time;
  final bool isError;

  AiMessage({
    required this.role,
    required this.content,
    DateTime? time,
    this.isError = false,
  }) : time = time ?? DateTime.now();
}

// ─── Warehouse Models ─────────────────────────────────────────────────────────

class Warehouse {
  final int? id;
  final String name;
  final String location;
  final String manager;
  final String phone;
  final String note;
  final bool isActive;

  const Warehouse({
    this.id,
    required this.name,
    this.location = '',
    this.manager = '',
    this.phone = '',
    this.note = '',
    this.isActive = true,
  });

  factory Warehouse.fromMap(Map<String, dynamic> m) => Warehouse(
    id:       m['id'] as int?,
    name:     (m['name']     as String?) ?? '',
    location: (m['location'] as String?) ?? '',
    manager:  (m['manager']  as String?) ?? '',
    phone:    (m['phone']    as String?) ?? '',
    note:     (m['note']     as String?) ?? '',
    isActive: (m['is_active'] as int?) == 1,
  );

  Map<String, dynamic> toMap() => {
    'name':      name,
    'location':  location,
    'manager':   manager,
    'phone':     phone,
    'note':      note,
    'is_active': isActive ? 1 : 0,
  };
}

class InventoryItem {
  final int? id;
  final String code;
  final String name;
  final String category;
  final String unit;
  final int costPrice;
  final int sellPrice;
  final int safetyStock;
  final String note;
  final bool isActive;

  const InventoryItem({
    this.id,
    this.code = '',
    required this.name,
    this.category = '',
    this.unit = '개',
    this.costPrice = 0,
    this.sellPrice = 0,
    this.safetyStock = 0,
    this.note = '',
    this.isActive = true,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> m) => InventoryItem(
    id:          m['id'] as int?,
    code:        (m['code']         as String?) ?? '',
    name:        (m['name']         as String?) ?? '',
    category:    (m['category']     as String?) ?? '',
    unit:        (m['unit']         as String?) ?? '개',
    costPrice:   m['cost_price']    as int? ?? 0,
    sellPrice:   m['sell_price']    as int? ?? 0,
    safetyStock: m['safety_stock']  as int? ?? 0,
    note:        (m['note']         as String?) ?? '',
    isActive:    (m['is_active']    as int?) == 1,
  );

  Map<String, dynamic> toMap() => {
    'code':         code,
    'name':         name,
    'category':     category,
    'unit':         unit,
    'cost_price':   costPrice,
    'sell_price':   sellPrice,
    'safety_stock': safetyStock,
    'note':         note,
    'is_active':    isActive ? 1 : 0,
  };
}

class InventoryInbound {
  final int? id;
  final String inboundNo;
  final String inboundDate;
  final int warehouseId;
  final String warehouseName;
  final int itemId;
  final String itemName;
  final String itemUnit;
  final int quantity;
  final int unitPrice;
  final String supplier;
  final String note;
  final String createdAt;

  const InventoryInbound({
    this.id,
    this.inboundNo = '',
    required this.inboundDate,
    required this.warehouseId,
    this.warehouseName = '',
    required this.itemId,
    this.itemName = '',
    this.itemUnit = '개',
    required this.quantity,
    this.unitPrice = 0,
    this.supplier = '',
    this.note = '',
    this.createdAt = '',
  });

  factory InventoryInbound.fromMap(Map<String, dynamic> m) => InventoryInbound(
    id:            m['id'] as int?,
    inboundNo:     (m['inbound_no']    as String?) ?? '',
    inboundDate:   (m['inbound_date']  as String?) ?? '',
    warehouseId:   m['warehouse_id']   as int? ?? 0,
    warehouseName: (m['warehouse_name'] as String?) ?? '',
    itemId:        m['item_id']        as int? ?? 0,
    itemName:      (m['item_name']     as String?) ?? '',
    itemUnit:      (m['item_unit']     as String?) ?? '개',
    quantity:      m['quantity']       as int? ?? 0,
    unitPrice:     m['unit_price']     as int? ?? 0,
    supplier:      (m['supplier']      as String?) ?? '',
    note:          (m['note']          as String?) ?? '',
    createdAt:     (m['created_at']    as String?) ?? '',
  );

  Map<String, dynamic> toMap() => {
    'inbound_no':   inboundNo,
    'inbound_date': inboundDate,
    'warehouse_id': warehouseId,
    'item_id':      itemId,
    'quantity':     quantity,
    'unit_price':   unitPrice,
    'supplier':     supplier,
    'note':         note,
    'created_at':   createdAt,
  };
}

class InventoryOutbound {
  final int? id;
  final String outboundNo;
  final String outboundDate;
  final int warehouseId;
  final String warehouseName;
  final int itemId;
  final String itemName;
  final String itemUnit;
  final int quantity;
  final int unitPrice;
  final String customer;
  final String note;
  final String createdAt;

  const InventoryOutbound({
    this.id,
    this.outboundNo = '',
    required this.outboundDate,
    required this.warehouseId,
    this.warehouseName = '',
    required this.itemId,
    this.itemName = '',
    this.itemUnit = '개',
    required this.quantity,
    this.unitPrice = 0,
    this.customer = '',
    this.note = '',
    this.createdAt = '',
  });

  factory InventoryOutbound.fromMap(Map<String, dynamic> m) => InventoryOutbound(
    id:             m['id'] as int?,
    outboundNo:     (m['outbound_no']   as String?) ?? '',
    outboundDate:   (m['outbound_date'] as String?) ?? '',
    warehouseId:    m['warehouse_id']   as int? ?? 0,
    warehouseName:  (m['warehouse_name'] as String?) ?? '',
    itemId:         m['item_id']        as int? ?? 0,
    itemName:       (m['item_name']     as String?) ?? '',
    itemUnit:       (m['item_unit']     as String?) ?? '개',
    quantity:       m['quantity']       as int? ?? 0,
    unitPrice:      m['unit_price']     as int? ?? 0,
    customer:       (m['customer']      as String?) ?? '',
    note:           (m['note']          as String?) ?? '',
    createdAt:      (m['created_at']    as String?) ?? '',
  );

  Map<String, dynamic> toMap() => {
    'outbound_no':   outboundNo,
    'outbound_date': outboundDate,
    'warehouse_id':  warehouseId,
    'item_id':       itemId,
    'quantity':      quantity,
    'unit_price':    unitPrice,
    'customer':      customer,
    'note':          note,
    'created_at':    createdAt,
  };
}

class InventoryTransfer {
  final int? id;
  final String transferNo;
  final String transferDate;
  final int fromWarehouseId;
  final String fromWarehouseName;
  final int toWarehouseId;
  final String toWarehouseName;
  final int itemId;
  final String itemName;
  final String itemUnit;
  final int quantity;
  final String note;
  final String createdAt;

  const InventoryTransfer({
    this.id,
    this.transferNo = '',
    required this.transferDate,
    required this.fromWarehouseId,
    this.fromWarehouseName = '',
    required this.toWarehouseId,
    this.toWarehouseName = '',
    required this.itemId,
    this.itemName = '',
    this.itemUnit = '개',
    required this.quantity,
    this.note = '',
    this.createdAt = '',
  });

  factory InventoryTransfer.fromMap(Map<String, dynamic> m) => InventoryTransfer(
    id:               m['id'] as int?,
    transferNo:       (m['transfer_no']         as String?) ?? '',
    transferDate:     (m['transfer_date']        as String?) ?? '',
    fromWarehouseId:  m['from_warehouse_id']     as int? ?? 0,
    fromWarehouseName:(m['from_warehouse_name']  as String?) ?? '',
    toWarehouseId:    m['to_warehouse_id']       as int? ?? 0,
    toWarehouseName:  (m['to_warehouse_name']    as String?) ?? '',
    itemId:           m['item_id']               as int? ?? 0,
    itemName:         (m['item_name']            as String?) ?? '',
    itemUnit:         (m['item_unit']            as String?) ?? '개',
    quantity:         m['quantity']              as int? ?? 0,
    note:             (m['note']                as String?) ?? '',
    createdAt:        (m['created_at']           as String?) ?? '',
  );

  Map<String, dynamic> toMap() => {
    'transfer_no':      transferNo,
    'transfer_date':    transferDate,
    'from_warehouse_id': fromWarehouseId,
    'to_warehouse_id':  toWarehouseId,
    'item_id':          itemId,
    'quantity':         quantity,
    'note':             note,
    'created_at':       createdAt,
  };
}

class StockRow {
  final int warehouseId;
  final String warehouseName;
  final int itemId;
  final String itemName;
  final String itemCode;
  final String itemUnit;
  final int safetyStock;
  final int inQty;
  final int outQty;
  final int transferIn;
  final int transferOut;
  int get stock => inQty - outQty + transferIn - transferOut;

  const StockRow({
    required this.warehouseId,
    required this.warehouseName,
    required this.itemId,
    required this.itemName,
    this.itemCode = '',
    this.itemUnit = '개',
    this.safetyStock = 0,
    this.inQty = 0,
    this.outQty = 0,
    this.transferIn = 0,
    this.transferOut = 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class SummaryRow {
  final String partnerName;
  final String businessNo;
  final int count;
  final int supplyTotal;
  final int taxTotal;
  final int grandTotal;

  const SummaryRow({
    required this.partnerName,
    required this.businessNo,
    required this.count,
    required this.supplyTotal,
    required this.taxTotal,
    required this.grandTotal,
  });

  factory SummaryRow.fromMap(Map<String, dynamic> m) => SummaryRow(
        partnerName: (m['name'] as String?) ?? '(거래처 없음)',
        businessNo: (m['business_no'] as String?) ?? '',
        count: m['cnt'] as int? ?? 0,
        supplyTotal: m['supply_total'] as int? ?? 0,
        taxTotal: m['tax_total'] as int? ?? 0,
        grandTotal: m['grand_total'] as int? ?? 0,
      );
}
