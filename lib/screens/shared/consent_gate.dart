import 'package:flutter/material.dart';

import '../../core/app_palette.dart';
import '../../data/consent_store.dart';
import 'consent_screen.dart';

class ConsentGate extends StatefulWidget {
  const ConsentGate({super.key, required this.userId, required this.child});

  final int userId;
  final Widget child;

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  bool? _accepted;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ConsentGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _accepted = null;
      _load();
    }
  }

  Future<void> _load() async {
    final accepted = await ConsentStore.hasConsent(widget.userId);
    if (!mounted) return;
    setState(() => _accepted = accepted);
  }

  @override
  Widget build(BuildContext context) {
    final accepted = _accepted;
    if (accepted == null) {
      return const Scaffold(
        backgroundColor: AppPalette.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!accepted) {
      return ConsentScreen(
        userId: widget.userId,
        onAccepted: () => setState(() => _accepted = true),
      );
    }

    return widget.child;
  }
}
