import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/toast_utils.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import '../providers/app_state.dart';
import '../widgets/customer_form_dialog.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';

class DashboardCustomersScreen extends StatefulWidget {
  const DashboardCustomersScreen({super.key});

  @override
  State<DashboardCustomersScreen> createState() =>
      _DashboardCustomersScreenState();
}

class _DashboardCustomersScreenState extends State<DashboardCustomersScreen> {
  final _repo = CustomerRepository();
  List<Customer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.listActive();
    setState(() {
      _customers = list;
      _loading = false;
    });
  }

  Future<void> _addOrEdit([Customer? existing]) async {
    final saved = await CustomerFormDialog.show(context, existing: existing);
    if (saved != null) {
      await _load();
      if (mounted) {
        ToastUtils.show(
          context,
          existing == null ? 'เพิ่มลูกค้าแล้ว' : 'บันทึกข้อมูลแล้ว',
        );
      }
    }
  }

  void _useCustomer(Customer customer) {
    context.read<AppState>().setCustomer(customer);
    ToastUtils.show(context, 'เลือกลูกค้า: ${customer.displayLabel}');
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Padding(
      padding: EdgeInsets.all(r.w(16)),
      child: GlassCard(
        padding: EdgeInsets.all(r.w(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'ลูกค้า / ใบกำกับภาษี',
                  style: TextStyle(
                    fontSize: r.sp(18),
                    fontWeight: FontWeight.w900,
                    color: AppColors.corporateBlueDark,
                  ),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'เพิ่มลูกค้า',
                  expand: false,
                  onPressed: () => _addOrEdit(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: _customers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = _customers[i];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              c.isCompany
                                  ? Icons.business_rounded
                                  : Icons.person_rounded,
                            ),
                          ),
                          title: Text(
                            c.displayLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            [
                              c.typeLabel,
                              if (c.address != null && c.address!.isNotEmpty)
                                c.address!,
                              if (c.phone != null) 'โทร ${c.phone}',
                              if (c.vehiclePlate != null)
                                'ทะเบียน ${c.vehiclePlate}',
                            ].join('\n'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _addOrEdit(c),
                                child: const Text('แก้ไข'),
                              ),
                              TextButton(
                                onPressed: () => _useCustomer(c),
                                child: const Text('ใช้งาน'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
