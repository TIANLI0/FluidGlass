// Layout/content from coui17 example component sections, Apache-2.0.
import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';
import 'app_components_page.dart';

/// Uses the repository's demo inputs, layout and vectors for inspection.
class SoftReferencePage extends StatefulWidget {
  const SoftReferencePage({super.key});
  @override
  State<SoftReferencePage> createState() => _SoftReferencePageState();
}

class _SoftReferencePageState extends State<SoftReferencePage> {
  final LayerBackdrop _wallpaper = LayerBackdrop();
  int _hour = 16, _minute = 30;
  DateTime _date = DateTime(2026, 7, 26);
  bool _revealed = false, _deleted = false, _settings = false;
  @override
  void dispose() {
    _wallpaper.dispose();
    super.dispose();
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: SizedBox(
      height: 32,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(text, style: SoftTheme.of(context).textStyles.headline2),
        ),
      ),
    ),
  );
  Widget _card(Widget child) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 3.5, 16, 16),
    child: SoftCard(child: child),
  );
  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return ColoredBox(
      color: theme.colors.surface,
      child: SoftPullToRefresh(
        pullLabel: '下拉刷新',
        releaseLabel: '松手刷新',
        refreshingLabel: '正在刷新',
        completeLabel: '刷新完成',
        onRefresh: () =>
            Future<void>.delayed(const Duration(milliseconds: 1000)),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 16,
            bottom: SoftFloatingNavigationBarDefaults.extent(context) + 24,
          ),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text('参照', style: theme.textStyles.title3)),
                  SoftTextButton(
                    text: '应用接入示例',
                    onPressed: () => Navigator.of(context).push<void>(
                      PageRouteBuilder<void>(
                        pageBuilder: (_, _, _) => ColoredBox(
                          color: theme.colors.surface,
                          child: const SoftAppComponentsPage(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _title('数字选择器'),
            _card(
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: SoftNumberPicker(
                        value: _hour,
                        min: 0,
                        max: 23,
                        wrapAround: true,
                        label: (value) => '$value'.padLeft(2, '0'),
                        onChanged: (value) => setState(() => _hour = value),
                      ),
                    ),
                    const Text(
                      ':',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: SoftNumberPicker(
                        value: _minute,
                        min: 0,
                        max: 59,
                        wrapAround: true,
                        label: (value) => '$value'.padLeft(2, '0'),
                        onChanged: (value) => setState(() => _minute = value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _title('日期选择器'),
            _card(
              SoftDatePicker(
                value: _date,
                onChanged: (value) => setState(() => _date = value),
              ),
            ),
            _title('通知侧滑'),
            const SizedBox(height: 3.5),
            Stack(
              children: <Widget>[
                Positioned.fill(
                  child: BackdropLayer(
                    backdrop: _wallpaper,
                    child: Image.asset(
                      'assets/wallpaper_light.webp',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('向左滑动以显示通知操作'),
                      const SizedBox(height: 16),
                      if (!_deleted)
                        SoftNotificationSwipeBox(
                          minHeight: 0,
                          backdrop: _wallpaper,
                          revealed: _revealed,
                          onRevealedChanged: (value) =>
                              setState(() => _revealed = value),
                          onSettings: () => setState(() => _settings = true),
                          onDismiss: () => setState(() => _deleted = true),
                          settingsLabel: '设置',
                          dismissLabel: '删除',
                          settingsIcon: const SoftGlyphIcon(SoftGlyph.settings),
                          dismissIcon: const SoftGlyphIcon(SoftGlyph.delete),
                          child: SizedBox(
                            height: 60,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: <Widget>[
                                  const SoftGlyphIcon(
                                    SoftGlyph.email,
                                    size: 36,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          '新消息',
                                          style: theme.textStyles.body2,
                                        ),
                                        Text(
                                          '缓慢拖动，观察融合连接逐渐分离',
                                          style: theme.textStyles.footnote2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (_deleted) const Text('通知已删除'),
                      if (_settings) const Text('已选择通知设置'),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          SoftTextButton(
                            text: '展开操作',
                            onPressed: _deleted
                                ? null
                                : () => setState(() => _revealed = true),
                          ),
                          const SizedBox(width: 12),
                          SoftTextButton(
                            text: '重置',
                            onPressed: () => setState(() {
                              _revealed = false;
                              _deleted = false;
                              _settings = false;
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _title('通知消息条'),
            _card(
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    SoftNotificationSnackBar(
                      title: '新消息',
                      message: '方形图片，44dp',
                      image: const SoftGlyphIcon(SoftGlyph.email),
                      actionLabel: '打开',
                      onAction: () {},
                      onClose: () {},
                    ),
                    const SizedBox(height: 12),
                    SoftNotificationSnackBar(
                      title: '正在播放',
                      message: '竖版图片，36dp x 48dp',
                      image: const SoftGlyphIcon(SoftGlyph.photos),
                      imageType: SoftNotificationImageType.vertical,
                      actionLabel: '暂停',
                      onAction: () {},
                      onClose: () {},
                    ),
                    const SizedBox(height: 12),
                    SoftNotificationSnackBar(
                      title: '闹钟已设置',
                      message: '横版图片，58dp x 44dp',
                      image: const SoftGlyphIcon(SoftGlyph.worldClock),
                      imageType: SoftNotificationImageType.horizontal,
                      onClose: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
