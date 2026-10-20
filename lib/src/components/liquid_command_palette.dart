import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../animation/spring.dart';
import '../backdrop.dart';
import '../backdrops/native_backdrop.dart';
import '../shapes/rounded_rectangular_shape.dart';
import '../theme/liquid_glass_theme.dart';
import 'liquid_morph.dart';
import 'liquid_panel.dart';

/// A searchable action. [id] must be unique within a command palette.
@immutable
class LiquidCommand {
  const LiquidCommand({
    required this.id,
    required this.label,
    this.description,
    this.icon,
    this.group,
    this.keywords = const <String>[],
    this.shortcut,
    this.enabled = true,
  }) : assert(id.length > 0),
       assert(label.length > 0);

  final String id;
  final String label;
  final String? description;
  final IconData? icon;
  final String? group;
  final List<String> keywords;

  /// A visual hint only; the palette does not register application shortcuts.
  final String? shortcut;
  final bool enabled;
}

/// All built-in copy, so a palette can use the application's own language.
@immutable
class LiquidCommandPaletteLabels {
  const LiquidCommandPaletteLabels({
    this.title = 'Command center',
    this.searchHint = 'Search commands…',
    this.emptyTitle = 'No matching commands',
    this.emptyMessage = 'Try another word or clear your search.',
    this.clear = 'Clear search',
    this.close = 'Close',
    this.commands = 'commands',
    this.navigate = 'Navigate',
    this.run = 'Run',
    this.tapToRun = 'Tap a command to run',
    this.running = 'Running',
    this.completed = 'Completed',
    this.error = 'That did not finish. Try again.',
    this.retry = 'Retry',
  });

  final String title;
  final String searchHint;
  final String emptyTitle;
  final String emptyMessage;
  final String clear;
  final String close;
  final String commands;
  final String navigate;
  final String run;
  final String tapToRun;
  final String running;
  final String completed;
  final String error;
  final String retry;
}

/// A searchable, grouped action surface with one shared pane of glass.
///
/// Arrows move a spring-driven selection beam while focus stays in the input.
/// Enter runs the selection; Escape calls [onDismiss], or clears an inline
/// palette. Text editing keys and IME composition remain with the text field.
///
/// [onSelected] may be asynchronous. Execution is serialized, failures stay in
/// the panel with a retry action, and [onCompleted] runs only after success.
/// Applications should navigate after [showLiquidCommandPalette] returns.
class LiquidCommandPalette extends StatefulWidget {
  const LiquidCommandPalette({
    super.key,
    required this.commands,
    required this.onSelected,
    this.backdrop = nativeBackdrop,
    this.labels = const LiquidCommandPaletteLabels(),
    this.controller,
    this.focusNode,
    this.autofocus = true,
    this.initialSelectedId,
    this.onDismiss,
    this.onCompleted,
    this.onError,
    this.accentColor,
    this.surfaceColor,
    this.maxWidth = 620,
    this.maxHeight = 600,
    this.resultsHeight = 336,
  }) : assert(maxWidth > 0 && maxWidth < double.infinity),
       assert(maxHeight > 0 && maxHeight < double.infinity),
       assert(resultsHeight > 0 && resultsHeight < double.infinity);

  /// Treat this list, the command objects and their keyword lists as immutable.
  final List<LiquidCommand> commands;
  final FutureOr<void> Function(LiquidCommand command) onSelected;
  final Backdrop backdrop;
  final LiquidCommandPaletteLabels labels;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;

  /// The initial keyboard cursor, if that command exists and is enabled.
  final String? initialSelectedId;
  final VoidCallback? onDismiss;
  final ValueChanged<LiquidCommand>? onCompleted;
  final void Function(Object error, StackTrace stack)? onError;
  final Color? accentColor;
  final Color? surfaceColor;
  final double maxWidth;
  final double maxHeight;

  /// Kept stable while filtering, so the search field and footer never jump.
  final double resultsHeight;

  @override
  State<LiquidCommandPalette> createState() => _LiquidCommandPaletteState();
}

class _LiquidCommandPaletteState extends State<LiquidCommandPalette> {
  late TextEditingController _controller;
  late FocusNode _focus;
  late List<_SearchEntry> _index;
  List<LiquidCommand> _results = const <LiquidCommand>[];
  String? _selectedId;
  LiquidCommand? _attempt;
  LiquidCommand? _completed;
  bool _running = false;
  bool _failed = false;
  int _revision = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focus = widget.focusNode ?? FocusNode(debugLabel: 'Liquid command search');
    _selectedId = widget.initialSelectedId;
    _buildIndex();
    _query = _controller.text;
    _filter();
    _controller.addListener(_onQuery);
  }

  void _buildIndex() {
    assert(
      widget.commands.map((c) => c.id).toSet().length == widget.commands.length,
      'LiquidCommand ids must be unique.',
    );
    _index = <_SearchEntry>[
      for (int i = 0; i < widget.commands.length; i++)
        _SearchEntry(widget.commands[i], i),
    ];
  }

  @override
  void didUpdateWidget(LiquidCommandPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final TextEditingValue previous = _controller.value;
      _controller.removeListener(_onQuery);
      if (oldWidget.controller == null) _controller.dispose();
      _controller =
          widget.controller ?? TextEditingController.fromValue(previous);
      _controller.addListener(_onQuery);
      _query = _controller.text;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) _focus.dispose();
      _focus =
          widget.focusNode ?? FocusNode(debugLabel: 'Liquid command search');
    }
    if (oldWidget.commands != widget.commands ||
        oldWidget.controller != widget.controller) {
      _buildIndex();
      _filter();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onQuery);
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _onQuery() {
    if (_controller.text == _query) return;
    setState(() {
      _query = _controller.text;
      _failed = false;
      _completed = null;
      _filter();
    });
  }

  void _filter() {
    final List<String> words = _query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final List<(_SearchEntry, int)> matches = <(_SearchEntry, int)>[];
    for (final _SearchEntry entry in _index) {
      final int score = entry.score(words);
      if (score >= 0) matches.add((entry, score));
    }
    matches.sort((a, b) {
      final int byScore = a.$2.compareTo(b.$2);
      return byScore != 0 ? byScore : a.$1.order.compareTo(b.$1.order);
    });
    final Map<String?, List<LiquidCommand>> groups =
        <String?, List<LiquidCommand>>{};
    for (final match in matches) {
      (groups[match.$1.command.group] ??= <LiquidCommand>[]).add(
        match.$1.command,
      );
    }
    final List<LiquidCommand> next = groups.values
        .expand((group) => group)
        .toList();
    if (!listEquals(
      _results.map((c) => c.id).toList(),
      next.map((c) => c.id).toList(),
    )) {
      _revision++;
    }
    _results = next;
    if (!_results.any((c) => c.id == _selectedId && c.enabled)) {
      _selectedId = _results.where((c) => c.enabled).firstOrNull?.id;
    }
  }

  void _move(int direction) {
    if (_running) return;
    final List<LiquidCommand> enabled = _results
        .where((c) => c.enabled)
        .toList();
    if (enabled.isEmpty) return;
    final int current = enabled.indexWhere((c) => c.id == _selectedId);
    final int next = current < 0
        ? 0
        : (current + direction).clamp(0, enabled.length - 1);
    if (_selectedId != enabled[next].id) {
      setState(() => _selectedId = enabled[next].id);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Candidate selection belongs to the IME, including Enter and arrow keys.
    if (!_controller.value.composing.isCollapsed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _move(-1);
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (event is KeyDownEvent) {
        final LiquidCommand? command = _results
            .where((c) => c.id == _selectedId)
            .firstOrNull;
        if (command != null) unawaited(_execute(command));
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        if (widget.onDismiss != null) {
          widget.onDismiss!();
        } else {
          _controller.clear();
        }
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Future<void> _execute(LiquidCommand command) async {
    if (_running || !command.enabled) return;
    setState(() {
      _running = true;
      _failed = false;
      _completed = null;
      _attempt = command;
      _selectedId = command.id;
    });
    try {
      await widget.onSelected(command);
    } catch (error, stack) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _failed = true;
      });
      widget.onError?.call(error, stack);
      return;
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _completed = command;
    });
    widget.onCompleted?.call(command);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final colors = LiquidGlassTheme.of(context);
    final Color accent = widget.accentColor ?? colors.accent;
    final Color ink = colors.content;
    // Dense information needs a steadier surface than a small glass button.
    final Color surface =
        widget.surfaceColor ??
        Color.alphaBlend(
          colors.container,
          theme.colorScheme.surface.withValues(alpha: dark ? 0.90 : 0.92),
        );
    final labels = widget.labels;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxHeight < 260;
          return Focus(
            onKeyEvent: _onKey,
            includeSemantics: false,
            canRequestFocus: false,
            child: LiquidPanel(
              backdrop: widget.backdrop,
              shape: const RoundedRectangle(28),
              surfaceColor: surface,
              blurRadius: 12,
              refractionHeight: 12,
              refractionAmount: 14,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            accent.withValues(alpha: 0),
                            accent.withValues(alpha: 0.7),
                            Color.lerp(accent, colors.glow, 0.6)!,
                            accent.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                    if (!compact)
                      Padding(
                        key: const ValueKey<String>('command-title'),
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          22,
                          8,
                          12,
                          0,
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.blur_on_rounded,
                              color: accent,
                              size: 18,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                labels.title,
                                style: TextStyle(
                                  color: ink.withValues(alpha: 0.66),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            if (widget.onDismiss != null)
                              IconButton(
                                tooltip: labels.close,
                                onPressed: widget.onDismiss,
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: ink.withValues(alpha: 0.6),
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    Padding(
                      key: const ValueKey<String>('command-input'),
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        22,
                        4,
                        16,
                        16,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.search_rounded,
                            color: ink.withValues(alpha: 0.45),
                            size: 25,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focus,
                              autofocus: widget.autofocus,
                              readOnly: _running,
                              maxLines: 1,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) {
                                final command = _results
                                    .where((c) => c.id == _selectedId)
                                    .firstOrNull;
                                if (command != null) {
                                  unawaited(_execute(command));
                                }
                              },
                              style: TextStyle(
                                color: ink,
                                fontSize: 21,
                                fontWeight: FontWeight.w500,
                              ),
                              cursorColor: accent,
                              decoration: InputDecoration(
                                hintText: labels.searchHint,
                                isDense: true,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: ink.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            child: ExcludeSemantics(
                              excluding: _query.isEmpty,
                              child: IgnorePointer(
                                ignoring: _query.isEmpty || _running,
                                child: AnimatedOpacity(
                                  opacity: _query.isEmpty ? 0 : 1,
                                  duration: still
                                      ? Duration.zero
                                      : const Duration(milliseconds: 140),
                                  child: IconButton(
                                    tooltip: labels.clear,
                                    onPressed: _running
                                        ? null
                                        : _controller.clear,
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      size: 19,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (compact && widget.onDismiss != null)
                            IconButton(
                              tooltip: labels.close,
                              onPressed: widget.onDismiss,
                              icon: Icon(
                                Icons.close_rounded,
                                color: ink.withValues(alpha: 0.65),
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: ink.withValues(alpha: 0.07)),
                    Flexible(
                      key: const ValueKey<String>('command-results'),
                      child: SizedBox(
                        height: widget.resultsHeight,
                        child: AnimatedSwitcher(
                          duration: still
                              ? Duration.zero
                              : const Duration(milliseconds: 160),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          layoutBuilder:
                              (Widget? current, List<Widget> previous) => Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  for (final child in previous)
                                    ExcludeSemantics(
                                      child: IgnorePointer(child: child),
                                    ),
                                  ?current,
                                ],
                              ),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.015),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  ),
                          child: _results.isEmpty
                              ? _EmptyCommands(
                                  key: const ValueKey<String>('empty'),
                                  labels: labels,
                                  ink: ink,
                                )
                              : _CommandResults(
                                  key: ValueKey<int>(_revision),
                                  commands: _results,
                                  selectedId: _selectedId,
                                  busy: _running,
                                  accent: accent,
                                  ink: ink,
                                  onHover: (id) {
                                    if (!_running && _selectedId != id) {
                                      setState(() => _selectedId = id);
                                    }
                                  },
                                  onSelected: (command) =>
                                      unawaited(_execute(command)),
                                ),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: ink.withValues(alpha: 0.07)),
                    Padding(
                      key: const ValueKey<String>('command-status'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: _animatedStatus(ink, accent, still),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _animatedStatus(Color ink, Color accent, bool still) {
    if (still) return _buildStatus(ink, accent, true);
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 140),
        child: _buildStatus(ink, accent, false),
      ),
    );
  }

  Widget _buildStatus(Color ink, Color accent, bool still) {
    final labels = widget.labels;
    final LiquidCommand? retryCommand = widget.commands
        .where((c) => c.id == _attempt?.id && c.enabled)
        .firstOrNull;
    if (_running || _failed || _completed != null) {
      final Color color = _failed
          ? LiquidGlassTheme.of(context).destructive
          : accent;
      return Semantics(
        key: ValueKey<String>(
          _running
              ? 'running'
              : _failed
              ? 'failed'
              : 'done',
        ),
        liveRegion: true,
        child: Row(
          children: <Widget>[
            if (_running && !still)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(
                _failed
                    ? Icons.error_outline_rounded
                    : _running
                    ? Icons.hourglass_top_rounded
                    : Icons.check_circle_outline_rounded,
                color: color,
                size: 18,
              ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _failed
                    ? labels.error
                    : '${_running ? labels.running : labels.completed} · ${(_running ? _attempt : _completed)?.label ?? ''}',
                style: TextStyle(
                  color: ink.withValues(alpha: 0.72),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            if (_failed)
              TextButton(
                onPressed: retryCommand == null
                    ? null
                    : () => unawaited(_execute(retryCommand)),
                child: Text(labels.retry),
              ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        key: const ValueKey<String>('idle'),
        children: <Widget>[
          Text(
            '${_results.length} ${labels.commands}',
            style: TextStyle(color: ink.withValues(alpha: 0.65), fontSize: 12),
          ),
          const Spacer(),
          if (constraints.maxWidth >=
              400 *
                  MediaQuery.textScalerOf(context).scale(11) /
                  11) ...<Widget>[
            _KeyHint('↑ ↓', ink: ink),
            const SizedBox(width: 6),
            Text(
              labels.navigate,
              style: TextStyle(
                color: ink.withValues(alpha: 0.65),
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 16),
            _KeyHint('Enter', ink: ink),
            const SizedBox(width: 6),
            Text(
              labels.run,
              style: TextStyle(
                color: ink.withValues(alpha: 0.65),
                fontSize: 11,
              ),
            ),
          ] else
            Flexible(
              child: Text(
                labels.tapToRun,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink.withValues(alpha: 0.65),
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchEntry {
  _SearchEntry(this.command, this.order)
    : label = command.label.toLowerCase(),
      terms =
          '${command.label} ${command.description ?? ''} ${command.group ?? ''} ${command.keywords.join(' ')}'
              .toLowerCase();
  final LiquidCommand command;
  final int order;
  final String label;
  final String terms;

  int score(List<String> words) {
    int result = 0;
    for (final word in words) {
      if (!terms.contains(word)) return -1;
      result += label.startsWith(word)
          ? 0
          : label.contains(word)
          ? 1
          : 2;
    }
    return result;
  }
}

class _CommandResults extends StatefulWidget {
  const _CommandResults({
    super.key,
    required this.commands,
    required this.selectedId,
    required this.busy,
    required this.accent,
    required this.ink,
    required this.onHover,
    required this.onSelected,
  });
  final List<LiquidCommand> commands;
  final String? selectedId;
  final bool busy;
  final Color accent;
  final Color ink;
  final ValueChanged<String> onHover;
  final ValueChanged<LiquidCommand> onSelected;
  @override
  State<_CommandResults> createState() => _CommandResultsState();
}

class _CommandResultsState extends State<_CommandResults>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final SpringValue _selection = SpringValue(
    vsync: this,
    value: 0,
    visibilityThreshold: 0.1,
  );
  late final Listenable _repaint = Listenable.merge(<Listenable>[
    _selection,
    _scroll,
  ]);
  double _rowHeight = 68;
  double _groupHeight = 30;
  double _selectedY = 0;
  bool _still = false;
  final List<Object> _rows = <Object>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final TextScaler scale = MediaQuery.textScalerOf(context);
    _rowHeight = math.max(
      68,
      scale.scale(15) * 1.3 + scale.scale(12) * 1.3 + 24,
    );
    _groupHeight = math.max(30, scale.scale(11) * 1.3 + 12);
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _resolveRows();
    _selection.snapTo(_selectedY);
    _revealSelection();
  }

  @override
  void didUpdateWidget(_CommandResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveRows();
    if (oldWidget.selectedId != widget.selectedId) {
      if (_still) {
        _selection.snapTo(_selectedY);
      } else {
        _selection.animateTo(_selectedY, springOf(0.95, 520));
      }
      _revealSelection();
    }
  }

  void _resolveRows() {
    _rows.clear();
    String? group;
    double y = 8;
    for (final command in widget.commands) {
      if (command.group != null && command.group != group) {
        _rows.add(command.group!);
        y += _groupHeight;
      }
      group = command.group;
      if (command.id == widget.selectedId) _selectedY = y;
      _rows.add(command);
      y += _rowHeight;
    }
  }

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || widget.selectedId == null) return;
      final double top = _scroll.offset;
      final double bottom = top + _scroll.position.viewportDimension;
      double target = top;
      if (_selectedY < top) target = _selectedY;
      if (_selectedY + _rowHeight > bottom) {
        target = _selectedY + _rowHeight - _scroll.position.viewportDimension;
      }
      target = target.clamp(0.0, _scroll.position.maxScrollExtent);
      if (target == top) return;
      if (_still) {
        _scroll.jumpTo(target);
      } else {
        unawaited(
          _scroll.animateTo(
            target,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _selection.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(
          child: CustomPaint(
            painter: _SelectionPainter(
              y: _selection,
              scroll: _scroll,
              repaint: _repaint,
              rowHeight: _rowHeight,
              color: widget.accent,
              visible: widget.selectedId != null,
              isLtr: Directionality.of(context) == TextDirection.ltr,
            ),
          ),
        ),
        ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _rows.length,
          itemBuilder: (context, index) {
            final Object row = _rows[index];
            if (row is String) {
              return SizedBox(
                height: _groupHeight,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 0),
                  child: Semantics(
                    header: true,
                    child: Text(
                      row,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.ink.withValues(alpha: 0.65),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              );
            }
            final command = row as LiquidCommand;
            final bool selected = command.id == widget.selectedId;
            final bool enabled = command.enabled && !widget.busy;
            final Color ink = widget.ink.withValues(
              alpha: command.enabled ? 1 : 0.35,
            );
            return Semantics(
              key: ValueKey<String>(command.id),
              container: true,
              button: true,
              enabled: enabled,
              selected: selected,
              liveRegion: selected,
              label:
                  '${command.label}${command.description == null ? '' : ', ${command.description}'}',
              onTap: enabled ? () => widget.onSelected(command) : null,
              excludeSemantics: true,
              child: MouseRegion(
                onEnter: enabled ? (_) => widget.onHover(command.id) : null,
                child: InkWell(
                  canRequestFocus: false,
                  excludeFromSemantics: true,
                  onTap: enabled ? () => widget.onSelected(command) : null,
                  splashFactory: NoSplash.splashFactory,
                  hoverColor: Colors.transparent,
                  highlightColor: widget.accent.withValues(alpha: 0.04),
                  child: SizedBox(
                    height: _rowHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: (selected ? widget.accent : widget.ink)
                                  .withValues(
                                    alpha: command.enabled ? 0.07 : 0.025,
                                  ),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              command.icon ?? Icons.bolt_rounded,
                              size: 19,
                              color: selected
                                  ? widget.accent
                                  : ink.withValues(alpha: 0.65),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  command.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 15,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                                if (command.description != null) ...<Widget>[
                                  const SizedBox(height: 3),
                                  Text(
                                    command.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: ink.withValues(
                                        alpha: command.enabled ? 0.65 : 0.3,
                                      ),
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (MediaQuery.sizeOf(context).width >= 420 &&
                              command.shortcut != null) ...<Widget>[
                            const SizedBox(width: 12),
                            _KeyHint(command.shortcut!, ink: ink),
                          ],
                          const SizedBox(width: 12),
                          AnimatedOpacity(
                            opacity: selected ? 1 : 0,
                            duration: _still
                                ? Duration.zero
                                : const Duration(milliseconds: 120),
                            child: Icon(
                              Icons.subdirectory_arrow_left_rounded,
                              color: widget.accent,
                              size: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter({
    required this.y,
    required this.scroll,
    required Listenable repaint,
    required this.rowHeight,
    required this.color,
    required this.visible,
    required this.isLtr,
  }) : super(repaint: repaint);
  final SpringValue y;
  final ScrollController scroll;
  final double rowHeight;
  final Color color;
  final bool visible;
  final bool isLtr;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final double top = y.value - (scroll.hasClients ? scroll.offset : 0);
    final Rect rect = Rect.fromLTWH(
      10,
      top + 2,
      math.max(0, size.width - 20),
      rowHeight - 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()
        ..shader = LinearGradient(
          begin: isLtr ? Alignment.centerLeft : Alignment.centerRight,
          end: isLtr ? Alignment.centerRight : Alignment.centerLeft,
          colors: <Color>[
            color.withValues(alpha: 0.13),
            color.withValues(alpha: 0.045),
          ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          isLtr ? 11 : size.width - 14,
          top + rowHeight * 0.28,
          3,
          rowHeight * 0.44,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SelectionPainter old) =>
      old.rowHeight != rowHeight ||
      old.color != color ||
      old.visible != visible ||
      old.isLtr != isLtr ||
      old.y != y ||
      old.scroll != scroll;
}

class _EmptyCommands extends StatelessWidget {
  const _EmptyCommands({super.key, required this.labels, required this.ink});
  final LiquidCommandPaletteLabels labels;
  final Color ink;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.search_off_rounded,
                size: 32,
                color: ink.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 12),
              Text(
                labels.emptyTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ink.withValues(alpha: 0.75),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                labels.emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ink.withValues(alpha: 0.65),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _KeyHint extends StatelessWidget {
  const _KeyHint(this.label, {required this.ink});
  final String label;
  final Color ink;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: ink.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(5),
        color: ink.withValues(alpha: 0.025),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ink.withValues(alpha: 0.65),
          fontSize: 10,
          height: 1,
        ),
      ),
    ),
  );
}

/// Presents a palette and returns the command after successful execution.
///
/// Cancellation returns null. [origin] is the launcher's global rectangle: the
/// same morph reverses on close, including when dismissed halfway through entry.
/// Application navigation belongs after the returned future, not in [onSelected].
Future<LiquidCommand?> showLiquidCommandPalette({
  required BuildContext context,
  required List<LiquidCommand> commands,
  FutureOr<void> Function(LiquidCommand command)? onSelected,
  void Function(Object error, StackTrace stack)? onError,
  Backdrop backdrop = nativeBackdrop,
  LiquidCommandPaletteLabels labels = const LiquidCommandPaletteLabels(),
  Color? accentColor,
  Color? surfaceColor,
  String? initialSelectedId,
  Rect? origin,
  double originRadius = 24,
  bool useRootNavigator = true,
  bool barrierDismissible = true,
  RouteSettings? routeSettings,
}) {
  final NavigatorState navigator = Navigator.of(
    context,
    rootNavigator: useRootNavigator,
  );
  final CapturedThemes themes = InheritedTheme.capture(
    from: context,
    to: navigator.context,
  );
  final colors = LiquidGlassTheme.of(context);
  final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<LiquidCommand>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.2),
    routeSettings: routeSettings,
    transitionDuration: still
        ? Duration.zero
        : const Duration(milliseconds: 360),
    pageBuilder: (dialogContext, animation, secondaryAnimation) => themes.wrap(
      LiquidGlassTheme(
        colors: colors,
        child: Builder(
          builder: (context) {
            void close([LiquidCommand? command]) {
              final ModalRoute<dynamic>? route = ModalRoute.of(context);
              if (route == null || !route.isActive) return;
              if (route.isCurrent) {
                Navigator.of(context).pop(command);
              } else {
                route.navigator?.removeRoute(route, command);
              }
            }

            return SafeArea(
              child: AnimatedPadding(
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.fromLTRB(
                  16,
                  24,
                  16,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Align(
                  alignment: const Alignment(0, -0.2),
                  child: LiquidMorph(
                    progress: animation,
                    origin: origin,
                    originRadius: originRadius,
                    radius: 28,
                    outset: 32,
                    child: RepaintBoundary(
                      child: LiquidCommandPalette(
                        commands: commands,
                        onSelected: onSelected ?? (_) {},
                        onCompleted: close,
                        onDismiss: close,
                        onError: onError,
                        backdrop: backdrop,
                        labels: labels,
                        accentColor: accentColor,
                        surfaceColor: surfaceColor,
                        initialSelectedId: initialSelectedId,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: animation.drive(CurveTween(curve: const Interval(0, 0.35))),
          child: child,
        ),
  );
}
