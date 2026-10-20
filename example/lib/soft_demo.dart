import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

/// Every soft component on one scrolling page, in light and dark.
///
/// `flutter run -t lib/soft_demo.dart`
void main() => runApp(const SoftDemoApp());

class SoftDemoApp extends StatefulWidget {
  const SoftDemoApp({super.key});

  @override
  State<SoftDemoApp> createState() => _SoftDemoAppState();
}

class _SoftDemoAppState extends State<SoftDemoApp> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = _dark
        ? SoftThemeData.dark()
        : SoftThemeData.light();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Soft components',
      theme: ThemeData(
        brightness: theme.brightness,
        scaffoldBackgroundColor: theme.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.accent,
          brightness: theme.brightness,
        ),
      ),
      builder: (BuildContext context, Widget? child) =>
          SoftTheme(data: theme, child: child!),
      home: SoftDemoPage(
        dark: _dark,
        onToggleDark: () => setState(() => _dark = !_dark),
      ),
    );
  }
}

class SoftDemoPage extends StatefulWidget {
  const SoftDemoPage({
    super.key,
    required this.dark,
    required this.onToggleDark,
  });

  final bool dark;
  final VoidCallback onToggleDark;

  @override
  State<SoftDemoPage> createState() => _SoftDemoPageState();
}

enum _Plan { personal, team, studio }

class _SoftDemoPageState extends State<SoftDemoPage> {
  int _tab = 0;
  int _segment = 0;
  int _segment3 = 1;
  int _tabs = 0;
  double _slider = 0.4;
  double _stepped = 2;
  bool? _check1 = true;
  bool? _check2 = false;
  bool? _check3;
  _Plan _radio = _Plan.team;
  final Set<String> _chips = <String>{'Running'};
  final List<String> _tags = <String>['Sleep', 'Heart rate', 'Steps'];
  bool _wifi = true;
  bool _notify = false;
  _Plan _plan = _Plan.personal;
  bool _loading = false;
  bool _fabOpen = false;
  double _progress = 0.35;
  int _page = 0;
  String? _error;
  final SoftTooltipController _tooltip = SoftTooltipController();

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final double bottom =
        SoftNavigationBar.extent(context) +
        MediaQuery.viewPaddingOf(context).bottom +
        40;
    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: <Widget>[
          SoftLargeTitleScaffold(
            title: 'Soft components',
            actions: <Widget>[
              SoftBarAction(
                icon: Icon(
                  widget.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                onPressed: widget.onToggleDark,
              ),
            ],
            slivers: <Widget>[
              SliverPadding(
                padding: EdgeInsets.only(bottom: bottom),
                sliver: SliverList.list(children: _sections(theme)),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
              ),
              child: SoftNavigationBar(
                selectedIndex: _tab,
                onSelected: (int i) => setState(() => _tab = i),
                items: const <SoftNavigationItem>[
                  SoftNavigationItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_rounded,
                    label: 'Home',
                    badge: 3,
                  ),
                  SoftNavigationItem(
                    icon: Icons.devices_other_outlined,
                    selectedIcon: Icons.devices_other,
                    label: 'Devices',
                  ),
                  SoftNavigationItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'Me',
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: MediaQuery.viewPaddingOf(context).bottom + 12 + 56 + 24,
            child: SoftFab(
              icon: Icons.add_rounded,
              expanded: _fabOpen,
              onPressed: () => setState(() => _fabOpen = !_fabOpen),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sections(SoftThemeData theme) {
    Widget pad(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
    return <Widget>[
      DemoSection('Buttons', <Widget>[
        pad(
          SoftButton(
            label: 'Continue',
            expand: true,
            loading: _loading,
            onPressed: () async {
              setState(() => _loading = true);
              await Future<void>.delayed(const Duration(seconds: 2));
              if (mounted) setState(() => _loading = false);
            },
          ),
        ),
        const SizedBox(height: 12),
        pad(
          SoftButtonBar(
            children: <Widget>[
              SoftButton(
                label: 'Cancel',
                variant: SoftButtonVariant.secondary,
                onPressed: () {},
              ),
              SoftButton(label: 'Confirm', onPressed: () {}),
            ],
          ),
        ),
        const SizedBox(height: 12),
        pad(
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              SoftButton(
                label: 'Tonal',
                variant: SoftButtonVariant.tonal,
                onPressed: () {},
              ),
              SoftButton(
                label: 'Outline',
                variant: SoftButtonVariant.outline,
                onPressed: () {},
              ),
              const SoftButton(label: 'Disabled', onPressed: null),
              SoftButton(label: 'Small', small: true, onPressed: () {}),
              SoftButton(
                label: 'Small',
                small: true,
                variant: SoftButtonVariant.secondary,
                icon: Icons.add_rounded,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ]),
      DemoSection('Segmented control & tabs', <Widget>[
        pad(
          SoftSegmentedControl(
            segments: const <String>['Day', 'Week'],
            selectedIndex: _segment,
            onSelected: (int i) => setState(() => _segment = i),
          ),
        ),
        const SizedBox(height: 12),
        pad(
          SoftSegmentedControl(
            segments: const <String>['Steps', 'Calories', 'Distance'],
            selectedIndex: _segment3,
            small: true,
            onSelected: (int i) => setState(() => _segment3 = i),
          ),
        ),
        const SizedBox(height: 12),
        SoftTabBar(
          tabs: const <String>[
            'Overview',
            'Activity',
            'Sleep',
            'Heart',
            'Body',
            'Stress',
          ],
          selectedIndex: _tabs,
          onSelected: (int i) => setState(() => _tabs = i),
        ),
      ]),
      DemoSection('Slider', <Widget>[
        pad(
          SoftSlider(
            value: _slider,
            onChanged: (double v) => setState(() => _slider = v),
          ),
        ),
        pad(
          SoftSlider(
            value: _stepped,
            min: 0,
            max: 5,
            divisions: 5,
            onChanged: (double v) => setState(() => _stepped = v),
          ),
        ),
        pad(const SoftSlider(value: 0.6, onChanged: null)),
      ]),
      DemoSection('Selection', <Widget>[
        pad(
          Row(
            children: <Widget>[
              SoftCheckbox(
                value: _check1,
                onChanged: (bool? v) => setState(() => _check1 = v),
              ),
              const SizedBox(width: 16),
              SoftCheckbox(
                value: _check2,
                onChanged: (bool? v) => setState(() => _check2 = v),
              ),
              const SizedBox(width: 16),
              SoftCheckbox(
                value: _check3,
                tristate: true,
                onChanged: (bool? v) => setState(() => _check3 = v),
              ),
              const SizedBox(width: 16),
              const SoftCheckbox(value: true, onChanged: null),
              const SizedBox(width: 32),
              for (final _Plan p in _Plan.values) ...<Widget>[
                SoftRadio<_Plan>(
                  value: p,
                  groupValue: _radio,
                  onChanged: (_Plan v) => setState(() => _radio = v),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        pad(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String c in <String>[
                'Running',
                'Cycling',
                'Swimming',
                'Yoga',
              ])
                SoftChip(
                  label: c,
                  selected: _chips.contains(c),
                  onSelected: (bool on) =>
                      setState(() => on ? _chips.add(c) : _chips.remove(c)),
                ),
              for (final String t in _tags)
                SoftChip(
                  label: t,
                  small: true,
                  onDeleted: () => setState(() => _tags.remove(t)),
                ),
            ],
          ),
        ),
      ]),
      DemoSection('Lists', <Widget>[
        SoftListGroup(
          header: 'Connections',
          children: <Widget>[
            SoftListTile(
              icon: const Icon(Icons.wifi_rounded),
              title: 'Wi-Fi',
              trailing: LiquidToggle(
                selected: _wifi,
                onSelect: (bool v) => setState(() => _wifi = v),
                backdrop: ColorBackdrop(theme.card),
              ),
              onTap: () => setState(() => _wifi = !_wifi),
            ),
            SoftListTile(
              icon: const Icon(Icons.bluetooth_rounded),
              title: 'Bluetooth',
              value: 'Watch 4',
              chevron: true,
              onTap: () {},
            ),
            SoftListTile(
              icon: const Icon(Icons.notifications_none_rounded),
              title: 'Notifications',
              summary: 'Workout reminders and weekly reports',
              trailing: LiquidToggle(
                selected: _notify,
                onSelect: (bool v) => setState(() => _notify = v),
                backdrop: ColorBackdrop(theme.card),
              ),
              onTap: () => setState(() => _notify = !_notify),
            ),
          ],
        ),
        SoftListGroup(
          header: 'Account',
          children: <Widget>[
            SoftListTile(
              title: 'Plan',
              trailing: SoftSelect<_Plan>(
                value: _plan,
                options: const <(_Plan, String)>[
                  (_Plan.personal, 'Personal'),
                  (_Plan.team, 'Team'),
                  (_Plan.studio, 'Studio'),
                ],
                onChanged: (_Plan v) => setState(() => _plan = v),
              ),
            ),
            SoftListTile(title: 'Privacy', chevron: true, onTap: () {}),
            const SoftListTile(
              title: 'Disabled row',
              chevron: true,
              enabled: false,
            ),
          ],
        ),
      ]),
      DemoSection('Inputs', <Widget>[
        pad(
          SoftTextField(
            label: 'Nickname',
            hint: 'Nickname',
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ),
        pad(
          Align(
            alignment: Alignment.centerLeft,
            child: SoftButton(
              label: 'Show error',
              small: true,
              variant: SoftButtonVariant.secondary,
              onPressed: () => setState(() => _error = 'Already taken'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        pad(
          const SoftTextField(
            hint: 'Outlined',
            style: SoftTextFieldStyle.outlined,
          ),
        ),
        const SizedBox(height: 12),
        pad(
          const SoftTextField(
            hint: 'In a card',
            style: SoftTextFieldStyle.card,
          ),
        ),
        const SizedBox(height: 8),
        pad(const SoftSearchBar(hint: 'Search')),
      ]),
      DemoSection('Feedback', <Widget>[
        pad(
          Row(
            children: <Widget>[
              const SoftSpinner(),
              const SizedBox(width: 20),
              const SoftSpinner(large: true),
              const SizedBox(width: 20),
              SoftCircularProgress(value: _progress),
              const SizedBox(width: 12),
              SoftCircularProgress(
                value: _progress,
                medium: true,
                followAccent: true,
              ),
              const SizedBox(width: 20),
              Expanded(child: SoftLinearProgress(value: _progress)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        pad(
          Row(
            children: <Widget>[
              SoftButton(
                label: 'Progress',
                small: true,
                variant: SoftButtonVariant.secondary,
                onPressed: () => setState(
                  () => _progress = _progress >= 1
                      ? 0
                      : (_progress + 0.25).clamp(0, 1),
                ),
              ),
              const SizedBox(width: 24),
              const SoftBadge(
                count: 3,
                child: Icon(Icons.mail_outline_rounded, size: 24),
              ),
              const SizedBox(width: 24),
              const SoftBadge(
                count: 42,
                child: Icon(Icons.chat_bubble_outline_rounded, size: 24),
              ),
              const SizedBox(width: 24),
              const SoftBadge(
                count: 120,
                child: Icon(Icons.notifications_none_rounded, size: 24),
              ),
              const SizedBox(width: 24),
              const SoftBadge(
                count: -1,
                child: Icon(Icons.settings_outlined, size: 24),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => setState(() => _page = (_page + 1) % 5),
            child: SoftPageIndicator(count: 5, index: _page),
          ),
        ),
        const SizedBox(height: 16),
        pad(
          SoftTopTips(
            icon: Icon(
              Icons.info_outline_rounded,
              size: 24,
              color: theme.accentText,
            ),
            content: 'Wear your watch to bed to see sleep stages.',
            onClose: () {},
          ),
        ),
        const SizedBox(height: 12),
        pad(
          SoftTopTips(
            title: 'Battery saver is on',
            content:
                'Some background syncing is paused until the device is charging again.',
            actionLabel: 'Turn off',
            onAction: () {},
          ),
        ),
        const SizedBox(height: 12),
        pad(
          Row(
            children: <Widget>[
              SoftTooltip(
                message: 'Long-press a card to rearrange it',
                controller: _tooltip,
                child: SoftButton(
                  label: 'Tooltip',
                  small: true,
                  variant: SoftButtonVariant.secondary,
                  onPressed: _tooltip.show,
                ),
              ),
              const SizedBox(width: 12),
              SoftButton(
                label: 'Snackbar',
                small: true,
                variant: SoftButtonVariant.secondary,
                onPressed: () => showSoftSnackBar(
                  context,
                  message: 'Workout saved',
                  actionLabel: 'Undo',
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: SoftEmptyState(
            illustration: Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.labelTertiary,
            ),
            title: 'No records yet',
            subtitle: 'Records appear here after your first workout.',
            actionLabel: 'Start a workout',
            onAction: () {},
          ),
        ),
      ]),
      DemoSection('Overlays', <Widget>[
        pad(
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              SoftButton(
                label: 'Dialog',
                small: true,
                variant: SoftButtonVariant.secondary,
                onPressed: () => showSoftDialog<bool>(
                  context,
                  title: 'Delete this record?',
                  message: 'It will be removed from all your devices.',
                  actions: const <SoftDialogAction<bool>>[
                    SoftDialogAction<bool>(label: 'Cancel', value: false),
                    SoftDialogAction<bool>(
                      label: 'Delete',
                      value: true,
                      style: SoftDialogActionStyle.destructive,
                    ),
                  ],
                ),
              ),
              SoftButton(
                label: 'Recommended',
                small: true,
                variant: SoftButtonVariant.secondary,
                onPressed: () => showSoftDialog<bool>(
                  context,
                  title: 'Turn on sleep tracking?',
                  message:
                      'Your watch will record heart rate and movement through the night to estimate how long you spend in each stage of sleep.',
                  actions: const <SoftDialogAction<bool>>[
                    SoftDialogAction<bool>(label: 'Not now', value: false),
                    SoftDialogAction<bool>(
                      label: 'Turn on',
                      value: true,
                      style: SoftDialogActionStyle.recommended,
                    ),
                  ],
                ),
              ),
              SoftButton(
                label: 'Sheet',
                small: true,
                variant: SoftButtonVariant.secondary,
                onPressed: () => showSoftSheet<void>(
                  context,
                  title: 'Share report',
                  builder: (BuildContext context) => Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SoftListGroup(
                          children: <Widget>[
                            SoftListTile(
                              icon: const Icon(Icons.image_outlined),
                              title: 'Save as image',
                              onTap: () => closeSoftSheet(context),
                            ),
                            SoftListTile(
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              title: 'Export PDF',
                              onTap: () => closeSoftSheet(context),
                            ),
                            SoftListTile(
                              icon: const Icon(Icons.link_rounded),
                              title: 'Copy link',
                              onTap: () => closeSoftSheet(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SoftButton(
                            label: 'Done',
                            expand: true,
                            onPressed: () => closeSoftSheet(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Builder(
                builder: (BuildContext anchor) => SoftButton(
                  label: 'Menu',
                  small: true,
                  variant: SoftButtonVariant.secondary,
                  onPressed: () => showSoftMenu<String>(
                    anchor,
                    items: const <SoftMenuItem<String>>[
                      SoftMenuItem<String>(
                        label: 'Edit',
                        value: 'edit',
                        icon: Icons.edit_outlined,
                      ),
                      SoftMenuItem<String>(
                        label: 'Share',
                        value: 'share',
                        icon: Icons.share_outlined,
                      ),
                      SoftMenuItem<String>(
                        label: 'Pin to top',
                        value: 'pin',
                        icon: Icons.push_pin_outlined,
                      ),
                      SoftMenuItem<String>(
                        label: 'Delete',
                        value: 'delete',
                        icon: Icons.delete_outline_rounded,
                        destructive: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    ];
  }
}

/// A section heading in the demo.
class DemoSection extends StatelessWidget {
  const DemoSection(this.title, this.children, {super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              title,
              style: theme.text(
                14,
                weight: FontWeight.w500,
                color: theme.labelSecondary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
