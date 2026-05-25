import '../../data/models/receipt_template.dart';
import '../../data/repositories/settings_repository.dart';

class ReceiptTemplateService {
  ReceiptTemplateService._();
  static final ReceiptTemplateService instance = ReceiptTemplateService._();

  static const _key = 'receipt_template';

  final _repo = SettingsRepository();
  ReceiptTemplate _cached = const ReceiptTemplate();

  ReceiptTemplate get current => _cached;

  Future<ReceiptTemplate> load() async {
    final raw = await _repo.get(_key, defaultValue: '');
    if (raw.isEmpty) {
      _cached = const ReceiptTemplate();
    } else {
      _cached = ReceiptTemplate.fromJsonString(raw);
    }
    return _cached;
  }

  Future<void> save(ReceiptTemplate template) async {
    _cached = template;
    await _repo.set(_key, template.toJsonString());
  }
}
