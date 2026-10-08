import 'dart:async';

import 'package:driver_diary/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Спиннер, который после [delay] объясняет, почему так долго.
class SlowLoading extends StatefulWidget {
  const SlowLoading({
    super.key,
    this.delay = const Duration(seconds: 3),
    this.hint =
        'Сервер просыпается — бесплатный хостинг усыпляет его без запросов. '
        'Обычно это до минуты.',
  });

  final Duration delay;
  final String hint;

  @override
  State<SlowLoading> createState() => _SlowLoadingState();
}

class _SlowLoadingState extends State<SlowLoading> {
  late final Timer _timer;
  var _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () => setState(() => _slow = true));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            AnimatedOpacity(
              opacity: _slow ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  widget.hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
