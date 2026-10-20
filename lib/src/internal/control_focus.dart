import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _StepIntent extends Intent {
  const _StepIntent(this.direction);
  final int direction;
}

class _EndpointIntent extends Intent {
  const _EndpointIntent(this.last);
  final bool last;
}

/// Shared keyboard traversal, activation, adjustment and visible focus feedback.
class ControlFocus extends StatefulWidget {
  const ControlFocus({
    super.key,
    required this.child,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.onActivate,
    this.onStep,
    this.onFirst,
    this.onLast,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
  });

  final Widget child;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onActivate;
  final ValueChanged<int>? onStep;
  final VoidCallback? onFirst;
  final VoidCallback? onLast;
  final BorderRadius borderRadius;

  @override
  State<ControlFocus> createState() => _ControlFocusState();
}

class _ControlFocusState extends State<ControlFocus> {
  bool _showFocus = false;

  @override
  Widget build(BuildContext context) {
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (bool value) {
          if (_showFocus != value) setState(() => _showFocus = value);
        },
        shortcuts: <ShortcutActivator, Intent>{
          if (widget.onActivate != null) ...<ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.enter):
                const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.numpadEnter):
                const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.space):
                const ActivateIntent(),
          },
          if (widget.onStep != null) ...<ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(
              isLtr ? 1 : -1,
            ),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(
              isLtr ? -1 : 1,
            ),
            const SingleActivator(LogicalKeyboardKey.arrowUp):
                const _StepIntent(1),
            const SingleActivator(LogicalKeyboardKey.arrowDown):
                const _StepIntent(-1),
          },
          if (widget.onFirst != null)
            const SingleActivator(LogicalKeyboardKey.home):
                const _EndpointIntent(false),
          if (widget.onLast != null)
            const SingleActivator(LogicalKeyboardKey.end):
                const _EndpointIntent(true),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (widget.enabled) widget.onActivate?.call();
              return null;
            },
          ),
          _StepIntent: CallbackAction<_StepIntent>(
            onInvoke: (_StepIntent intent) {
              if (widget.enabled) widget.onStep?.call(intent.direction);
              return null;
            },
          ),
          _EndpointIntent: CallbackAction<_EndpointIntent>(
            onInvoke: (_EndpointIntent intent) {
              if (widget.enabled) {
                (intent.last ? widget.onLast : widget.onFirst)?.call();
              }
              return null;
            },
          ),
        },
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: _showFocus && widget.enabled
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
