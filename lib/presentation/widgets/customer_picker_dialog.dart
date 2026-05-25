import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import '../providers/app_state.dart';
import 'customer_form_dialog.dart';
import 'high_end_dialog.dart';
import 'primary_button.dart';

/// เลือกลูกค้าสำหรับรายการขาย / ใบกำกับภาษี
class CustomerPickerDialog {
  static Future<void> show(BuildContext context) async {
    final r = Responsive.of(context);
    final repo = CustomerRepository();
    final searchCtrl = TextEditingController();
    var customers = <Customer>[];
    var loading = true;

    await HighEndDialog.show<void>(
      context: context,
      title: 'เลือกลูกค้า',
      compact: true,
      maxWidth: r.w(480),
      content: StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> runSearch() async {
            setLocal(() => loading = true);
            customers = await repo.search(searchCtrl.text);
            if (ctx.mounted) setLocal(() => loading = false);
          }

          if (loading && customers.isEmpty) {
            Future.microtask(runSearch);
          }

          final listMaxH = (MediaQuery.sizeOf(ctx).height * 0.32).clamp(140.0, 280.0);

          return SizedBox(
            width: r.w(400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText:
                        'ค้นหา ชื่อ / เลขภาษี / โทร / ทะเบียน / บัตรฟลีท',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.corporateBlue),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        searchCtrl.clear();
                        runSearch();
                      },
                    ),
                  ),
                  onSubmitted: (_) => runSearch(),
                ),
                SizedBox(height: r.h(6)),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: runSearch,
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('ค้นหา'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        context.read<AppState>().setCustomer(null);
                        Navigator.pop(ctx);
                      },
                      child: const Text('ล้างการเลือก'),
                    ),
                  ],
                ),
                const Divider(height: 1),
                SizedBox(
                  height: listMaxH,
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : customers.isEmpty
                          ? Center(
                              child: Text(
                                'ไม่พบลูกค้า',
                                style: TextStyle(
                                  color: AppColors.greyMedium,
                                  fontSize: r.sp(13),
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: customers.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final c = customers[i];
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: r.sp(16),
                                    backgroundColor:
                                        AppColors.corporateBlue.withValues(
                                            alpha: 0.12),
                                    child: Icon(
                                      c.isCompany
                                          ? Icons.business_rounded
                                          : Icons.person_rounded,
                                      color: AppColors.corporateBlue,
                                      size: r.sp(18),
                                    ),
                                  ),
                                  title: Text(
                                    c.displayLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      c.typeLabel,
                                      if (c.phone != null) c.phone!,
                                      if (c.vehiclePlate != null)
                                        'ทะเบียน ${c.vehiclePlate}',
                                    ].join(' • '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: r.sp(11)),
                                  ),
                                  onTap: () {
                                    context.read<AppState>().setCustomer(c);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        PrimaryButton(
          label: 'ปิด',
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.pop(context),
        ),
        PrimaryButton(
          label: 'เพิ่มลูกค้า',
          icon: Icons.person_add_rounded,
          onPressed: () async {
            final created = await CustomerFormDialog.show(context);
            if (created != null && context.mounted) {
              context.read<AppState>().setCustomer(created);
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}
