import 'dart:async';

import 'package:flutter/material.dart';

/// Rebuilds only the clock text once a second.
class LiveClock extends StatefulWidget {
  const LiveClock({super.key, required this.builder});

  final Widget Function(DateTime now) builder;

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = DateTime.now();
      if (next.minute != _now.minute || next.hour != _now.hour) {
        setState(() => _now = next);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_now);
}
