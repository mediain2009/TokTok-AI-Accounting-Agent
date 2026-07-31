import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'models.dart';

class DbHelper {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'TaxInvoice', 'invoices.db');
    await Directory(dirname(dbPath)).create(recursive: true);

    return openDatabase(
      dbPath,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE partners (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        business_no TEXT DEFAULT '',
        rep_name    TEXT DEFAULT '',
        address     TEXT DEFAULT '',
        email       TEXT DEFAULT '',
        phone       TEXT DEFAULT '',
        fax         TEXT DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE invoices (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_date  TEXT NOT NULL,
        type          TEXT NOT NULL DEFAULT '과세',
        direction     TEXT NOT NULL DEFAULT '매출',
        partner_id    INTEGER,
        supply_amount INTEGER DEFAULT 0,
        tax_amount    INTEGER DEFAULT 0,
        total_amount  INTEGER DEFAULT 0,
        memo          TEXT DEFAULT '',
        bill_type     TEXT DEFAULT '영수',
        issue_type    TEXT DEFAULT '미발행',
        tx_status     TEXT DEFAULT '',
        approval_no   TEXT DEFAULT '',
        created_at    TEXT,
        updated_at    TEXT,
        FOREIGN KEY(partner_id) REFERENCES partners(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE invoice_items (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id    INTEGER NOT NULL,
        item_name     TEXT DEFAULT '',
        quantity      INTEGER DEFAULT 1,
        unit_price    INTEGER DEFAULT 0,
        supply_amount INTEGER DEFAULT 0,
        tax_amount    INTEGER DEFAULT 0,
        FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');
    await _createNewTables(db);
    await _createV3Tables(db);
    await _createV5Tables(db);
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) await _createNewTables(db);
    if (oldV < 3) await _createV3Tables(db);
    // v4: messenger_settings 테이블 추가
    if (oldV < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS messenger_settings (
          id                  INTEGER PRIMARY KEY AUTOINCREMENT,
          telegram_bot_token  TEXT DEFAULT '',
          telegram_chat_id    TEXT DEFAULT '',
          telegram_enabled    INTEGER DEFAULT 0,
          kakao_api_key       TEXT DEFAULT '',
          kakao_sender_key    TEXT DEFAULT '',
          kakao_phone_no      TEXT DEFAULT '',
          kakao_enabled       INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldV < 5) await _createV5Tables(db);
  }

  static Future<void> _createV5Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouses (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        name      TEXT NOT NULL,
        location  TEXT DEFAULT '',
        manager   TEXT DEFAULT '',
        phone     TEXT DEFAULT '',
        note      TEXT DEFAULT '',
        is_active INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_items (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        code         TEXT DEFAULT '',
        name         TEXT NOT NULL,
        category     TEXT DEFAULT '',
        unit         TEXT DEFAULT '개',
        cost_price   INTEGER DEFAULT 0,
        sell_price   INTEGER DEFAULT 0,
        safety_stock INTEGER DEFAULT 0,
        note         TEXT DEFAULT '',
        is_active    INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_inbound (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        inbound_no   TEXT DEFAULT '',
        inbound_date TEXT NOT NULL,
        warehouse_id INTEGER NOT NULL,
        item_id      INTEGER NOT NULL,
        quantity     INTEGER DEFAULT 0,
        unit_price   INTEGER DEFAULT 0,
        supplier     TEXT DEFAULT '',
        note         TEXT DEFAULT '',
        created_at   TEXT,
        FOREIGN KEY(warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY(item_id)      REFERENCES inventory_items(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_outbound (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        outbound_no   TEXT DEFAULT '',
        outbound_date TEXT NOT NULL,
        warehouse_id  INTEGER NOT NULL,
        item_id       INTEGER NOT NULL,
        quantity      INTEGER DEFAULT 0,
        unit_price    INTEGER DEFAULT 0,
        customer      TEXT DEFAULT '',
        note          TEXT DEFAULT '',
        created_at    TEXT,
        FOREIGN KEY(warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY(item_id)      REFERENCES inventory_items(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_transfer (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_no       TEXT DEFAULT '',
        transfer_date     TEXT NOT NULL,
        from_warehouse_id INTEGER NOT NULL,
        to_warehouse_id   INTEGER NOT NULL,
        item_id           INTEGER NOT NULL,
        quantity          INTEGER DEFAULT 0,
        note              TEXT DEFAULT '',
        created_at        TEXT,
        FOREIGN KEY(from_warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY(to_warehouse_id)   REFERENCES warehouses(id),
        FOREIGN KEY(item_id)           REFERENCES inventory_items(id)
      )
    ''');
  }

  static Future<void> _createNewTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS company_info (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        company_name    TEXT DEFAULT '',
        rep_name        TEXT DEFAULT '',
        business_no     TEXT DEFAULT '',
        biz_type        TEXT DEFAULT '',
        biz_item        TEXT DEFAULT '',
        address         TEXT DEFAULT '',
        current_address TEXT DEFAULT '',
        phone           TEXT DEFAULT '',
        fax             TEXT DEFAULT '',
        email           TEXT DEFAULT '',
        logo_path       TEXT DEFAULT '',
        seal_path       TEXT DEFAULT '',
        biz_start_date  TEXT DEFAULT '',
        fiscal_start    TEXT DEFAULT '',
        fiscal_end      TEXT DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        doc_type         TEXT NOT NULL,
        doc_no           TEXT DEFAULT '',
        doc_date         TEXT NOT NULL,
        customer_name    TEXT DEFAULT '',
        customer_biz_no  TEXT DEFAULT '',
        customer_address TEXT DEFAULT '',
        customer_contact TEXT DEFAULT '',
        supply_amount    INTEGER DEFAULT 0,
        tax_amount       INTEGER DEFAULT 0,
        total_amount     INTEGER DEFAULT 0,
        note             TEXT DEFAULT '',
        status           TEXT DEFAULT '작성',
        created_at       TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_items (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        doc_id        INTEGER NOT NULL,
        item_name     TEXT DEFAULT '',
        quantity      INTEGER DEFAULT 1,
        unit_price    INTEGER DEFAULT 0,
        supply_amount INTEGER DEFAULT 0,
        tax_amount    INTEGER DEFAULT 0,
        FOREIGN KEY(doc_id) REFERENCES documents(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createV3Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_settings (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        provider TEXT DEFAULT 'claude',
        api_key  TEXT DEFAULT '',
        base_url TEXT DEFAULT '',
        model    TEXT DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messenger_settings (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        telegram_bot_token  TEXT DEFAULT '',
        telegram_chat_id    TEXT DEFAULT '',
        telegram_enabled    INTEGER DEFAULT 0,
        kakao_api_key       TEXT DEFAULT '',
        kakao_sender_key    TEXT DEFAULT '',
        kakao_phone_no      TEXT DEFAULT '',
        kakao_enabled       INTEGER DEFAULT 0
      )
    ''');
  }

  // ─── Partners ──────────────────────────────────────────────────────

  static Future<List<Partner>> getPartners() async {
    final d = await db;
    final rows = await d.query('partners', orderBy: 'name');
    return rows.map(Partner.fromMap).toList();
  }

  static Future<int> insertPartner(Partner p) async {
    final d = await db;
    return d.insert('partners', p.toMap());
  }

  static Future<void> updatePartner(Partner p) async {
    final d = await db;
    await d.update('partners', p.toMap(), where: 'id=?', whereArgs: [p.id]);
  }

  static Future<void> deletePartner(int id) async {
    final d = await db;
    await d.delete('partners', where: 'id=?', whereArgs: [id]);
  }

  // ─── Invoices ──────────────────────────────────────────────────────

  static Future<List<Invoice>> getInvoices({
    required String direction,
    required String issueType, // '미발행' | '종이' | '전자' | '전체'
    required String start,
    required String end,
  }) async {
    final d = await db;
    String where;
    if (issueType == '전체') {
      where = "i.direction='$direction' AND i.issue_type IN ('종이','전자','미발행') AND i.invoice_date BETWEEN '$start' AND '$end'";
    } else {
      where = "i.direction='$direction' AND i.issue_type='$issueType' AND i.invoice_date BETWEEN '$start' AND '$end'";
    }
    final rows = await d.rawQuery('''
      SELECT i.*, p.name AS partner_name, p.business_no
      FROM invoices i
      LEFT JOIN partners p ON i.partner_id = p.id
      WHERE $where
      ORDER BY i.invoice_date DESC, i.id DESC
    ''');
    return rows.map(Invoice.fromMap).toList();
  }

  static Future<int> insertInvoice(Invoice inv, List<InvoiceItem> items) async {
    final d = await db;
    final id = await d.insert('invoices', inv.toMap());
    // compute supply/tax from items
    int supply = 0, tax = 0;
    for (final item in items) {
      final it = InvoiceItem(
        invoiceId: id,
        itemName: item.itemName,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        supplyAmount: item.supplyAmount,
        taxAmount: item.taxAmount,
      );
      await d.insert('invoice_items', it.toMap());
      supply += item.supplyAmount;
      tax += item.taxAmount;
    }
    await d.update(
      'invoices',
      {'supply_amount': supply, 'tax_amount': tax, 'total_amount': supply + tax},
      where: 'id=?',
      whereArgs: [id],
    );
    return id;
  }

  static Future<void> issueInvoice(int id, String issueType, String approvalNo) async {
    final d = await db;
    String txStatus;
    if (issueType == '종이') {
      txStatus = '종이발행';
    } else {
      txStatus = approvalNo.isNotEmpty ? '완료' : '임시';
    }
    await d.update(
      'invoices',
      {
        'issue_type': issueType,
        'tx_status': txStatus,
        'approval_no': approvalNo,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteInvoice(int id) async {
    final d = await db;
    await d.delete('invoice_items', where: 'invoice_id=?', whereArgs: [id]);
    await d.delete('invoices', where: 'id=?', whereArgs: [id]);
  }

  static Future<List<InvoiceItem>> getItems(int invoiceId) async {
    final d = await db;
    final rows = await d.query('invoice_items', where: 'invoice_id=?', whereArgs: [invoiceId]);
    return rows.map(InvoiceItem.fromMap).toList();
  }

  // 수정발행: 마이너스 복사본 생성
  static Future<void> modifyIssue(Invoice orig, String reason) async {
    final d = await db;
    final now = DateTime.now().toIso8601String();
    final newId = await d.insert('invoices', {
      'invoice_date': DateTime.now().toString().substring(0, 10),
      'type': orig.type,
      'direction': orig.direction,
      'partner_id': orig.partnerId,
      'supply_amount': -orig.supplyAmount,
      'tax_amount': -orig.taxAmount,
      'total_amount': -orig.totalAmount,
      'memo': '[수정:$reason] ${orig.memo}',
      'bill_type': orig.billType,
      'issue_type': '미발행',
      'tx_status': '',
      'approval_no': '',
      'created_at': now,
      'updated_at': now,
    });
    final items = await getItems(orig.id!);
    for (final item in items) {
      await d.insert('invoice_items', {
        'invoice_id': newId,
        'item_name': item.itemName,
        'quantity': -item.quantity,
        'unit_price': item.unitPrice,
        'supply_amount': -item.supplyAmount,
        'tax_amount': -item.taxAmount,
      });
    }
  }

  // 매입 분류
  static Future<void> classifyPurchase(int id, String issueType) async {
    final d = await db;
    await d.update(
      'invoices',
      {'issue_type': issueType, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  // ─── Summary ───────────────────────────────────────────────────────

  static Future<List<SummaryRow>> getSummary({
    required String year,
    required String startMonth,
    required String endMonth,
    required String direction,
    required String invType, // '세금계산서' | '계산서'
  }) async {
    final d = await db;
    final start = '$year-$startMonth';
    final end   = '$year-$endMonth';
    final typeFilter = invType == '계산서'
        ? "AND i.type = '면세'"
        : "AND i.type IN ('과세', '영세')";
    final rows = await d.rawQuery('''
      SELECT p.name, p.business_no,
             COUNT(*) AS cnt,
             SUM(i.supply_amount) AS supply_total,
             SUM(i.tax_amount)    AS tax_total,
             SUM(i.total_amount)  AS grand_total
      FROM invoices i
      LEFT JOIN partners p ON i.partner_id = p.id
      WHERE i.direction = ?
        $typeFilter
        AND i.issue_type IN ('종이','전자')
        AND i.invoice_date BETWEEN ? AND ?
      GROUP BY i.partner_id
      ORDER BY p.name
    ''', [direction, start, end]);
    return rows.map(SummaryRow.fromMap).toList();
  }

  // ─── Company Info ──────────────────────────────────────────────────

  static Future<CompanyInfo?> getCompanyInfo() async {
    final d = await db;
    final rows = await d.query('company_info', limit: 1);
    if (rows.isEmpty) return null;
    return CompanyInfo.fromMap(rows.first);
  }

  static Future<void> saveCompanyInfo(CompanyInfo info) async {
    final d = await db;
    final existing = await d.query('company_info', limit: 1);
    if (existing.isEmpty) {
      await d.insert('company_info', info.toMap());
    } else {
      await d.update('company_info', info.toMap(),
          where: 'id=?', whereArgs: [existing.first['id']]);
    }
  }

  // ─── Documents (견적서/거래명세표/계산서/입금표) ──────────────────────

  static Future<List<Document>> getDocuments(String docType) async {
    final d = await db;
    final rows = await d.query('documents',
        where: 'doc_type=?', whereArgs: [docType],
        orderBy: 'doc_date DESC, id DESC');
    return rows.map(Document.fromMap).toList();
  }

  static Future<int> insertDocument(Document doc, List<DocumentItem> items) async {
    final d = await db;
    final map = doc.toMap()..['created_at'] = DateTime.now().toIso8601String();
    final id = await d.insert('documents', map);
    int supply = 0, tax = 0;
    for (final item in items) {
      final it = DocumentItem(
        docId: id,
        itemName: item.itemName,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        supplyAmount: item.supplyAmount,
        taxAmount: item.taxAmount,
      );
      await d.insert('document_items', it.toMap());
      supply += item.supplyAmount;
      tax    += item.taxAmount;
    }
    await d.update('documents',
        {'supply_amount': supply, 'tax_amount': tax, 'total_amount': supply + tax},
        where: 'id=?', whereArgs: [id]);
    return id;
  }

  static Future<Document?> getDocumentByNo(String docNo) async {
    final d = await db;
    final rows = await d.query('documents', where: 'doc_no=?', whereArgs: [docNo]);
    if (rows.isEmpty) return null;
    return Document.fromMap(rows.first);
  }

  static Future<List<DocumentItem>> getDocumentItems(int docId) async {
    final d = await db;
    final rows = await d.query('document_items', where: 'doc_id=?', whereArgs: [docId]);
    return rows.map(DocumentItem.fromMap).toList();
  }

  static Future<void> updateDocumentStatus(int id, String status) async {
    final d = await db;
    await d.update('documents', {'status': status}, where: 'id=?', whereArgs: [id]);
  }

  static Future<void> deleteDocument(int id) async {
    final d = await db;
    await d.delete('document_items', where: 'doc_id=?', whereArgs: [id]);
    await d.delete('documents', where: 'id=?', whereArgs: [id]);
  }

  // ─── Messenger Settings ───────────────────────────────────────────

  static Future<MessengerSettings?> getMessengerSettings() async {
    final d = await db;
    final rows = await d.query('messenger_settings', limit: 1);
    if (rows.isEmpty) return null;
    return MessengerSettings.fromMap(rows.first);
  }

  static Future<void> saveMessengerSettings(MessengerSettings s) async {
    final d = await db;
    final existing = await d.query('messenger_settings', limit: 1);
    if (existing.isEmpty) {
      await d.insert('messenger_settings', s.toMap());
    } else {
      await d.update('messenger_settings', s.toMap(),
          where: 'id=?', whereArgs: [existing.first['id']]);
    }
  }

  // ─── AI Settings ──────────────────────────────────────────────────

  static Future<AiSettings?> getAiSettings() async {
    final d = await db;
    final rows = await d.query('ai_settings', limit: 1);
    if (rows.isEmpty) return null;
    return AiSettings.fromMap(rows.first);
  }

  static Future<void> saveAiSettings(AiSettings s) async {
    final d = await db;
    final existing = await d.query('ai_settings', limit: 1);
    if (existing.isEmpty) {
      await d.insert('ai_settings', s.toMap());
    } else {
      await d.update('ai_settings', s.toMap(),
          where: 'id=?', whereArgs: [existing.first['id']]);
    }
  }

  // ─── Warehouses ────────────────────────────────────────────────────

  static Future<List<Warehouse>> getWarehouses({bool activeOnly = false}) async {
    final d = await db;
    final where = activeOnly ? 'is_active=1' : null;
    final rows = await d.query('warehouses', where: where, orderBy: 'id');
    return rows.map(Warehouse.fromMap).toList();
  }

  static Future<int> insertWarehouse(Warehouse w) async {
    final d = await db;
    final map = w.toMap()..['created_at'] = DateTime.now().toIso8601String();
    return d.insert('warehouses', map);
  }

  static Future<void> updateWarehouse(Warehouse w) async {
    final d = await db;
    await d.update('warehouses', w.toMap(), where: 'id=?', whereArgs: [w.id]);
  }

  static Future<void> deleteWarehouse(int id) async {
    final d = await db;
    await d.delete('warehouses', where: 'id=?', whereArgs: [id]);
  }

  // ─── Inventory Items ───────────────────────────────────────────────

  static Future<List<InventoryItem>> getInventoryItems({bool activeOnly = false}) async {
    final d = await db;
    final where = activeOnly ? 'is_active=1' : null;
    final rows = await d.query('inventory_items', where: where, orderBy: 'name');
    return rows.map(InventoryItem.fromMap).toList();
  }

  static Future<int> insertInventoryItem(InventoryItem item) async {
    final d = await db;
    return d.insert('inventory_items', item.toMap());
  }

  static Future<void> updateInventoryItem(InventoryItem item) async {
    final d = await db;
    await d.update('inventory_items', item.toMap(), where: 'id=?', whereArgs: [item.id]);
  }

  static Future<void> deleteInventoryItem(int id) async {
    final d = await db;
    await d.delete('inventory_items', where: 'id=?', whereArgs: [id]);
  }

  // ─── Inventory Inbound ─────────────────────────────────────────────

  static Future<List<InventoryInbound>> getInbounds({
    String? start, String? end, int? warehouseId,
  }) async {
    final d = await db;
    final cond = <String>[];
    final args = <dynamic>[];
    if (warehouseId != null) { cond.add('b.warehouse_id=?'); args.add(warehouseId); }
    if (start != null) { cond.add("b.inbound_date>=?"); args.add(start); }
    if (end != null)   { cond.add("b.inbound_date<=?"); args.add(end); }
    final where = cond.isEmpty ? '' : 'WHERE ${cond.join(' AND ')}';
    final rows = await d.rawQuery('''
      SELECT b.*, w.name AS warehouse_name, i.name AS item_name, i.unit AS item_unit
      FROM inventory_inbound b
      LEFT JOIN warehouses w ON b.warehouse_id = w.id
      LEFT JOIN inventory_items i ON b.item_id = i.id
      $where
      ORDER BY b.inbound_date DESC, b.id DESC
    ''', args);
    return rows.map(InventoryInbound.fromMap).toList();
  }

  static Future<int> insertInbound(InventoryInbound ib) async {
    final d = await db;
    final today = DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    final cnt = Sqflite.firstIntValue(await d.rawQuery(
        "SELECT COUNT(*) FROM inventory_inbound WHERE inbound_date=?", [ib.inboundDate])) ?? 0;
    final no = 'IN-$today-${(cnt + 1).toString().padLeft(3, '0')}';
    final map = ib.toMap()
      ..['inbound_no'] = no
      ..['created_at'] = DateTime.now().toIso8601String();
    return d.insert('inventory_inbound', map);
  }

  static Future<void> deleteInbound(int id) async {
    final d = await db;
    await d.delete('inventory_inbound', where: 'id=?', whereArgs: [id]);
  }

  // ─── Inventory Outbound ────────────────────────────────────────────

  static Future<List<InventoryOutbound>> getOutbounds({
    String? start, String? end, int? warehouseId,
  }) async {
    final d = await db;
    final cond = <String>[];
    final args = <dynamic>[];
    if (warehouseId != null) { cond.add('b.warehouse_id=?'); args.add(warehouseId); }
    if (start != null) { cond.add("b.outbound_date>=?"); args.add(start); }
    if (end != null)   { cond.add("b.outbound_date<=?"); args.add(end); }
    final where = cond.isEmpty ? '' : 'WHERE ${cond.join(' AND ')}';
    final rows = await d.rawQuery('''
      SELECT b.*, w.name AS warehouse_name, i.name AS item_name, i.unit AS item_unit
      FROM inventory_outbound b
      LEFT JOIN warehouses w ON b.warehouse_id = w.id
      LEFT JOIN inventory_items i ON b.item_id = i.id
      $where
      ORDER BY b.outbound_date DESC, b.id DESC
    ''', args);
    return rows.map(InventoryOutbound.fromMap).toList();
  }

  static Future<int> insertOutbound(InventoryOutbound ob) async {
    final d = await db;
    final today = DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    final cnt = Sqflite.firstIntValue(await d.rawQuery(
        "SELECT COUNT(*) FROM inventory_outbound WHERE outbound_date=?", [ob.outboundDate])) ?? 0;
    final no = 'OUT-$today-${(cnt + 1).toString().padLeft(3, '0')}';
    final map = ob.toMap()
      ..['outbound_no'] = no
      ..['created_at'] = DateTime.now().toIso8601String();
    return d.insert('inventory_outbound', map);
  }

  static Future<void> deleteOutbound(int id) async {
    final d = await db;
    await d.delete('inventory_outbound', where: 'id=?', whereArgs: [id]);
  }

  // ─── Inventory Transfer ────────────────────────────────────────────

  static Future<List<InventoryTransfer>> getTransfers({
    String? start, String? end,
  }) async {
    final d = await db;
    final cond = <String>[];
    final args = <dynamic>[];
    if (start != null) { cond.add("t.transfer_date>=?"); args.add(start); }
    if (end != null)   { cond.add("t.transfer_date<=?"); args.add(end); }
    final where = cond.isEmpty ? '' : 'WHERE ${cond.join(' AND ')}';
    final rows = await d.rawQuery('''
      SELECT t.*,
             wf.name AS from_warehouse_name,
             wt.name AS to_warehouse_name,
             i.name  AS item_name,
             i.unit  AS item_unit
      FROM inventory_transfer t
      LEFT JOIN warehouses wf ON t.from_warehouse_id = wf.id
      LEFT JOIN warehouses wt ON t.to_warehouse_id   = wt.id
      LEFT JOIN inventory_items i ON t.item_id = i.id
      $where
      ORDER BY t.transfer_date DESC, t.id DESC
    ''', args);
    return rows.map(InventoryTransfer.fromMap).toList();
  }

  static Future<int> insertTransfer(InventoryTransfer tr) async {
    final d = await db;
    final today = DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    final cnt = Sqflite.firstIntValue(await d.rawQuery(
        "SELECT COUNT(*) FROM inventory_transfer WHERE transfer_date=?", [tr.transferDate])) ?? 0;
    final no = 'TR-$today-${(cnt + 1).toString().padLeft(3, '0')}';
    final map = tr.toMap()
      ..['transfer_no'] = no
      ..['created_at'] = DateTime.now().toIso8601String();
    return d.insert('inventory_transfer', map);
  }

  static Future<void> deleteTransfer(int id) async {
    final d = await db;
    await d.delete('inventory_transfer', where: 'id=?', whereArgs: [id]);
  }

  // ─── Stock Status (재고현황) ────────────────────────────────────────

  static Future<List<StockRow>> getStockStatus({int? warehouseId}) async {
    final d = await db;
    final wFilter = warehouseId != null ? 'AND b.warehouse_id=$warehouseId' : '';
    final wFilterOut = warehouseId != null ? 'AND o.warehouse_id=$warehouseId' : '';
    final wFilterTrIn  = warehouseId != null ? 'AND t.to_warehouse_id=$warehouseId' : '';
    final wFilterTrOut = warehouseId != null ? 'AND t.from_warehouse_id=$warehouseId' : '';

    // 입고합계
    final inRows = await d.rawQuery('''
      SELECT b.warehouse_id, b.item_id, SUM(b.quantity) AS total
      FROM inventory_inbound b WHERE 1=1 $wFilter
      GROUP BY b.warehouse_id, b.item_id
    ''');
    // 출고합계
    final outRows = await d.rawQuery('''
      SELECT o.warehouse_id, o.item_id, SUM(o.quantity) AS total
      FROM inventory_outbound o WHERE 1=1 $wFilterOut
      GROUP BY o.warehouse_id, o.item_id
    ''');
    // 이동 입고합계
    final trInRows = await d.rawQuery('''
      SELECT t.to_warehouse_id AS warehouse_id, t.item_id, SUM(t.quantity) AS total
      FROM inventory_transfer t WHERE 1=1 $wFilterTrIn
      GROUP BY t.to_warehouse_id, t.item_id
    ''');
    // 이동 출고합계
    final trOutRows = await d.rawQuery('''
      SELECT t.from_warehouse_id AS warehouse_id, t.item_id, SUM(t.quantity) AS total
      FROM inventory_transfer t WHERE 1=1 $wFilterTrOut
      GROUP BY t.from_warehouse_id, t.item_id
    ''');

    // 집계용 맵
    Map<String, int> inMap = {}, outMap = {}, trInMap = {}, trOutMap = {};
    for (final r in inRows)    inMap['${r['warehouse_id']}_${r['item_id']}']    = r['total'] as int? ?? 0;
    for (final r in outRows)   outMap['${r['warehouse_id']}_${r['item_id']}']   = r['total'] as int? ?? 0;
    for (final r in trInRows)  trInMap['${r['warehouse_id']}_${r['item_id']}']  = r['total'] as int? ?? 0;
    for (final r in trOutRows) trOutMap['${r['warehouse_id']}_${r['item_id']}'] = r['total'] as int? ?? 0;

    // 창고 × 품목 조합
    final keys = <String>{...inMap.keys, ...outMap.keys, ...trInMap.keys, ...trOutMap.keys};
    if (keys.isEmpty) return [];

    final wRows = await d.query('warehouses', where: 'is_active=1');
    final iRows = await d.query('inventory_items', where: 'is_active=1');
    final wMap = {for (final r in wRows) r['id'] as int: r};
    final iMap = {for (final r in iRows) r['id'] as int: r};

    final result = <StockRow>[];
    for (final key in keys) {
      final parts = key.split('_');
      final wid = int.tryParse(parts[0]) ?? 0;
      final iid = int.tryParse(parts[1]) ?? 0;
      final w = wMap[wid];
      final i = iMap[iid];
      result.add(StockRow(
        warehouseId:   wid,
        warehouseName: (w?['name'] as String?) ?? '(삭제됨)',
        itemId:        iid,
        itemName:      (i?['name'] as String?) ?? '(삭제됨)',
        itemCode:      (i?['code'] as String?) ?? '',
        itemUnit:      (i?['unit'] as String?) ?? '개',
        safetyStock:   i?['safety_stock'] as int? ?? 0,
        inQty:         inMap[key] ?? 0,
        outQty:        outMap[key] ?? 0,
        transferIn:    trInMap[key] ?? 0,
        transferOut:   trOutMap[key] ?? 0,
      ));
    }
    result.sort((a, b) {
      final w = a.warehouseName.compareTo(b.warehouseName);
      return w != 0 ? w : a.itemName.compareTo(b.itemName);
    });
    return result;
  }

  // 다음 문서 번호 자동 생성 (예: EST-20260729-001)
  static Future<String> nextDocNo(String docType) async {
    final d = await db;
    final prefix = {
      '견적서':   'EST',
      '거래명세표': 'DLV',
      '계산서':   'INV',
      '입금표':   'RCP',
    }[docType] ?? 'DOC';
    final today = DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    final rows = await d.rawQuery(
        "SELECT COUNT(*) AS cnt FROM documents WHERE doc_type=? AND doc_date=?",
        [docType, DateTime.now().toString().substring(0, 10)]);
    final cnt = (rows.first['cnt'] as int? ?? 0) + 1;
    return '$prefix-$today-${cnt.toString().padLeft(3, '0')}';
  }
}
