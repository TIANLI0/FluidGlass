import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart' show Icons, MaterialApp;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'soft_demo/motion_section.dart';
import 'soft_demo/reference_page.dart';

/// The soft family's navigation bar, laid out the way the reference gallery
/// lays out its own: a page of grey list cards under a floating bar with a
/// round view at each side, plus the bar's variants over a wallpaper.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SoftPrograms.instance.load();
  runApp(const SoftDemoApp());
}

class SoftDemoApp extends StatefulWidget {
  const SoftDemoApp({super.key, this.initialDark});

  /// Overrides the platform brightness; tests use it.
  final bool? initialDark;

  @override
  State<SoftDemoApp> createState() => _SoftDemoAppState();
}

class _SoftDemoAppState extends State<SoftDemoApp> {
  late bool? _dark = widget.initialDark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Soft',
      home: Builder(
        builder: (BuildContext context) => SoftDemoHome(
          dark: SoftTheme.of(context).isDark,
          onDarkChanged: (bool value) => setState(() => _dark = value),
        ),
      ),
      builder: (BuildContext context, Widget? child) {
        final bool dark =
            _dark ??
            MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        final SoftThemeData theme = dark
            ? const SoftThemeData.dark()
            : const SoftThemeData.light();
        return SoftTheme(
          data: theme,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: dark
                ? SystemUiOverlayStyle.light.copyWith(
                    systemNavigationBarColor: const Color(0x00000000),
                  )
                : SystemUiOverlayStyle.dark.copyWith(
                    systemNavigationBarColor: const Color(0x00000000),
                  ),
            child: DefaultTextStyle(
              style: theme.textStyles.body1.copyWith(
                color: theme.colors.onBackground,
              ),
              child: child!,
            ),
          ),
        );
      },
    );
  }
}

class SoftDemoHome extends StatefulWidget {
  const SoftDemoHome({
    super.key,
    required this.dark,
    required this.onDarkChanged,
  });

  final bool dark;
  final ValueChanged<bool> onDarkChanged;

  @override
  State<SoftDemoHome> createState() => _SoftDemoHomeState();
}

class _SoftDemoHomeState extends State<SoftDemoHome> {
  final LayerBackdrop _page = LayerBackdrop();
  int _tab = 0;
  String? _toast;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _say(String text) {
    setState(() => _toast = text);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _toast == text) setState(() => _toast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final List<String> titles = <String>['首页', '组件', '配色'];
    return ColoredBox(
      color: theme.colors.surface,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: BackdropLayer(
              backdrop: _page,
              motionPixelRatio: MediaQuery.devicePixelRatioOf(context) * 0.5,
              child: ColoredBox(
                color: theme.colors.surface,
                child: switch (_tab) {
                  0 => _HomeTab(
                    dark: widget.dark,
                    onDarkChanged: widget.onDarkChanged,
                  ),
                  1 => const SoftReferencePage(),
                  _ => _PlainTab(title: titles[_tab]),
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RepaintBoundary(
              child: SoftFloatingNavigationBar(
                backdrop: _page,
                quality: GlassQuality.liquid,
                selectedIndex: _tab,
                onSelected: (int i) => setState(() => _tab = i),
                start: SoftFloatingAccessory(
                  icon: const SoftGlyphIcon(SoftGlyph.search),
                  semanticLabel: '搜索',
                  onTap: () => _say('搜索'),
                ),
                end: SoftFloatingAccessory(
                  icon: const SoftGlyphIcon(SoftGlyph.more),
                  semanticLabel: '更多',
                  onTap: () => _say('更多'),
                ),
                items: const <SoftFloatingNavigationItem>[
                  SoftFloatingNavigationItem(
                    icon: SoftGlyphIcon(SoftGlyph.home),
                    selectedIcon: SoftGlyphIcon(SoftGlyph.home),
                    label: '首页',
                  ),
                  SoftFloatingNavigationItem(
                    icon: SoftGlyphIcon(SoftGlyph.image),
                    selectedIcon: SoftGlyphIcon(SoftGlyph.image),
                    label: '组件',
                  ),
                  SoftFloatingNavigationItem(
                    icon: SoftGlyphIcon(SoftGlyph.theme),
                    selectedIcon: SoftGlyphIcon(SoftGlyph.theme),
                    label: '配色',
                  ),
                ],
              ),
            ),
          ),
          if (_toast != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: SoftFloatingNavigationBarDefaults.extent(context) + 12,
              child: Center(child: _Toast(_toast!)),
            ),
        ],
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: theme.colors.onBackground,
        shape: SoftSquircleBorder.all(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          text,
          style: theme.textStyles.body2.copyWith(
            color: theme.colors.background,
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.dark, required this.onDarkChanged});

  final bool dark;
  final ValueChanged<bool> onDarkChanged;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(32, padding.top + 40, 32, 12),
            child: Text(
              '导航栏',
              style: theme.textStyles.title1.copyWith(
                color: theme.colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SoftSmallTitle('外观')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SoftCard(
              child: SoftBasicComponent(
                title: '深色模式',
                position: SoftCardListPosition.full,
                end: <Widget>[
                  SoftSwitch(checked: dark, onChanged: onDarkChanged),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SoftSmallTitle('底部悬浮导航栏')),
        const SliverToBoxAdapter(child: _PlainBarDemo()),
        const SliverToBoxAdapter(child: SoftSmallTitle('两侧带圆形按钮')),
        const SliverToBoxAdapter(child: _AccessoryBarDemo()),
        const SliverToBoxAdapter(
          child: SoftSmallTitle('选中某一格时融出的按钮（合成器模糊，不抓页面）'),
        ),
        const SliverToBoxAdapter(child: _ExpansionBarDemo()),
        const SliverToBoxAdapter(child: SoftSmallTitle('角标 · 大图标 · 禁用项')),
        const SliverToBoxAdapter(child: _BadgeBarDemo()),
        const SliverToBoxAdapter(child: SoftSmallTitle('动效与光效实验室')),
        const SliverToBoxAdapter(child: SoftMotionSection()),
        const SliverToBoxAdapter(child: SoftSmallTitle('列表')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SoftCard(
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < 12; i++) ...<Widget>[
                    if (i > 0) const SoftDivider(indent: 16, endIndent: 16),
                    SoftBasicComponent(
                      title: '标题 ${i + 1}',
                      summary: '摘要',
                      position: SoftCardListPosition.of(i, 12),
                      onTap: () {},
                      end: <Widget>[
                        Text(
                          '末尾',
                          style: theme.textStyles.body2.copyWith(
                            color: theme.colors.onSurfaceVariantActions,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: SoftFloatingNavigationBarDefaults.extent(context) + 16,
          ),
        ),
      ],
    );
  }
}

/// A wallpaper the bars sit on, so the frosting has something to show.
class _Wallpaper extends StatelessWidget {
  const _Wallpaper({this.backdrop, required this.child});

  final LayerBackdrop? backdrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.asset(
      'assets/wallpaper_light.webp',
      fit: BoxFit.cover,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: SoftSquircleBorder.all(17)),
        child: SizedBox(
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (backdrop != null)
                BackdropLayer(backdrop: backdrop!, child: image)
              else
                image,
              Align(alignment: Alignment.bottomCenter, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

const List<SoftFloatingNavigationItem> _threeItems =
    <SoftFloatingNavigationItem>[
      SoftFloatingNavigationItem(
        icon: SoftGlyphIcon(SoftGlyph.home),
        selectedIcon: SoftGlyphIcon(SoftGlyph.home),
        label: '首页',
      ),
      SoftFloatingNavigationItem(
        icon: Icon(Icons.chat_bubble_outline_rounded),
        selectedIcon: Icon(Icons.chat_bubble_rounded),
        label: '消息',
      ),
      SoftFloatingNavigationItem(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings_rounded),
        label: '设置',
      ),
    ];

class _PlainBarDemo extends StatefulWidget {
  const _PlainBarDemo();

  @override
  State<_PlainBarDemo> createState() => _PlainBarDemoState();
}

class _PlainBarDemoState extends State<_PlainBarDemo> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return _Wallpaper(
      child: SoftFloatingNavigationBar(
        includeBottomInset: false,
        selectedIndex: _selected,
        onSelected: (int i) => setState(() => _selected = i),
        items: <SoftFloatingNavigationItem>[
          ..._threeItems,
          const SoftFloatingNavigationItem(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

class _AccessoryBarDemo extends StatefulWidget {
  const _AccessoryBarDemo();

  @override
  State<_AccessoryBarDemo> createState() => _AccessoryBarDemoState();
}

class _AccessoryBarDemoState extends State<_AccessoryBarDemo> {
  final LayerBackdrop _backdrop = LayerBackdrop();
  int _selected = 0;
  bool _start = true;
  bool _end = true;

  @override
  void dispose() {
    _backdrop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return Column(
      children: <Widget>[
        _Wallpaper(
          backdrop: _backdrop,
          child: SoftFloatingNavigationBar(
            includeBottomInset: false,
            backdrop: _backdrop,
            quality: GlassQuality.liquid,
            selectedIndex: _selected,
            onSelected: (int i) => setState(() => _selected = i),
            start: SoftFloatingAccessory(
              icon: const SoftGlyphIcon(SoftGlyph.search),
              visible: _start,
              onTap: () {},
            ),
            end: SoftFloatingAccessory(
              icon: const Icon(Icons.add_rounded),
              visible: _end,
              onTap: () {},
            ),
            items: _threeItems,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SoftCard(
            child: Column(
              children: <Widget>[
                SoftBasicComponent(
                  title: '起始按钮',
                  position: SoftCardListPosition.head,
                  end: <Widget>[
                    LiquidToggle(
                      selected: _start,
                      onSelect: (bool v) => setState(() => _start = v),
                      backdrop: ColorBackdrop(theme.colors.surfaceContainer),
                    ),
                  ],
                ),
                const SoftDivider(indent: 16, endIndent: 16),
                SoftBasicComponent(
                  title: '末尾按钮',
                  position: SoftCardListPosition.tail,
                  end: <Widget>[
                    LiquidToggle(
                      selected: _end,
                      onSelect: (bool v) => setState(() => _end = v),
                      backdrop: ColorBackdrop(theme.colors.surfaceContainer),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The expansion melting out of the capsule on one tab, frosted by the
/// compositor: no [LayerBackdrop], no page capture.
class _ExpansionBarDemo extends StatefulWidget {
  const _ExpansionBarDemo();

  @override
  State<_ExpansionBarDemo> createState() => _ExpansionBarDemoState();
}

class _ExpansionBarDemoState extends State<_ExpansionBarDemo> {
  int _selected = 0;
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _Wallpaper(
          child: SoftFloatingNavigationBar(
            includeBottomInset: false,
            selectedIndex: _selected,
            onSelected: (int i) => setState(() => _selected = i),
            expansion: SoftFloatingAccessory(
              icon: const Icon(Icons.nfc_rounded),
              semanticLabel: '贴卡',
              visible: _selected == 1,
              onTap: () => setState(() => _taps++),
            ),
            items: <SoftFloatingNavigationItem>[
              ..._threeItems,
              const SoftFloatingNavigationItem(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: '我的',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text('切到「消息」时按钮从胶囊里融出 · 已点 $_taps 次'),
        ),
      ],
    );
  }
}

class _BadgeBarDemo extends StatefulWidget {
  const _BadgeBarDemo();

  @override
  State<_BadgeBarDemo> createState() => _BadgeBarDemoState();
}

class _BadgeBarDemoState extends State<_BadgeBarDemo> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return _Wallpaper(
      child: SoftFloatingNavigationBar(
        includeBottomInset: false,
        selectedIndex: _selected,
        onSelected: (int i) => setState(() => _selected = i),
        items: const <SoftFloatingNavigationItem>[
          SoftFloatingNavigationItem(
            icon: SoftGlyphIcon(SoftGlyph.home),
            selectedIcon: SoftGlyphIcon(SoftGlyph.home),
            label: '首页',
            badge: 0,
          ),
          SoftFloatingNavigationItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: '消息',
            badge: 8,
          ),
          SoftFloatingNavigationItem(
            icon: Icon(Icons.add_circle_rounded),
            label: '发布',
            largeIcon: true,
          ),
          SoftFloatingNavigationItem(
            icon: Icon(Icons.notifications_none_rounded),
            label: '通知',
            badge: 128,
          ),
          SoftFloatingNavigationItem(
            icon: Icon(Icons.person_outline_rounded),
            label: '我的',
            enabled: false,
          ),
        ],
      ),
    );
  }
}

class _PlainTab extends StatelessWidget {
  const _PlainTab({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        padding.top + 40,
        0,
        SoftFloatingNavigationBarDefaults.extent(context) + 16,
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
          child: Text(
            title,
            style: theme.textStyles.title1.copyWith(
              color: theme.colors.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        for (int g = 0; g < 4; g++) ...<Widget>[
          SoftSmallTitle('分组 ${g + 1}'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SoftCard(
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < 4; i++) ...<Widget>[
                    if (i > 0) const SoftDivider(indent: 16, endIndent: 16),
                    SoftBasicComponent(
                      title: '$title ${g * 4 + i + 1}',
                      position: SoftCardListPosition.of(i, 4),
                      onTap: () {},
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
