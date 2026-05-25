import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../widgets/app_logo.dart';

class SidebarNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onSelect;
  final VoidCallback onLogout;
  final VoidCallback? onSuspendedList;
  final bool productsEnabled;

  const SidebarNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
    this.onSuspendedList,
    this.productsEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Container(
      width: r.w(90),
      color: AppColors.corporateBlue,
      child: Column(
        children: [
          SizedBox(height: r.h(20)),
          AppLogo(size: r.w(52)),
          SizedBox(height: r.h(30)),

          _NavItem(
              icon: Icons.local_gas_station_rounded,
              label: 'ขายน้ำมัน',
              isSelected: selectedIndex == 0,
              onTap: () => onSelect(0)),
          if (productsEnabled)
            _NavItem(
                icon: Icons.shopping_cart_rounded,
                label: 'ขายสินค้า',
                isSelected: selectedIndex == 1,
                onTap: () => onSelect(1)),
          _NavItem(
              icon: Icons.receipt_long_rounded,
              label: 'สรุปยอด',
              isSelected: selectedIndex == 2,
              onTap: () => onSelect(2)),
          _NavItem(
              icon: Icons.group_rounded,
              label: 'ลูกค้า',
              isSelected: selectedIndex == 3,
              onTap: () => onSelect(3)),

          const Spacer(),

          if (onSuspendedList != null)
            _NavItem(
                icon: Icons.pause_circle_outline_rounded,
                label: 'พักไว้',
                isSelected: false,
                onTap: onSuspendedList!),

          _NavItem(
              icon: Icons.settings_rounded,
              label: 'ตั้งค่า',
              isSelected: selectedIndex == 4,
              onTap: () => onSelect(4)),
          _NavItem(
              icon: Icons.logout_rounded,
              label: 'ออกจากระบบ',
              isSelected: false,
              onTap: onLogout),
          SizedBox(height: r.h(20)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem(
      {required this.icon,
      required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          border: isSelected
              ? const Border(left: BorderSide(color: AppColors.fuel95, width: 4))
              : null,
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? AppColors.fuel95 : AppColors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.white : AppColors.white.withValues(alpha: 0.7),
                fontSize: r.sp(11),
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
