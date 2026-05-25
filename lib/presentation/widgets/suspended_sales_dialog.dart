import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/repositories/dispenser_repository.dart';
import '../../data/repositories/suspended_sale_repository.dart';
import '../providers/app_state.dart';
import 'high_end_dialog.dart';

class SuspendedSalesDialog {
  static Future<bool> show(BuildContext context) async {
    final repo = SuspendedSaleRepository();
    final items = await repo.listActive();
    if (!context.mounted) return false;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีรายการที่พักไว้')),
      );
      return false;
    }

    final selected = await HighEndDialog.show<SuspendedSale>(
      context: context,
      title: 'รายการที่พักไว้',
      icon: Icons.pause_circle_rounded,
      content: SizedBox(
        width: Responsive.of(context).w(400),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final s = items[i];
            return ListTile(
              title: Text(s.label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                s.note ?? 'พักเมื่อ ${s.createdAt.toLocal()}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: () async {
                  await repo.delete(s.id);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  if (!context.mounted) return;
                  await show(context);
                },
              ),
              onTap: () => Navigator.pop(context, s),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
      ],
    );

    if (selected == null || !context.mounted) return false;

    final state = context.read<AppState>();
    final dispenserId = selected.payload['dispenser_id'] as int?;
    if (dispenserId != null) {
      final dispensers = await DispenserRepository().listActive();
      final d = dispensers.where((x) => x.id == dispenserId).firstOrNull;
      if (d != null) state.selectDispenser(d);
    }
    state.restoreFromPayload(selected.payload);

    await repo.delete(selected.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โหลดรายการที่พักไว้แล้ว')),
      );
    }
    return true;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
