import 'package:flutter/material.dart';

import '../theme/easel_theme.dart';

/// Centered modal matching web `.overlay` + `.modal`.
class EaselModal extends StatelessWidget {
  const EaselModal({
    super.key,
    required this.child,
    this.width = 560,
    this.onBarrierTap,
  });

  final Widget child;
  final double width;
  final VoidCallback? onBarrierTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: GestureDetector(
        onTap: onBarrierTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // absorb
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width,
                maxHeight: MediaQuery.sizeOf(context).height * 0.9,
              ),
              child: Material(
                color: EaselColors.surface,
                borderRadius: BorderRadius.circular(EaselColors.radiusXl),
                clipBehavior: Clip.antiAlias,
                elevation: 12,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EaselChip extends StatelessWidget {
  const EaselChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? EaselColors.borderStrong : EaselColors.border,
            ),
            color: selected ? EaselColors.accentSoft : EaselColors.surface,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? EaselColors.accentEnd : EaselColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
