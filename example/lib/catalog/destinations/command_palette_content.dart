import 'dart:async';

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _OpenCommandsIntent extends Intent {
  const _OpenCommandsIntent();
}

/// A product-sized example of the command palette, rather than a row of demos.
class CommandPaletteContent extends StatefulWidget {
  const CommandPaletteContent({super.key});

  @override
  State<CommandPaletteContent> createState() => _CommandPaletteContentState();
}

class _CommandPaletteContentState extends State<CommandPaletteContent> {
  Color get _accent =>
      _dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  static const List<LiquidCommand> _commands = <LiquidCommand>[
    LiquidCommand(
      id: 'canvas',
      label: 'Create a canvas',
      description: 'A fresh space for your next idea',
      icon: Icons.add_rounded,
      group: 'Workspace',
      keywords: <String>['new', 'design', '创建', '画布'],
      shortcut: 'N',
    ),
    LiquidCommand(
      id: 'recent',
      label: 'Open recent',
      description: 'Pick up where you left off',
      icon: Icons.history_rounded,
      group: 'Workspace',
      keywords: <String>['files', 'history', '最近'],
      shortcut: 'O',
    ),
    LiquidCommand(
      id: 'export',
      label: 'Export workspace',
      description: 'Prepare a local preview',
      icon: Icons.ios_share_rounded,
      group: 'Workspace',
      keywords: <String>['save', 'download', '导出'],
      shortcut: 'Shift E',
    ),
    LiquidCommand(
      id: 'appearance',
      label: 'Switch appearance',
      description: 'Find your light or dark side',
      icon: Icons.contrast_rounded,
      group: 'Make it yours',
      keywords: <String>['theme', 'dark', 'light', '主题'],
    ),
    LiquidCommand(
      id: 'sync',
      label: 'Test a retry',
      description: 'A recoverable failure, then a successful retry',
      icon: Icons.sync_rounded,
      group: 'Make it yours',
      keywords: <String>['error', 'failure', '失败'],
    ),
    LiquidCommand(
      id: 'team',
      label: 'Invite your team',
      description: 'Unavailable in this local demo',
      icon: Icons.people_outline_rounded,
      group: 'Make it yours',
      enabled: false,
    ),
  ];

  final GlobalKey _launcher = GlobalKey();
  bool _dark = false;
  bool _opening = false;
  int _canvases = 3;
  bool _retryFailed = false;
  String _status = 'Your next idea starts here.';

  Future<void> _perform(LiquidCommand command) async {
    if (command.id == 'export' || command.id == 'sync') {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
    }
    if (command.id == 'sync' && !_retryFailed) {
      _retryFailed = true;
      throw StateError('A deliberate demo failure. The next attempt succeeds.');
    }
    setState(() {
      switch (command.id) {
        case 'canvas':
          _canvases++;
          _status = 'Canvas $_canvases is ready. Make something good.';
        case 'recent':
          _status = 'Welcome back to Material studies.';
        case 'export':
          _status = 'Your local preview is ready.';
        case 'appearance':
          _dark = !_dark;
          _status = _dark
              ? 'A quieter space after dark.'
              : 'A little more daylight.';
        case 'sync':
          _status = 'Recovered. Your work is safe.';
        default:
          _status = command.label;
      }
    });
  }

  Future<void> _open(BuildContext context) async {
    if (_opening) return;
    _opening = true;
    final RenderBox? box =
        _launcher.currentContext?.findRenderObject() as RenderBox?;
    try {
      await showLiquidCommandPalette(
        context: context,
        commands: _commands,
        accentColor: _accent,
        origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        onSelected: _perform,
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final ThemeData theme = ThemeData(
      brightness: _dark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: _accent,
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      fontFamilyFallback: Theme.of(
        context,
      ).textTheme.bodyMedium?.fontFamilyFallback,
      splashFactory: LiquidInkHighlight.splashFactory,
    );
    final Color ink = _dark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    return AnimatedTheme(
      data: theme,
      duration: still ? Duration.zero : const Duration(milliseconds: 240),
      child: LiquidGlassTheme(
        colors: LiquidGlassColors.forBrightness(theme.brightness).copyWith(
          accent: _accent,
          toggleAccent: _accent,
          content: ink,
          glow: const Color(0xFFD8EAFF),
        ),
        child: Builder(
          builder: (context) => Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.keyK, control: true):
                  _OpenCommandsIntent(),
              SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                  _OpenCommandsIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                _OpenCommandsIntent: CallbackAction<_OpenCommandsIntent>(
                  onInvoke: (_) {
                    unawaited(_open(context));
                    return null;
                  },
                ),
              },
              child: Focus(
                autofocus: true,
                child: AnimatedContainer(
                  width: double.infinity,
                  height: double.infinity,
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _dark
                          ? const <Color>[
                              Color(0xFF101B2E),
                              Color(0xFF14171F),
                              Color(0xFF1B2639),
                            ]
                          : const <Color>[
                              Color(0xFFF7F9FD),
                              Color(0xFFEDF3FF),
                              Color(0xFFE7EEFA),
                            ],
                    ),
                  ),
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final bool wide = constraints.maxWidth >= 960;
                        return SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            wide ? 72 : 24,
                            88,
                            wide ? 72 : 24,
                            40,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1120),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Icon(
                                        Icons.blur_on_rounded,
                                        color: ink,
                                        size: 26,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'fluid / studio',
                                        style: TextStyle(
                                          color: ink,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'Switch appearance',
                                        onPressed: () =>
                                            setState(() => _dark = !_dark),
                                        icon: Icon(
                                          _dark
                                              ? Icons.light_mode_outlined
                                              : Icons.dark_mode_outlined,
                                          color: ink,
                                          size: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: wide ? 80 : 32),
                                  if (wide)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: <Widget>[
                                        Expanded(
                                          child: _intro(context, ink, wide),
                                        ),
                                        const SizedBox(width: 64),
                                        SizedBox(
                                          width: 540,
                                          child: _palette(context),
                                        ),
                                      ],
                                    )
                                  else ...<Widget>[
                                    _intro(context, ink, wide),
                                    const SizedBox(height: 28),
                                    _palette(context),
                                  ],
                                  const SizedBox(height: 36),
                                  Divider(color: ink.withValues(alpha: 0.12)),
                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: _accent,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: AnimatedSize(
                                          duration: still
                                              ? Duration.zero
                                              : const Duration(
                                                  milliseconds: 180,
                                                ),
                                          alignment: Alignment.centerLeft,
                                          child: AnimatedSwitcher(
                                            layoutBuilder:
                                                (current, previous) => Stack(
                                                  alignment:
                                                      AlignmentDirectional
                                                          .centerStart,
                                                  children: <Widget>[
                                                    ...previous,
                                                    ?current,
                                                  ],
                                                ),
                                            duration: still
                                                ? Duration.zero
                                                : const Duration(
                                                    milliseconds: 160,
                                                  ),
                                            child: Text(
                                              _status,
                                              key: ValueKey<String>(_status),
                                              style: TextStyle(
                                                color: ink.withValues(
                                                  alpha: 0.65,
                                                ),
                                                fontSize: 13,
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro(BuildContext context, Color ink, bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        wide ? 'A little less\nsearching.' : 'A little less searching.',
        style: TextStyle(
          color: ink,
          fontSize: wide ? 50 : 32,
          height: 1.08,
          fontWeight: FontWeight.w500,
          letterSpacing: -1.6,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'A little more making.',
        style: TextStyle(
          color: _accent,
          fontSize: wide ? 25 : 20,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Text(
          'Your workspace, one clear command away.\nType a thought. Find your next move.',
          style: TextStyle(
            color: ink.withValues(alpha: 0.68),
            fontSize: 14,
            height: 1.7,
          ),
        ),
      ),
      const SizedBox(height: 26),
      LiquidButton(
        key: _launcher,
        backdrop: emptyBackdrop,
        surfaceColor: ink.withValues(alpha: 0.06),
        onPressed: () => unawaited(_open(context)),
        children: <Widget>[
          Icon(Icons.open_in_new_rounded, color: ink, size: 17),
          Text(
            'Open floating panel',
            style: TextStyle(
              color: ink,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        'Ctrl K / Cmd K  ·  open from anywhere',
        style: TextStyle(color: ink.withValues(alpha: 0.65), fontSize: 11),
      ),
    ],
  );

  Widget _palette(BuildContext context) => LiquidCommandPalette(
    commands: _commands,
    backdrop: nativeBackdrop,
    accentColor: _accent,
    autofocus: false,
    onSelected: _perform,
  );
}
