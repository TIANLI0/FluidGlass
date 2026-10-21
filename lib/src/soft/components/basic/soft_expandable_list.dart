// Derived from coui17 basic/ExpandableList.kt, Apache-2.0.
import 'package:flutter/widgets.dart';

import '../../../internal/control_focus.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_pressable.dart';

abstract final class SoftExpandableListDefaults {
  static const Duration duration = Duration(milliseconds: 400);
  static const Curve curve = Cubic(0.3, 0, 0.1, 1);
}

/// Controlled expanding group for use inside an existing scroll view.
/// Height and opacity run on the same 400ms curve; children cannot receive
/// input during the transition and are removed when fully collapsed.
class SoftExpandableGroup extends StatefulWidget {
  const SoftExpandableGroup({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.headerBuilder,
    required this.children,
    this.enabled = true,
    this.semanticLabel,
    this.duration = SoftExpandableListDefaults.duration,
  });
  final bool expanded, enabled;
  final VoidCallback? onToggle;
  final Widget Function(BuildContext context, bool expanded) headerBuilder;
  final List<Widget> children;
  final String? semanticLabel;
  final Duration duration;
  @override
  State<SoftExpandableGroup> createState() => _SoftExpandableGroupState();
}

class _SoftExpandableGroupState extends State<SoftExpandableGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.expanded ? 1 : 0,
  );
  Animation<double> get _progress => _controller;
  bool _reduce = false;

  void _sync() {
    if (_reduce) {
      _controller.value = widget.expanded ? 1 : 0;
    } else {
      _controller.animateTo(
        widget.expanded ? 1 : 0,
        duration: widget.duration,
        curve: SoftExpandableListDefaults.curve,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = softReduceMotion(context);
    if (_reduce) _sync();
  }

  @override
  void didUpdateWidget(SoftExpandableGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (oldWidget.expanded != widget.expanded) _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Semantics(
        label: widget.semanticLabel,
        expanded: widget.expanded,
        child: ControlFocus(
          enabled: widget.enabled && widget.onToggle != null,
          onActivate: widget.onToggle,
          child: SoftPressable(
            enabled: widget.enabled,
            onTap: widget.onToggle,
            child: widget.headerBuilder(context, widget.expanded),
          ),
        ),
      ),
      AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) {
          if (_controller.value == 0 && !widget.expanded) {
            return const SizedBox.shrink();
          }
          return ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: _progress.value,
              child: Opacity(
                opacity: _progress.value,
                child: IgnorePointer(
                  ignoring: _controller.isAnimating || !widget.expanded,
                  child: ExcludeSemantics(
                    excluding: _controller.isAnimating || !widget.expanded,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.children,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}

/// A bounded, lazily built list of expanding groups. At the expansion cap,
/// the pinned Kotlin implementation removes the lowest previously open index.
/// Headers and child rows remain caller-owned.
class SoftExpandableList extends StatelessWidget {
  const SoftExpandableList({
    super.key,
    required this.groupCount,
    required this.childCount,
    required this.expandedGroups,
    required this.onExpandedGroupsChanged,
    required this.headerBuilder,
    required this.childBuilder,
    this.maxExpandedGroups,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.enabled = true,
  }) : assert(groupCount >= 0),
       assert(maxExpandedGroups == null || maxExpandedGroups > 0);

  final int groupCount;
  final int Function(int group) childCount;
  final Set<int> expandedGroups;
  final ValueChanged<Set<int>> onExpandedGroupsChanged;
  final Widget Function(BuildContext context, int group, bool expanded)
  headerBuilder;
  final Widget Function(BuildContext context, int group, int child)
  childBuilder;
  final int? maxExpandedGroups;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: controller,
    padding: padding,
    itemCount: groupCount,
    itemBuilder: (BuildContext context, int group) => SoftExpandableGroup(
      key: ValueKey<int>(group),
      expanded: expandedGroups.contains(group),
      enabled: enabled,
      onToggle: () {
        final Set<int> next = Set<int>.of(expandedGroups);
        if (!next.remove(group)) {
          next.add(group);
          if (maxExpandedGroups != null &&
              next.length > maxExpandedGroups! &&
              expandedGroups.isNotEmpty) {
            final int lowest = expandedGroups.reduce((a, b) => a < b ? a : b);
            next.remove(lowest);
          }
        }
        onExpandedGroupsChanged(next);
      },
      headerBuilder: (BuildContext context, bool expanded) =>
          headerBuilder(context, group, expanded),
      children: List<Widget>.generate(
        childCount(group),
        (int child) => childBuilder(context, group, child),
      ),
    ),
  );
}
