import 'dart:async';
import 'package:flutter/material.dart';

/// A widget that scrolls its child horizontally in a marquee fashion.
/// Uses Timer.periodic for better resource management instead of while loop.
class MarqueeWidget extends StatefulWidget {
  final Widget child;
  final Duration pauseDuration;

  const MarqueeWidget({
    super.key,
    required this.child,
    this.pauseDuration = const Duration(seconds: 2),
  });

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget> {
  late ScrollController _scrollController;
  Timer? _scrollTimer;
  bool _isAnimating = false;
  bool _isScrollingForward = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrollTimer());
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrollTimer() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(widget.pauseDuration, (_) => _performScroll());
  }

  Future<void> _performScroll() async {
    if (_isAnimating || !mounted) return;
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    _isAnimating = true;

    try {
      final targetPosition = _isScrollingForward ? maxScroll : 0.0;
      final duration = Duration(milliseconds: (maxScroll * 30).toInt().clamp(500, 10000));

      await _scrollController.animateTo(
        targetPosition,
        duration: duration,
        curve: Curves.linear,
      );

      if (mounted) {
        _isScrollingForward = !_isScrollingForward;
      }
    } catch (e) {
      // Animation was interrupted (e.g., widget disposed)
    } finally {
      _isAnimating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      child: widget.child,
    );
  }
}
