import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/fuel_type.dart';
import '../../../data/repositories/fuel_repository.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/high_end_dialog.dart';
import '../../widgets/pos_header.dart';
import '../../widgets/primary_button.dart';

class FuelPriceSettingsScreen extends StatefulWidget {
  const FuelPriceSettingsScreen({super.key});

  @override
  State<FuelPriceSettingsScreen> createState() =>
      _FuelPriceSettingsScreenState();
}

class _FuelPriceSettingsScreenState extends State<FuelPriceSettingsScreen> {
  final _repo = FuelRepository();
  List<FuelType> _fuels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fuels = await _repo.listAll();
    setState(() {
      _fuels = fuels;
      _loading = false;
    });
  }

  Future<void> _editPrice(FuelType f) async {
    final controller =
        TextEditingController(text: f.pricePerLiter.toStringAsFixed(2));
    final res = await HighEndDialog.show<double>(
      context: context,
      title: 'แก้ราคา — ${f.name}',
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'ราคาต่อลิตร (บาท)'),
      ),
      actions: [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.pop(context),
        ),
        PrimaryButton(
          label: 'บันทึก',
          onPressed: () => Navigator.pop(
            context,
            double.tryParse(controller.text),
          ),
        ),
      ],
    );
    if (res != null && res > 0) {
      await _repo.updatePrice(f.id, res);
      await _load();
    }
  }

  Future<void> _toggle(FuelType f, bool active) async {
    await _repo.setActive(f.id, active);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        title: 'ราคาน้ำมัน',
        subtitle: 'อัปเดตราคาต่อลิตร',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: EdgeInsets.all(r.w(16)),
              itemCount: _fuels.length,
              separatorBuilder: (_, __) => SizedBox(height: r.h(8)),
              itemBuilder: (_, i) {
                final f = _fuels[i];
                return GlassCard(
                  padding: EdgeInsets.all(r.w(12)),
                  child: ListTile(
                    leading: Container(
                      width: r.w(48),
                      height: r.w(48),
                      decoration: BoxDecoration(
                        color: f.color,
                        borderRadius: BorderRadius.circular(r.r(10)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        f.code,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      f.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: f.isActive
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Text(
                      Fmt.money(f.pricePerLiter),
                      style: const TextStyle(
                        color: AppColors.corporateBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: f.isActive,
                          onChanged: (v) => _toggle(f, v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded),
                          onPressed: () => _editPrice(f),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
