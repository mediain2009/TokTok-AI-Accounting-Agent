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
  // KakaoTalk (카카오 알림톡 REST API)
  final String kakaoApiKey;
  final String kakaoSenderKey;
  final String kakaoPhoneNo;
  final bool kakaoEnabled;

  const MessengerSettings({
    this.id,
    this.telegramBotToken = '',
    this.telegramChatId   = '',
    this.telegramEnabled  = false,
    this.kakaoApiKey      = '',
    this.kakaoSenderKey   = '',
    this.kakaoPhoneNo     = '',
    this.kakaoEnabled     = false,
  });

  factory MessengerSettings.fromMap(Map<String, dynamic> m) => MessengerSettings(
    id:               m['id'] as int?,
    telegramBotToken: (m['telegram_bot_token'] as String?) ?? '',
    telegramChatId:   (m['telegram_chat_id']   as String?) ?? '',
    telegramEnabled:  (m['telegram_enabled']   as int?) == 1,
    kakaoApiKey:      (m['kakao_api_key']       as String?) ?? '',
    kakaoSenderKey:   (m['kakao_sender_key']    as String?) ?? '',
    kakaoPhoneNo:     (m['kakao_phone_no']      as String?) ?? '',
    kakaoEnabled:     (m['kakao_enabled']       as int?) == 1,
  );

  Map<String, dynamic> toMap() => {
    'telegram_bot_token': telegramBotToken,
    'telegram_chat_id':   telegramChatId,
    'telegram_enabled':   telegramEnabled ? 1 : 0,
    'kakao_api_key':      kakaoApiKey,
    'kakao_sender_key':   kakaoSenderKey,
    'kakao_phone_no':     kakaoPhoneNo,
    'kakao_enabled':      kakaoEnabled ? 1 : 0,
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
