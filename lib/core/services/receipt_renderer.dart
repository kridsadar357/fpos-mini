import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../data/models/customer.dart';
import '../../data/models/promotion.dart';
import '../../data/models/receipt_template.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/settings_repository.dart';
import '../constants/app_constants.dart';
import 'receipt_template_service.dart';

/// Builds ESC/POS bytes from customizable receipt template.
class ReceiptRenderer {
  ReceiptRenderer._();

  static Future<Uint8List> build({
    required PaperSize paperSize,
    required Transaction tx,
    required String fuelName,
    required String cashierName,
    Customer? customer,
    Promotion? promotion,
    bool isDraft = false,
    ReceiptTemplate? template,
  }) async {
    final tpl = template ?? ReceiptTemplateService.instance.current;
    final repo = SettingsRepository();
    final stationName =
        await repo.get('station_name', defaultValue: AppConstants.appName);
    final address = await repo.get('station_address', defaultValue: '');
    final taxId = await repo.get('station_tax_id', defaultValue: '');
    final footerDefault = await repo.get('receipt_footer',
        defaultValue: 'ขอบคุณที่ใช้บริการ');

    final placeholders = <String, String>{
      'station_name': stationName,
      'station_address': address,
      'tax_id': taxId,
      'receipt_footer': footerDefault,
      'receipt_no': tx.receiptNo,
      'date': _fmtDate(tx.createdAt),
      'cashier': cashierName,
      'plate': customer?.vehiclePlate ?? _plateFromNotes(tx.notes) ?? '',
      'customer_name': customer?.invoiceName ?? '',
      'customer_tax_id': customer?.taxId ?? '',
      'customer_branch': customer?.branchNo ?? '',
      'customer_address': customer?.address ?? '',
      'fuel': fuelName,
      'liters': tx.liters.toStringAsFixed(2),
      'total': tx.total.toStringAsFixed(2),
    };

    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];
    bytes += generator.reset();

    for (final block in tpl.blockOrder) {
      switch (block) {
        case ReceiptBlockType.logo:
          if (tpl.logoEnabled) {
            bytes += await _appendLogo(generator, paperSize);
          }
          break;
        case ReceiptBlockType.header:
          bytes += _appendLines(generator, tpl.headerLines, placeholders,
              boldFirst: true);
          bytes += generator.hr();
          break;
        case ReceiptBlockType.body:
          bytes += _appendBody(
            generator: generator,
            tx: tx,
            fuelName: fuelName,
            cashierName: cashierName,
            customer: customer,
            promotion: promotion,
            isDraft: isDraft,
            placeholders: placeholders,
            taxNotes: customer?.formatTaxNotes() ?? tx.notes,
          );
          break;
        case ReceiptBlockType.footer:
          bytes += generator.hr();
          bytes += _appendLines(generator, tpl.footerLines, placeholders);
          bytes += generator.feed(2);
          break;
      }
    }

    bytes += generator.cut();
    return Uint8List.fromList(bytes);
  }

  static Future<List<int>> _appendLogo(
      Generator generator, PaperSize paperSize) async {
    try {
      final data = await rootBundle.load('assets/images/app_logo.png');
      final decoded = img.decodeImage(data.buffer.asUint8List());
      if (decoded != null) {
        final targetWidth = paperSize == PaperSize.mm58 ? 280 : 420;
        final resized = img.copyResize(decoded, width: targetWidth);
        return generator.image(resized, align: PosAlign.center);
      }
    } catch (_) {}
    return generator.text('FUEL POS',
        styles: const PosStyles(
          bold: true,
          align: PosAlign.center,
          height: PosTextSize.size2,
        ));
  }

  static List<int> _appendLines(
    Generator generator,
    List<String> lines,
    Map<String, String> placeholders, {
    bool boldFirst = false,
  }) {
    List<int> bytes = [];
    for (var i = 0; i < lines.length; i++) {
      final line = ReceiptPlaceholders.apply(lines[i].trim(), placeholders);
      if (line.isEmpty) continue;
      bytes += generator.text(
        line,
        styles: PosStyles(
          bold: boldFirst && i == 0,
          align: PosAlign.center,
          height: boldFirst && i == 0 ? PosTextSize.size2 : PosTextSize.size1,
          width: boldFirst && i == 0 ? PosTextSize.size2 : PosTextSize.size1,
        ),
      );
    }
    return bytes;
  }

  static List<int> _appendBody({
    required Generator generator,
    required Transaction tx,
    required String fuelName,
    required String cashierName,
    required Customer? customer,
    Promotion? promotion,
    required bool isDraft,
    required Map<String, String> placeholders,
    required String? taxNotes,
  }) {
    List<int> bytes = [];

    bytes += generator.row([
      PosColumn(text: 'Receipt:', width: 5),
      PosColumn(
          text: placeholders['receipt_no']!,
          width: 7,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Date:', width: 5),
      PosColumn(
          text: placeholders['date']!,
          width: 7,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Cashier:', width: 5),
      PosColumn(
          text: cashierName,
          width: 7,
          styles: const PosStyles(align: PosAlign.right)),
    ]);

    final plate = customer?.vehiclePlate ?? _plateFromNotes(tx.notes);
    if (plate != null && plate.isNotEmpty) {
      bytes += generator.row([
        PosColumn(text: 'Plate:', width: 5),
        PosColumn(
            text: plate,
            width: 7,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += _appendTaxInvoiceBlock(generator, customer, taxNotes);

    if (isDraft) {
      bytes += generator.text('*** ใบแจ้งหนี้ (ยังไม่ชำระ) ***',
          styles: const PosStyles(
              bold: true, align: PosAlign.center, height: PosTextSize.size1));
    }

    bytes += generator.hr(ch: '-');
    bytes += generator.text('FUEL',
        styles: const PosStyles(bold: true, align: PosAlign.left));
    bytes += generator.row([
      PosColumn(text: fuelName, width: 8),
      PosColumn(
          text: '${tx.liters.toStringAsFixed(2)} L',
          width: 4,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(
          text:
              '  ${tx.pricePerLiter.toStringAsFixed(2)} x ${tx.liters.toStringAsFixed(2)}',
          width: 8),
      PosColumn(
          text: tx.subtotal.toStringAsFixed(2),
          width: 4,
          styles: const PosStyles(align: PosAlign.right)),
    ]);

    if (promotion != null) {
      bytes += generator.row([
        PosColumn(
            text: 'Promo: ${promotion.name}',
            width: 8,
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            text: promotion.isFreeProduct
                ? (tx.rewardQty > 0
                    ? (tx.rewardQty > 1
                        ? 'แถม x${tx.rewardQty}'
                        : 'แถม')
                    : promotion.freeProductLabel(subtotal: tx.subtotal))
                : '-${tx.promotionAmount.toStringAsFixed(2)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    } else if (tx.promotionAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Promotion', width: 8),
        PosColumn(
            text: '-${tx.promotionAmount.toStringAsFixed(2)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    if (tx.discountAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Discount', width: 8),
        PosColumn(
            text: '-${tx.discountAmount.toStringAsFixed(2)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr(ch: '-');
    bytes += generator.row([
      PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
          text: tx.total.toStringAsFixed(2),
          width: 6,
          styles: const PosStyles(
              bold: true, align: PosAlign.right, height: PosTextSize.size2)),
    ]);

    bytes += generator.row([
      PosColumn(text: 'Payment:', width: 6),
      PosColumn(
          text: tx.paymentMethod,
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]);

    if (tx.received > 0) {
      bytes += generator.row([
        PosColumn(text: 'Received:', width: 6),
        PosColumn(
            text: tx.received.toStringAsFixed(2),
            width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Change:', width: 6),
        PosColumn(
            text: tx.changeAmount.toStringAsFixed(2),
            width: 6,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
    }

    return bytes;
  }

  static List<int> _appendTaxInvoiceBlock(
    Generator generator,
    Customer? customer,
    String? taxNotes,
  ) {
    List<int> bytes = [];
    if (customer != null && customer.hasTaxInvoiceData) {
      bytes += generator.text('--- ข้อมูลใบกำกับภาษี ---',
          styles: const PosStyles(bold: true, align: PosAlign.center));
      bytes += generator.text(customer.invoiceName);
      if (customer.taxId != null) {
        bytes += generator.text('Tax ID: ${customer.taxId}');
        bytes += generator.text('Branch: ${customer.branchNo ?? '00000'}');
      }
      if (customer.address != null && customer.address!.isNotEmpty) {
        bytes += generator.text(customer.address!);
      }
      if (customer.phone != null) {
        bytes += generator.text('Tel: ${customer.phone}');
      }
      bytes += generator.hr(ch: '.');
      return bytes;
    }
    final notes = taxNotes?.trim();
    if (notes != null &&
        notes.isNotEmpty &&
        notes.contains('เลขผู้เสียภาษี')) {
      bytes += generator.text('--- ข้อมูลใบกำกับภาษี ---',
          styles: const PosStyles(bold: true, align: PosAlign.center));
      for (final line in notes.split('\n')) {
        if (line.trim().isEmpty) continue;
        bytes += generator.text(line.trim());
      }
      bytes += generator.hr(ch: '.');
    }
    return bytes;
  }

  static String? _plateFromNotes(String? notes) {
    if (notes == null) return null;
    for (final line in notes.split('\n')) {
      if (line.startsWith('ทะเบียนรถ:')) {
        return line.replaceFirst('ทะเบียนรถ:', '').trim();
      }
    }
    if (!notes.contains('เลขผู้เสียภาษี') && !notes.startsWith('ลูกค้า:')) {
      return notes.trim();
    }
    return null;
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
