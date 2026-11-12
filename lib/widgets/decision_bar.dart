import 'package:flutter/material.dart';

import '../core/app_palette.dart';

class DecisionBar extends StatelessWidget {
  const DecisionBar({
    super.key,
    required this.onReject,
    required this.onApprove,
    this.busy = false,
  });

  final VoidCallback onReject;
  final VoidCallback onApprove;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        border: Border(top: BorderSide(color: AppPalette.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onReject,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Tolak'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.red,
                  backgroundColor: AppPalette.surface,
                  side: BorderSide(
                    color: AppPalette.red.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onApprove,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 19),
                label: Text(busy ? 'Memproses...' : 'Setujui'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
