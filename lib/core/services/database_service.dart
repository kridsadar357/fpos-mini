import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../constants/app_constants.dart';
import 'database_import_report.dart';

/// SQLite persistence layer.
/// Optimized for Thai Fuel Station operations.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'fuel_pos_v2.db'; // V2 for schema overhaul
  static const _dbVersion = 13;

  static int get schemaVersion => _dbVersion;

  /// Minimum backup schema version accepted for import.
  static const int minImportVersion = 2;

  /// Core tables that must exist in any FUEL POS backup.
  static const List<String> coreImportTables = [
    'users',
    'fuel_types',
    'tanks',
    'dispensers',
    'nozzles',
    'transactions',
    'settings',
    'audit_log',
  ];

  /// Tables required after migration to the current app schema.
  static const List<String> currentSchemaTables = [
    ...coreImportTables,
    'suspended_sales',
    'customers',
    'products',
    'product_stock_movements',
    'shifts',
    'promotions',
    'discounts',
    'suppliers',
    'fuel_deliveries',
  ];

  Database? _db;
  Future<void> _opChain = Future.value();
  String? _testDbPath;

  /// Serialize DB access so close/restore cannot race with queries.
  Future<T> _runLocked<T>(Future<T> Function() action) {
    final run = _opChain.then((_) => action());
    _opChain = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<Database> _openIfNeeded() async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> get database => _runLocked(_openIfNeeded);

  Future<String> get databasePath async {
    if (_testDbPath != null) return _testDbPath!;
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbName);
  }

  Future<Database> _open() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
    final path = _testDbPath ?? (kIsWeb ? _dbName : await databasePath);
    if (_testDbPath == null && !kIsWeb) {
      await _snapshotBeforeUpgrade(path);
    }
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.rawQuery('PRAGMA journal_mode = WAL');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _ensureCustomerColumns(db);
    await _seedV2(db);
    return db;
  }

  /// Adds customer invoice/CRM columns missing from DBs created before v4.
  Future<void> _ensureCustomerColumns(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='customers'",
    );
    if (tables.isEmpty) return;

    final cols = await db.rawQuery('PRAGMA table_info(customers)');
    final names = cols.map((c) => c['name'] as String).toSet();

    for (final col in [
      'tax_id TEXT',
      "branch_no TEXT DEFAULT '00000'",
      'address TEXT',
      'postal_code TEXT',
      'email TEXT',
      'contact_name TEXT',
      "customer_type TEXT NOT NULL DEFAULT 'company'",
      'vehicle_plate TEXT',
      'note TEXT',
    ]) {
      final colName = col.split(' ').first;
      if (names.contains(colName)) continue;
      try {
        await db.execute('ALTER TABLE customers ADD COLUMN $col');
      } catch (_) {}
    }

    final txTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='transactions'",
    );
    if (txTables.isEmpty) return;

    final txCols = await db.rawQuery('PRAGMA table_info(transactions)');
    final txNames = txCols.map((c) => c['name'] as String).toSet();
    if (!txNames.contains('customer_id')) {
      try {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN customer_id INTEGER');
      } catch (_) {}
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suspended_sales(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cashier_id INTEGER NOT NULL,
          payload TEXT NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY(cashier_id) REFERENCES users(id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          fleet_card_no TEXT,
          company TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS products(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          price REAL NOT NULL,
          sku TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');
      try {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN product_id INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN notes TEXT');
      } catch (_) {}
      await _seedSampleProducts(db);
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shifts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          opened_at TEXT NOT NULL,
          closed_at TEXT,
          opening_cash REAL NOT NULL DEFAULT 0,
          closing_cash REAL,
          status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','closed')),
          FOREIGN KEY(user_id) REFERENCES users(id)
        )
      ''');
      try {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN shift_id INTEGER');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      await _ensureCustomerColumns(db);
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
            "ALTER TABLE transactions ADD COLUMN sale_type TEXT NOT NULL DEFAULT 'fuel'");
      } catch (_) {}
      await db.execute('''
        UPDATE transactions SET sale_type = 'product'
        WHERE product_id IS NOT NULL OR receipt_no LIKE 'PD-%' OR liters <= 0
      ''');
    }
    if (oldVersion < 6) {
      await _syncFuelBrandColors(db);
    }
    if (oldVersion < 7) {
      await _createSupplierTables(db);
    }
    if (oldVersion < 8) {
      await _upgradeSupplierDocumentFields(db);
    }
    if (oldVersion < 9) {
      await _upgradeFuelImportBatchFields(db);
    }
    if (oldVersion < 10) {
      await _upgradeFuelImportShippingCost(db);
    }
    if (oldVersion < 11) {
      await _upgradePromotionFreeProduct(db);
    }
    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN image_path TEXT');
      } catch (_) {}
    }
    if (oldVersion < 13) {
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN current_qty INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN reward_product_id INTEGER');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN reward_qty INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_stock_movements(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          qty_delta INTEGER NOT NULL,
          qty_after INTEGER NOT NULL,
          movement_type TEXT NOT NULL,
          reference_type TEXT,
          reference_id INTEGER,
          user_id INTEGER,
          note TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future<void> _upgradePromotionFreeProduct(Database db) async {
    try {
      await db.execute(
          'ALTER TABLE promotions ADD COLUMN reward_product_id INTEGER');
    } catch (_) {}
    try {
      await db.execute(
          'ALTER TABLE promotions ADD COLUMN reward_qty INTEGER NOT NULL DEFAULT 1');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE promotions_new(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        type TEXT NOT NULL CHECK(type IN ('percent','fixed','per_liter','free_product')),
        value REAL NOT NULL,
        min_amount REAL NOT NULL DEFAULT 0,
        fuel_type_id INTEGER,
        starts_at TEXT,
        ends_at TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        reward_product_id INTEGER,
        reward_qty INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY(fuel_type_id) REFERENCES fuel_types(id) ON DELETE SET NULL,
        FOREIGN KEY(reward_product_id) REFERENCES products(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      INSERT INTO promotions_new(
        id, name, description, type, value, min_amount, fuel_type_id,
        starts_at, ends_at, is_active, created_at, reward_product_id, reward_qty
      )
      SELECT
        id, name, description, type, value, min_amount, fuel_type_id,
        starts_at, ends_at, is_active, created_at, reward_product_id,
        COALESCE(reward_qty, 1)
      FROM promotions
    ''');
    await db.execute('DROP TABLE promotions');
    await db.execute('ALTER TABLE promotions_new RENAME TO promotions');
  }

  Future<void> _upgradeFuelImportShippingCost(Database db) async {
    try {
      await db.execute(
          'ALTER TABLE fuel_deliveries ADD COLUMN shipping_cost REAL');
    } catch (_) {}
  }

  Future<void> _upgradeFuelImportBatchFields(Database db) async {
    for (final col in [
      'batch_key TEXT',
      "status TEXT NOT NULL DEFAULT 'received'",
      'received_liters REAL',
    ]) {
      try {
        await db.execute('ALTER TABLE fuel_deliveries ADD COLUMN $col');
      } catch (_) {}
    }
    await db.execute('''
      UPDATE fuel_deliveries
      SET batch_key = supplier_id || '_' || created_at,
          status = 'received',
          received_liters = liters
      WHERE batch_key IS NULL OR batch_key = ''
    ''');
  }

  Future<void> _upgradeSupplierDocumentFields(Database db) async {
    for (final col in [
      'company TEXT',
      "branch_no TEXT DEFAULT '00000'",
      'postal_code TEXT',
      'email TEXT',
      'contact_name TEXT',
      'note TEXT',
      "supplier_type TEXT NOT NULL DEFAULT 'company'",
    ]) {
      try {
        await db.execute('ALTER TABLE suppliers ADD COLUMN $col');
      } catch (_) {}
    }
    try {
      await db.execute(
          'ALTER TABLE fuel_deliveries ADD COLUMN supplier_snapshot TEXT');
    } catch (_) {}
  }

  /// สำรองไฟล์ .db ก่อน migrate — เก็บค่าเดิมเมื่อ schema เปลี่ยน
  Future<void> _snapshotBeforeUpgrade(String dbPath) async {
    try {
      final file = File(dbPath);
      if (!await file.exists()) return;

      final probe = await openDatabase(dbPath, readOnly: true);
      final rows = await probe.rawQuery('PRAGMA user_version');
      await probe.close();
      final currentVer = rows.isNotEmpty
          ? (rows.first['user_version'] as int? ?? 0)
          : 0;
      if (currentVer >= _dbVersion) return;

      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(dir.path, 'backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final name =
          'pre_upgrade_v${currentVer}_to_v${_dbVersion}_$stamp.db';
      await file.copy(p.join(backupDir.path, name));
    } catch (_) {
      // ไม่บล็อกการเปิดแอปถ้าสำรองไม่สำเร็จ
    }
  }

  Future<void> _createSupplierTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        company TEXT,
        phone TEXT,
        tax_id TEXT,
        branch_no TEXT DEFAULT '00000',
        address TEXT,
        postal_code TEXT,
        email TEXT,
        contact_name TEXT,
        note TEXT,
        supplier_type TEXT NOT NULL DEFAULT 'company',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fuel_deliveries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        tank_id INTEGER NOT NULL,
        liters REAL NOT NULL,
        unit_cost REAL,
        shipping_cost REAL,
        note TEXT,
        supplier_snapshot TEXT,
        batch_key TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        received_liters REAL,
        user_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY(supplier_id) REFERENCES suppliers(id),
        FOREIGN KEY(tank_id) REFERENCES tanks(id),
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_fuel_deliveries_created ON fuel_deliveries(created_at)');
  }

  /// สีมาตรฐานปั๊มไทย — 91 เขียว, 95 ส้ม, ดีเซล น้ำเงินเข้ม
  Future<void> _syncFuelBrandColors(Database db) async {
    const palette = {
      'DSL': '#1E3D59',
      'G91': '#2B7A3E',
      'G95': '#F37021',
    };
    for (final e in palette.entries) {
      await db.update(
        'fuel_types',
        {'color_hex': e.value},
        where: 'code = ?',
        whereArgs: [e.key],
      );
    }
    await db.execute("""
      UPDATE fuel_types SET color_hex = '#F37021'
      WHERE (name LIKE '%95%' OR name LIKE '%E85%')
        AND (color_hex IS NULL OR color_hex IN ('#D4AF37', '#F5D76E', '#FFC107', '#FFD54F'))
    """);
    await db.execute("""
      UPDATE fuel_types SET color_hex = '#2B7A3E'
      WHERE (name LIKE '%91%' OR name LIKE '%E10%')
        AND (color_hex IS NULL OR color_hex IN ('#D4AF37', '#F5D76E', '#FFC107'))
    """);
    await db.execute("""
      UPDATE fuel_types SET color_hex = '#1E3D59'
      WHERE (name LIKE '%ดีเซล%' OR name LIKE '%B7%' OR name LIKE '%diesel%')
        AND color_hex IS NULL
    """);
  }

  Future<void> _seedSampleProducts(Database db) async {
    final products = await db.query('products', limit: 1);
    if (products.isEmpty) {
      final now = DateTime.now().toIso8601String();
      for (final p in [
        {'name': 'น้ำดื่ม', 'price': 15.0, 'sku': 'W001'},
        {'name': 'ผ้าเช็ด', 'price': 25.0, 'sku': 'C001'},
        {'name': 'ยางปะ', 'price': 50.0, 'sku': 'T001'},
      ]) {
        await db.insert('products', {
          ...p,
          'is_active': 1,
          'created_at': now,
        });
      }
    }
  }

  Future<void> _seedV2(Database db) async {
    await _seedSampleProducts(db);

    final cols = await db.rawQuery('PRAGMA table_info(customers)');
    final names = cols.map((c) => c['name'] as String).toSet();
    if (!names.contains('tax_id')) return;

    final customers = await db.query('customers', limit: 1);
    if (customers.isEmpty) {
      final now = DateTime.now().toIso8601String();
      await db.insert('customers', {
        'name': 'ลูกค้าฟลีท ตัวอย่าง',
        'phone': '0812345678',
        'fleet_card_no': 'FLT-001',
        'company': 'บริษัท ทีพี ขนส่ง จำกัด',
        'tax_id': '0105551234567',
        'branch_no': '00000',
        'address': '123 ถ.พระราม 4 แขวงคลองเตย เขตคลองเตย กรุงเทพฯ',
        'postal_code': '10110',
        'email': 'billing@example.com',
        'contact_name': 'คุณสมชาย',
        'customer_type': 'company',
        'vehicle_plate': 'กข 1234',
        'is_active': 1,
        'created_at': now,
      });
    }
  }

  static String hash(String raw) =>
      sha256.convert(utf8.encode('fpos::$raw')).toString();

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Users
    batch.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL CHECK(role IN ('admin','cashier')),
        display_name TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Fuel Types
    batch.execute('''
      CREATE TABLE fuel_types(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        price_per_liter REAL NOT NULL,
        color_hex TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 3. Tanks (Inventory)
    batch.execute('''
      CREATE TABLE tanks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        fuel_type_id INTEGER NOT NULL,
        capacity REAL NOT NULL,
        current_liters REAL NOT NULL,
        FOREIGN KEY(fuel_type_id) REFERENCES fuel_types(id)
      )
    ''');

    // 4. Dispensers (Physical Pumps)
    batch.execute('''
      CREATE TABLE dispensers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 5. Nozzles (Pumps link to Tanks)
    batch.execute('''
      CREATE TABLE nozzles(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dispenser_id INTEGER NOT NULL,
        tank_id INTEGER NOT NULL,
        nozzle_number INTEGER NOT NULL,
        FOREIGN KEY(dispenser_id) REFERENCES dispensers(id),
        FOREIGN KEY(tank_id) REFERENCES tanks(id)
      )
    ''');

    // 6. Promotions
    batch.execute('''
      CREATE TABLE promotions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        type TEXT NOT NULL CHECK(type IN ('percent','fixed','per_liter','free_product')),
        value REAL NOT NULL,
        min_amount REAL NOT NULL DEFAULT 0,
        fuel_type_id INTEGER,
        starts_at TEXT,
        ends_at TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        reward_product_id INTEGER,
        reward_qty INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY(fuel_type_id) REFERENCES fuel_types(id) ON DELETE SET NULL,
        FOREIGN KEY(reward_product_id) REFERENCES products(id) ON DELETE SET NULL
      )
    ''');

    // 7. Discounts
    batch.execute('''
      CREATE TABLE discounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('percent','fixed')),
        value REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 8. Transactions
    batch.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_no TEXT UNIQUE NOT NULL,
        cashier_id INTEGER NOT NULL,
        shift_id INTEGER,
        fuel_type_id INTEGER NOT NULL,
        dispenser_id INTEGER,
        nozzle_id INTEGER,
        payment_method TEXT NOT NULL,
        liters REAL NOT NULL,
        price_per_liter REAL NOT NULL,
        subtotal REAL NOT NULL,
        promotion_id INTEGER,
        promotion_amount REAL NOT NULL DEFAULT 0,
        discount_id INTEGER,
        discount_amount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        received REAL NOT NULL DEFAULT 0,
        change_amount REAL NOT NULL DEFAULT 0,
        printed INTEGER NOT NULL DEFAULT 0,
        product_id INTEGER,
        customer_id INTEGER,
        sale_type TEXT NOT NULL DEFAULT 'fuel',
        notes TEXT,
        reward_product_id INTEGER,
        reward_qty INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY(cashier_id) REFERENCES users(id),
        FOREIGN KEY(customer_id) REFERENCES customers(id),
        FOREIGN KEY(fuel_type_id) REFERENCES fuel_types(id),
        FOREIGN KEY(dispenser_id) REFERENCES dispensers(id),
        FOREIGN KEY(nozzle_id) REFERENCES nozzles(id),
        FOREIGN KEY(promotion_id) REFERENCES promotions(id),
        FOREIGN KEY(discount_id) REFERENCES discounts(id)
      )
    ''');

    batch.execute('CREATE INDEX idx_tx_created ON transactions(created_at)');

    batch.execute('''
      CREATE TABLE suspended_sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cashier_id INTEGER NOT NULL,
        payload TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(cashier_id) REFERENCES users(id)
      )
    ''');

    batch.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        fleet_card_no TEXT,
        company TEXT,
        tax_id TEXT,
        branch_no TEXT DEFAULT '00000',
        address TEXT,
        postal_code TEXT,
        email TEXT,
        contact_name TEXT,
        customer_type TEXT NOT NULL DEFAULT 'company',
        vehicle_plate TEXT,
        note TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        sku TEXT,
        image_path TEXT,
        current_qty INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE product_stock_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        qty_delta INTEGER NOT NULL,
        qty_after INTEGER NOT NULL,
        movement_type TEXT NOT NULL,
        reference_type TEXT,
        reference_id INTEGER,
        user_id INTEGER,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE shifts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        opening_cash REAL NOT NULL DEFAULT 0,
        closing_cash REAL,
        status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','closed')),
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');

    // 9. Settings
    batch.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');

    // 10. Audit Log
    batch.execute('''
      CREATE TABLE audit_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        action TEXT NOT NULL,
        details TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
    await _seed(db);
    await _seedV2(db);
    await _createSupplierTables(db);
  }

  /// Ensures default admin/cashier exist when the users table is empty
  /// (fresh install, failed wizard, or restored DB without users).
  Future<void> ensureDefaultUsers() async {
    await _ensureDefaultUsersOn(await database);
  }

  Future<void> finalizeAfterImport() async {
    await ensureDefaultUsers();
    await _markInitializedIfConfigured();
  }

  Future<void> _markInitializedIfConfigured() async {
    final db = await database;
    final initRows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['is_initialized'],
      limit: 1,
    );
    if (initRows.isNotEmpty && initRows.first['value'] == 'true') return;

    final userCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users'),
        ) ??
        0;
    final tanks = await db.query('tanks', limit: 1);
    if (userCount > 0 && tanks.isNotEmpty) {
      await db.insert(
        'settings',
        {'key': 'is_initialized', 'value': 'true'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _ensureDefaultUsersOn(Database db) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users'),
        ) ??
        0;
    if (count > 0) return;

    final now = DateTime.now().toIso8601String();
    await db.insert('users', {
      'username': AppConstants.defaultAdminUsername,
      'password_hash': hash(AppConstants.defaultAdminPassword),
      'role': 'admin',
      'display_name': 'ผู้ดูแลระบบ',
      'is_active': 1,
      'created_at': now,
    });
    await db.insert('users', {
      'username': AppConstants.defaultCashierUsername,
      'password_hash': hash(AppConstants.defaultCashierPassword),
      'role': 'cashier',
      'display_name': 'แคชเชียร์',
      'is_active': 1,
      'created_at': now,
    });

    await db.insert(
      'settings',
      {'key': 'is_initialized', 'value': 'true'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _ensureDemoStationIfEmpty(db);
  }

  Future<void> _ensureDemoStationIfEmpty(Database db) async {
    final tanks = await db.query('tanks', limit: 1);
    if (tanks.isNotEmpty) return;

    final fuels = await db.query('fuel_types', orderBy: 'id ASC');
    if (fuels.isEmpty) return;

    for (var i = 0; i < fuels.length; i++) {
      final fuel = fuels[i];
      final fuelId = fuel['id'] as int;
      final name = fuel['name'] as String;
      await db.insert('tanks', {
        'name': 'ถัง $name',
        'fuel_type_id': fuelId,
        'capacity': 10000.0,
        'current_liters': 8000.0,
      });
    }

    final allTanks = await db.query('tanks', orderBy: 'id ASC');
    if (allTanks.isEmpty) return;

    final dispenserId = await db.insert('dispensers', {
      'name': 'ตู้จ่าย 1',
      'is_active': 1,
    });

    for (var i = 0; i < allTanks.length && i < 4; i++) {
      await db.insert('nozzles', {
        'dispenser_id': dispenserId,
        'tank_id': allTanks[i]['id'],
        'nozzle_number': i + 1,
      });
    }
  }

  Future<int> userCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users'),
        ) ??
        0;
  }

  Future<void> resetAdminPasswordToDefault() async {
    final db = await database;
    await db.update(
      'users',
      {
        'password_hash': hash(AppConstants.defaultAdminPassword),
        'is_active': 1,
      },
      where: 'username = ?',
      whereArgs: [AppConstants.defaultAdminUsername],
    );
  }

  Future<void> _seed(Database db) async {
    // Seed fuel types (Thai station mix)
    final fuels = [
      {'id': 1, 'code': 'DSL', 'name': 'ดีเซล B7', 'price_per_liter': 31.94, 'color_hex': '#1E3D59'},
      {'id': 2, 'code': 'G91', 'name': 'แก๊สโซฮอล์ 91', 'price_per_liter': 36.68, 'color_hex': '#2B7A3E'},
      {'id': 3, 'code': 'G95', 'name': 'แก๊สโซฮอล์ 95', 'price_per_liter': 37.95, 'color_hex': '#F37021'},
    ];
    for (final f in fuels) {
      await db.insert('fuel_types', {...f, 'is_active': 1});
    }

    // Tanks, Dispensers, and Nozzles will be created by the Setup Wizard.

    // Default settings
    final defaultSettings = {
      'station_name': 'FUEL POS STATION',
      'station_tax_id': '',
      'station_address': '',
      'receipt_footer': 'ขอบคุณที่ใช้บริการ — เดินทางปลอดภัย',
      'tts_enabled': 'true',
      'tts_language': 'th-TH',
      'backup_cloud_enabled': 'false',
      'backup_cloud_endpoint': '',
      'backup_cloud_token': '',
      'auto_local_backup_enabled': 'true',
      'last_local_backup_at': '',
      'local_backup_db_version': '0',
      'printer_mac': '',
      'printer_name': '',
      'printer_paper_size': '80',
      'is_initialized': 'false',
      'vat_enabled': 'true',
      'vat_rate': '7',
      'license_key': '',
      'license_type': 'free',
    };
    for (final e in defaultSettings.entries) {
      await db.insert('settings', {'key': e.key, 'value': e.value});
    }
    // ผู้ใช้และการตั้งค่าสถานีจริง — สร้างผ่าน Setup Wizard เท่านั้น
  }

  // ---------- Low-level helpers used by repositories ----------
  Future<int> insert(String table, Map<String, Object?> values) async =>
      _runLocked(() async => (await _openIfNeeded()).insert(table, values));

  Future<int> update(String table, Map<String, Object?> values,
          {required String where, List<Object?>? whereArgs}) async =>
      _runLocked(() async => (await _openIfNeeded())
          .update(table, values, where: where, whereArgs: whereArgs));

  Future<int> delete(String table,
          {required String where, List<Object?>? whereArgs}) async =>
      _runLocked(() async => (await _openIfNeeded())
          .delete(table, where: where, whereArgs: whereArgs));

  Future<List<Map<String, Object?>>> query(String table,
          {String? where,
          List<Object?>? whereArgs,
          String? orderBy,
          int? limit,
          String? groupBy}) async =>
      _runLocked(() async => (await _openIfNeeded()).query(table,
          where: where,
          whereArgs: whereArgs,
          orderBy: orderBy,
          limit: limit,
          groupBy: groupBy));

  Future<List<Map<String, Object?>>> raw(String sql,
          [List<Object?>? args]) async =>
      _runLocked(() async => (await _openIfNeeded()).rawQuery(sql, args));

  /// Run multiple writes atomically — rolls back on any error.
  Future<T> runInTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) =>
      _runLocked(() async {
        final db = await _openIfNeeded();
        return db.transaction(action);
      });

  /// Alias for [raw] — some repositories call this name directly.
  Future<List<Map<String, Object?>>> rawQuery(String sql,
          [List<Object?>? args]) =>
      raw(sql, args);

  Future<void> close() => _runLocked(() async {
        await _db?.close();
        _db = null;
      });

  /// Point the singleton at an isolated DB (unit/integration tests only).
  @visibleForTesting
  void configureForTesting({String? dbPath}) {
    _testDbPath = dbPath ?? inMemoryDatabasePath;
  }

  /// Close and forget test overrides.
  @visibleForTesting
  Future<void> resetForTesting() async {
    await close();
    _testDbPath = null;
    _opChain = Future.value();
  }

  /// Hot backup — keeps DB open (safe while app is running).
  Future<void> copyDatabaseFile(String destPath) async {
    if (kIsWeb) return;
    await _runLocked(() async {
      final db = await _openIfNeeded();
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      final dest = File(destPath);
      if (await dest.exists()) {
        await dest.delete();
      }
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('$destPath$suffix');
        if (await sidecar.exists()) {
          await sidecar.delete();
        }
      }
      final escaped = destPath.replaceAll("'", "''");
      await db.execute("VACUUM INTO '$escaped'");
    });
  }

  /// Replace live DB file — used for restore/import only.
  Future<void> replaceDatabaseFile(String sourcePath) async {
    if (kIsWeb) return;
    await _runLocked(() async {
      await _db?.close();
      _db = null;
      final destPath = await databasePath;
      await File(sourcePath).copy(destPath);
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('$destPath$suffix');
        if (await sidecar.exists()) {
          await sidecar.delete();
        }
      }
      await _openIfNeeded();
    });
  }

  Future<DatabaseImportReport> inspectImportFile(String path) async {
    if (kIsWeb) {
      return DatabaseImportReport(
        ok: false,
        message: 'การนำเข้าไฟล์ .db ไม่รองรับบน Web',
        expectedVersion: _dbVersion,
      );
    }

    final file = File(path);
    if (!await file.exists()) {
      return DatabaseImportReport(
        ok: false,
        message: 'ไม่พบไฟล์ที่เลือก',
        expectedVersion: _dbVersion,
      );
    }

    final size = await file.length();
    if (size < 512) {
      return DatabaseImportReport(
        ok: false,
        message: 'ไฟล์ไม่ถูกต้อง (ขนาดเล็กเกินไป)',
        expectedVersion: _dbVersion,
      );
    }

    Database? probe;
    try {
      probe = await openDatabase(path, readOnly: true);
      final versionRow = await probe.rawQuery('PRAGMA user_version');
      final fileVersion = versionRow.first['user_version'] as int? ?? 0;

      final tableRows = await probe.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      final tables =
          tableRows.map((r) => r['name'] as String).toSet();

      final missing =
          coreImportTables.where((t) => !tables.contains(t)).toList();

      String? stationName;
      var isInitialized = false;
      var userCount = 0;

      try {
        final stationRows = await probe.query(
          'settings',
          where: 'key = ?',
          whereArgs: ['station_name'],
          limit: 1,
        );
        if (stationRows.isNotEmpty) {
          stationName = stationRows.first['value'] as String?;
        }
        final initRows = await probe.query(
          'settings',
          where: 'key = ?',
          whereArgs: ['is_initialized'],
          limit: 1,
        );
        if (initRows.isNotEmpty) {
          isInitialized = initRows.first['value'] == 'true';
        }
      } catch (_) {}

      try {
        userCount = Sqflite.firstIntValue(
              await probe.rawQuery('SELECT COUNT(*) FROM users'),
            ) ??
            0;
      } catch (_) {}

      final needsMigration =
          fileVersion > 0 && fileVersion < _dbVersion;

      return DatabaseImportReport(
        ok: missing.isEmpty &&
            fileVersion >= minImportVersion &&
            fileVersion <= _dbVersion,
        message: '',
        fileVersion: fileVersion,
        expectedVersion: _dbVersion,
        missingTables: missing,
        stationName: stationName,
        userCount: userCount,
        isInitialized: isInitialized,
        needsMigration: needsMigration,
      );
    } catch (e) {
      return DatabaseImportReport(
        ok: false,
        message: 'ไม่สามารถอ่านไฟล์ SQLite ได้: $e',
        expectedVersion: _dbVersion,
      );
    } finally {
      await probe?.close();
    }
  }

  Future<DatabaseImportReport> validateImportFile(String path) async {
    final report = await inspectImportFile(path);
    if (report.fileVersion == null && report.message.isNotEmpty) {
      return report;
    }

    if (report.missingTables.isNotEmpty) {
      return DatabaseImportReport(
        ok: false,
        message:
            'ไฟล์ไม่ใช่ฐานข้อมูล FUEL POS (ขาดตาราง: ${report.missingTables.join(', ')})',
        fileVersion: report.fileVersion,
        expectedVersion: _dbVersion,
        missingTables: report.missingTables,
        stationName: report.stationName,
        userCount: report.userCount,
        isInitialized: report.isInitialized,
        needsMigration: report.needsMigration,
      );
    }

    final fileVersion = report.fileVersion ?? 0;
    if (fileVersion < minImportVersion) {
      return DatabaseImportReport(
        ok: false,
        message:
            'Schema เก่าเกินไป (v$fileVersion) — ต้องเป็น v$minImportVersion ขึ้นไป',
        fileVersion: report.fileVersion,
        expectedVersion: _dbVersion,
        missingTables: report.missingTables,
        stationName: report.stationName,
        userCount: report.userCount,
        isInitialized: report.isInitialized,
        needsMigration: report.needsMigration,
      );
    }

    if (fileVersion > _dbVersion) {
      return DatabaseImportReport(
        ok: false,
        message:
            'Schema ใหม่กว่าแอป (ไฟล์ v$fileVersion, แอป v$_dbVersion) — กรุณาอัปเดตแอป',
        fileVersion: report.fileVersion,
        expectedVersion: _dbVersion,
        missingTables: report.missingTables,
        stationName: report.stationName,
        userCount: report.userCount,
        isInitialized: report.isInitialized,
        needsMigration: report.needsMigration,
      );
    }

    final migrateNote = report.needsMigration
        ? ' (จะ migrate เป็น v$_dbVersion อัตโนมัติ)'
        : ' (schema ตรงกับแอป)';

    return DatabaseImportReport(
      ok: true,
      message: 'ไฟล์พร้อมนำเข้า$migrateNote',
      fileVersion: report.fileVersion,
      expectedVersion: _dbVersion,
      missingTables: report.missingTables,
      stationName: report.stationName,
      userCount: report.userCount,
      isInitialized: report.isInitialized,
      needsMigration: report.needsMigration,
    );
  }

  /// Validate a backup file after export — schema + readable SQLite.
  Future<({bool ok, String message})> verifyBackupFile(String path) async {
    final report = await validateImportFile(path);
    if (!report.ok) {
      return (ok: false, message: report.message);
    }

    Database? probe;
    try {
      probe = await openDatabase(path, readOnly: true);
      await probe.rawQuery('SELECT COUNT(*) FROM transactions');
      await probe.rawQuery('SELECT COUNT(*) FROM settings');
      return (
        ok: true,
        message: 'ไฟล์สำรองถูกต้อง (schema v${report.fileVersion})',
      );
    } catch (e) {
      return (ok: false, message: 'ไฟล์สำรองอ่านไม่ได้: $e');
    } finally {
      await probe?.close();
    }
  }

  Future<DatabaseImportReport> verifyCurrentSchema() async {
    final db = await database;
    final versionRow = await db.rawQuery('PRAGMA user_version');
    final currentVersion = versionRow.first['user_version'] as int? ?? 0;

    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    final tables = tableRows.map((r) => r['name'] as String).toSet();
    final missing =
        currentSchemaTables.where((t) => !tables.contains(t)).toList();

    if (currentVersion != _dbVersion) {
      return DatabaseImportReport(
        ok: false,
        message:
            'Migrate ไม่สมบูรณ์ (ได้ v$currentVersion ต้องการ v$_dbVersion)',
        fileVersion: currentVersion,
        expectedVersion: _dbVersion,
        missingTables: missing,
      );
    }

    if (missing.isNotEmpty) {
      return DatabaseImportReport(
        ok: false,
        message: 'Schema ไม่ครบหลัง migrate (ขาด: ${missing.join(', ')})',
        fileVersion: currentVersion,
        expectedVersion: _dbVersion,
        missingTables: missing,
      );
    }

    return DatabaseImportReport(
      ok: true,
      message: 'Schema v$_dbVersion ถูกต้อง',
      fileVersion: currentVersion,
      expectedVersion: _dbVersion,
    );
  }

  /// Quick health check on app startup — schema version + core tables.
  Future<({bool ok, String message})> startupHealthCheck() async {
    try {
      final report = await verifyCurrentSchema();
      if (!report.ok) {
        return (ok: false, message: report.message);
      }
      return (ok: true, message: report.message);
    } catch (e) {
      return (ok: false, message: 'ฐานข้อมูลมีปัญหา: $e');
    }
  }

  Future<DatabaseImportReport> importDatabaseFile(String sourcePath) async {
    final pre = await validateImportFile(sourcePath);
    if (!pre.ok) return pre;

    if (kIsWeb) {
      return DatabaseImportReport(
        ok: false,
        message: 'การนำเข้าไฟล์ .db ไม่รองรับบน Web',
        expectedVersion: _dbVersion,
      );
    }

    await replaceDatabaseFile(sourcePath);
    final post = await verifyCurrentSchema();
    if (!post.ok) return post;

    await finalizeAfterImport();
    return DatabaseImportReport(
      ok: true,
      message: 'นำเข้าและ migrate สำเร็จ (v$_dbVersion)',
      fileVersion: _dbVersion,
      expectedVersion: _dbVersion,
      stationName: pre.stationName,
      userCount: pre.userCount,
      isInitialized: pre.isInitialized,
    );
  }

  Future<void> audit(int? userId, String action, {String? details}) async {
    try {
      await (await database).insert('audit_log', {
        'user_id': userId,
        'action': action,
        'details': details,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
}
