import 'package:flutter/material.dart';

const Duration kSettingsOpacityPressDuration = Duration(milliseconds: 100);
const double kSettingsOpacityPressValue = 0.58;

/// Fades [child] together on press. Optional [onTap]: if null, only pointer
/// press dims (no action). If set, uses [Focus] + [GestureDetector] (no ink splash).
class SettingsOpacityTap extends StatefulWidget {
  const SettingsOpacityTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.focusDebugLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? focusDebugLabel;

  @override
  State<SettingsOpacityTap> createState() => _SettingsOpacityTapState();
}

class _SettingsOpacityTapState extends State<SettingsOpacityTap> {
  bool _pressed = false;
  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();
    if (widget.onTap != null) {
      _focusNode = FocusNode(debugLabel: widget.focusDebugLabel);
    }
  }

  @override
  void dispose() {
    _focusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode?.hasFocus ?? false;
    final dimmed = _pressed || focused;

    final opacityChild = AnimatedOpacity(
      duration: kSettingsOpacityPressDuration,
      curve: Curves.easeOut,
      opacity: dimmed ? kSettingsOpacityPressValue : 1.0,
      child: widget.child,
    );

    if (widget.onTap == null && widget.onLongPress == null) {
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: opacityChild,
      );
    }

    final detector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onLongPressStart: (_) => setState(() => _pressed = true),
      onLongPressEnd: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: opacityChild,
    );

    if (_focusNode == null) return detector;

    return Focus(
      focusNode: _focusNode,
      onFocusChange: (_) {
        if (mounted) setState(() {});
      },
      child: detector,
    );
  }
}
