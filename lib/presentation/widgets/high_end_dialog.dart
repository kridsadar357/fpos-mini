import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import 'glass_card.dart';
import 'primary_button.dart';

class HighEndDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;
  final List<Widget>? actions;
  final IconData? icon;
  final Color iconColor;
  final double? maxWidth;
  final bool compact;

  const HighEndDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.actions,
    this.icon,
    this.iconColor = AppColors.corporateBlue,
    this.maxWidth,
    this.compact = false,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? message,
    Widget? content,
    List<Widget>? actions,
    List<Widget> Function(BuildContext dialogContext)? actionBuilders,
    IconData? icon,
    Color iconColor = AppColors.corporateBlue,
    double? maxWidth,
    bool compact = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      useRootNavigator: true,
      builder: (dialogContext) {
        return PopScope(
          canPop: barrierDismissible,
          child: HighEndDialog(
            title: title,
            message: message,
            content: content,
            actions: actionBuilders?.call(dialogContext) ?? actions,
            icon: icon,
            iconColor: iconColor,
            maxWidth: maxWidth,
            compact: compact,
          ),
        );
      },
    );
  }

  static void close<T>(BuildContext context, [T? result]) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context, rootNavigator: true).pop(result);
  }

  static Widget actionsGrid(
    BuildContext context,
    List<Widget> actions, {
    bool compact = false,
  }) {
    final r = Responsive.of(context);
    if (actions.isEmpty) return const SizedBox.shrink();

    if (actions.length == 1) {
      return Row(
        children: [Expanded(child: actions.first)],
      );
    }

    final gap = r.w(compact ? 6 : 8);
    final rowGap = r.h(compact ? 6 : 8);
    final rows = <Widget>[];

    for (var i = 0; i < actions.length; i += 2) {
      final left = actions[i];
      final right = i + 1 < actions.length ? actions[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: rows.isEmpty ? 0 : rowGap),
          child: right == null
              ? Row(children: [Expanded(child: left)])
              : Row(
                  children: [
                    Expanded(child: left),
                    SizedBox(width: gap),
                    Expanded(child: right),
                  ],
                ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final screenH = media.size.height;
    final dialogMaxW = maxWidth ?? r.w(400);
    final cappedMaxW = dialogMaxW.clamp(280.0, screenW - r.w(48));
    final cardPad = compact ? r.w(10) : r.w(20);
    final outerPad = compact ? r.w(8) : r.w(20);
    final maxDialogH = (screenH - media.padding.vertical - outerPad * 2)
        .clamp(280.0, screenH * 0.92);

    Widget header;
    if (compact) {
      header = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              padding: EdgeInsets.all(r.w(6)),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: r.sp(16)),
            ),
            SizedBox(width: r.w(8)),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.corporateBlueDark,
                fontSize: r.sp(13),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      );
    } else {
      header = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon != null) ...[
            Center(
              child: Container(
                padding: EdgeInsets.all(r.w(14)),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: r.sp(40)),
              ),
            ),
            SizedBox(height: r.h(16)),
          ],
          Text(
            title,
            style: TextStyle(
              color: AppColors.corporateBlueDark,
              fontSize: r.sp(20),
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    Widget actionsSection;
    if (actions != null) {
      actionsSection = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: compact ? r.h(8) : r.h(16)),
          actionsGrid(context, actions!, compact: compact),
        ],
      );
    } else {
      actionsSection = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: compact ? r.h(8) : r.h(16)),
          actionsGrid(
            context,
            [
              PrimaryButton(
                label: 'ตกลง',
                onPressed: () => Navigator.pop(context),
              ),
            ],
            compact: compact,
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.all(outerPad),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: GlassCard(
            padding: EdgeInsets.all(cardPad),
            borderRadius: compact ? 12 : 24,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: cappedMaxW,
                maxHeight: maxDialogH,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          header,
                          if (message != null) ...[
                            SizedBox(height: r.h(compact ? 4 : 6)),
                            Text(
                              message!,
                              maxLines: compact ? 3 : null,
                              overflow: compact
                                  ? TextOverflow.ellipsis
                                  : TextOverflow.visible,
                              softWrap: true,
                              style: TextStyle(
                                color: AppColors.greyMedium,
                                fontSize: r.sp(compact ? 10 : 13),
                                height: 1.25,
                              ),
                              textAlign: compact
                                  ? TextAlign.left
                                  : TextAlign.center,
                            ),
                          ],
                          if (content != null) ...[
                            SizedBox(height: compact ? r.h(6) : r.h(16)),
                            content!,
                          ],
                        ],
                      ),
                    ),
                  ),
                  actionsSection,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
