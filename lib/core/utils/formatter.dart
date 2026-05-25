import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class Fmt {
  static final _money = NumberFormat('#,##0.00');
  static final _integer = NumberFormat('#,##0');
  static final _date = DateFormat('yyyy-MM-dd');
  static final _dateTime = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final _displayDate = DateFormat('dd MMM yyyy');
  static final _receiptDate = DateFormat('dd/MM/yyyy HH:mm');

  static String money(num v) =>
      '${AppConstants.currencySymbol} ${_money.format(v)}';

  static String moneyPlain(num v) => _money.format(v);

  static String integer(num v) => _integer.format(v);

  static String liters(num v) => '${_money.format(v)} L';

  static String date(DateTime d) => _date.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
  static String displayDate(DateTime d) => _displayDate.format(d);
  static String receiptDate(DateTime d) => _receiptDate.format(d);
}
