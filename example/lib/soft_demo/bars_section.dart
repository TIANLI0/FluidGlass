import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

/// The top app bars and tabs of the soft family, laid out like the
/// reference gallery: a collapsing large-title page, the small bar over a
/// wallpaper in its glass forms, the tab rows and a card of chip tab groups.
class SoftDemoBarsSection extends StatefulWidget {
  const SoftDemoBarsSection({super.key});

  @override
  State<SoftDemoBarsSection> createState() => _SoftDemoBarsSectionState();
}

class _SoftDemoBarsSectionState extends State<SoftDemoBarsSection> {
  static const List<String> _frameless = <String>['日', '周', '月'];
  static const List<String> _segments = <String>['全部', '允许', '拒绝'];
  static const List<String> _tiny = <String>['照片', '视频', '人像', '全景'];

  final ScrollController _glassScroll = ScrollController();
  final ScrollController _gradientScroll = ScrollController();
  final PageController _pages = PageController();

  int _framelessSelected = 0;
  int _segmentSelected = 0;
  int _tinySelected = 0;
  int _chipSelected = 0;
  int _iconChipSelected = 0;
  int _dotChipSelected = 0;

  @override
  void dispose() {
    _glassScroll.dispose();
    _gradientScroll.dispose();
    _pages.dispose();
    super.dispose();
  }

  Widget _back() => SoftTopAppBarIconButton(
    icon: const SoftBackIcon(),
    semanticLabel: '返回',
    onPressed: () {},
  );

  Widget _more() => SoftTopAppBarIconButton(
    icon: const SoftMoreIcon(),
    semanticLabel: '更多',
    onPressed: () {},
  );

  Widget _rows(int count, {double top = 0, ScrollController? controller}) {
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.only(top: top),
      itemCount: count,
      itemBuilder: (BuildContext context, int index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text('滚动行 $index'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SoftSmallTitle('顶部应用栏'),
        _Frame(
          height: 320,
          child: ColoredBox(
            color: theme.colors.surface,
            child: CustomScrollView(
              slivers: <Widget>[
                SoftLargeTopAppBar(
                  title: '设置',
                  navigationIcon: _back(),
                  actions: <Widget>[_more()],
                ),
                SliverList.builder(
                  itemCount: 30,
                  itemBuilder: (BuildContext context, int index) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text('滚动行 $index'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SoftSmallTitle('顶部应用栏 · 玻璃'),
        _Frame(
          height: 260,
          child: Stack(
            children: <Widget>[
              const Positioned.fill(child: _Wallpaper()),
              Positioned.fill(
                child: _rows(
                  12,
                  top: SoftTopAppBarDefaults.collapsedHeight + 24,
                  controller: _glassScroll,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SoftTopAppBar(
                  title: '顶部应用栏',
                  subtitle: '玻璃',
                  blur: true,
                  scrollController: _glassScroll,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Frame(
          height: 280,
          child: Stack(
            children: <Widget>[
              const Positioned.fill(child: _Wallpaper()),
              Positioned.fill(
                child: _rows(
                  12,
                  top: 3 * SoftTopAppBarDefaults.collapsedHeight,
                  controller: _gradientScroll,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Column(
                  children: <Widget>[
                    SoftTopAppBar(
                      title: '居中标题',
                      centerTitle: true,
                      blur: true,
                      navigationIcon: _back(),
                      actions: <Widget>[_more()],
                    ),
                    SoftTopAppBar(
                      title: '分段',
                      blur: true,
                      actions: <Widget>[_more()],
                    ),
                    SoftTopAppBar(
                      title: '渐变玻璃',
                      gradientGlass: true,
                      blur: true,
                      scrollController: _gradientScroll,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SoftSmallTitle('标签栏'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SoftTabRow(
            tabs: _frameless,
            selectedIndex: _framelessSelected,
            onTabSelected: (int i) => setState(() => _framelessSelected = i),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SoftTabRow.contour(
                  tabs: _segments,
                  selectedIndex: _segmentSelected,
                  onTabSelected: (int i) {
                    setState(() => _segmentSelected = i);
                    _pages.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 300),
                      curve: SoftMotion.inEase,
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 16),
                  child: SizedBox(
                    height: 24,
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: _segments.length,
                      onPageChanged: (int i) =>
                          setState(() => _segmentSelected = i),
                      itemBuilder: (BuildContext context, int page) =>
                          Text('内容：${_segments[page]}'),
                    ),
                  ),
                ),
                SoftTabRow.contour(
                  tabs: _tiny,
                  selectedIndex: _tinySelected,
                  onTabSelected: (int i) => setState(() => _tinySelected = i),
                  height: SoftTabRowDefaults.tinyHeight,
                  cornerRadius: SoftTabRowDefaults.tinyCornerRadius,
                  contourPadding: SoftTabRowDefaults.tinyContourPadding,
                ),
              ],
            ),
          ),
        ),
        const SoftSmallTitle('标签页'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SoftChipTabGroup(
                    tabs: const <SoftChipTabData>[
                      SoftChipTabData(label: '全部'),
                      SoftChipTabData(label: '照片'),
                      SoftChipTabData(label: '视频'),
                      SoftChipTabData(label: '文档'),
                    ],
                    selectedIndex: _chipSelected,
                    onSelectedChange: (int i) =>
                        setState(() => _chipSelected = i),
                  ),
                ),
                const SoftDivider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SoftChipTabGroup(
                    tabs: const <SoftChipTabData>[
                      SoftChipTabData(label: '全部', icon: Icon(Icons.apps)),
                      SoftChipTabData(
                        label: '照片',
                        icon: Icon(Icons.photo_outlined),
                      ),
                      SoftChipTabData(
                        label: '音乐',
                        icon: Icon(Icons.music_note_outlined),
                      ),
                      SoftChipTabData(
                        label: '文件',
                        icon: Icon(Icons.insert_drive_file_outlined),
                      ),
                    ],
                    selectedIndex: _iconChipSelected,
                    onSelectedChange: (int i) =>
                        setState(() => _iconChipSelected = i),
                  ),
                ),
                const SoftDivider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SoftChipTabGroup(
                    tabs: const <SoftChipTabData>[
                      SoftChipTabData(label: '收件箱', showRedDot: true),
                      SoftChipTabData(label: '更新', count: 12),
                      SoftChipTabData(
                        label: '已归档',
                        count: 128,
                        showRedDot: true,
                      ),
                      SoftChipTabData(label: '不可用', enabled: false),
                      SoftChipTabData(label: '垃圾信息'),
                    ],
                    selectedIndex: _dotChipSelected,
                    onSelectedChange: (int i) =>
                        setState(() => _dotChipSelected = i),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A fixed-height page frame inset like a card, with the status bar
/// removed so the bars sit at its top.
class _Frame extends StatelessWidget {
  const _Frame({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool smooth = SoftTheme.of(context).smoothCorners;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: height,
        child: ClipPath(
          clipper: ShapeBorderClipper(
            shape: SoftSquircleBorder.all(
              SoftCardDefaults.cornerRadius,
              smooth: smooth,
            ),
          ),
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeLeft: true,
            removeRight: true,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A colourful stand-in for a wallpaper, for the glass to blur.
class _Wallpaper extends StatelessWidget {
  const _Wallpaper();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF5B8DEF),
            Color(0xFFE57CB5),
            Color(0xFFF6C26B),
            Color(0xFF59C3A6),
          ],
        ),
      ),
    );
  }
}
