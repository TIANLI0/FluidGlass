import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

/// [LiquidNavigationBar] over a feed that scrolls underneath it.
///
/// The chrome is three floating islands of glass, not a bar, and the islands
/// are *siblings* of the scrolling content — glass cannot refract something it
/// is inside of. Three things are worth watching, and the controls at the
/// bottom drive each one:
///
/// * **The content keeps scrolling between the islands.** That is what islands
///   buy over a bar: only what carries text has to be covered.
/// * **The scrim is what keeps the gaps legible.** Take it to zero and the
///   page colour ends on a hard line under the chrome; at 48 the content walks
///   out from under it with no edge at all.
/// * **Only the islands take input.** The scrim ignores it, so a row still
///   half under the chrome takes the tap — the readout says which row you hit.
class NavigationBarContent extends StatefulWidget {
  const NavigationBarContent({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<NavigationBarContent> createState() => _NavigationBarContentState();
}

class _NavigationBarContentState extends State<NavigationBarContent> {
  final LayerBackdrop _backdrop = LayerBackdrop();

  // Start a little scrolled, so a row is already under the chrome and there is
  // something to refract before anyone touches anything.
  final ScrollController _scroll = ScrollController(initialScrollOffset: 120);

  static const List<double> _fades = <double>[0, 24, 48];

  int _fadeIndex = 1;
  bool _avatar = true;
  bool _longTitle = false;
  String _lastTap = 'nothing yet';

  @override
  void dispose() {
    _scroll.dispose();
    _backdrop.dispose();
    super.dispose();
  }

  double get _fade => _fades[_fadeIndex];

  @override
  Widget build(BuildContext context) {
    final EdgeInsets viewPadding = MediaQuery.paddingOf(context);
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor = isLight
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);

    final LiquidNavigationBar bar = LiquidNavigationBar(
      backdrop: _backdrop,
      fadeHeight: _fade,
      titleLeading: _avatar
          ? const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF0088FF),
              child: Text(
                'M',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      title: Text(_longTitle ? 'Mika, and the long-name case' : 'Mika'),
      onTitlePressed: () => setState(() => _lastTap = 'the title island'),
      leading: LiquidNavigationAction(
        backdrop: _backdrop,
        icon: Icons.arrow_back_ios_new,
        label: 'Back',
        iconSize: 18,
        onPressed: widget.onBack ?? () => Navigator.maybePop(context),
      ),
      trailing: LiquidMenu(
        backdrop: _backdrop,
        alignment: Alignment.topRight,
        items: const <LiquidMenuItem>[
          LiquidMenuItem(label: 'All activity', isSelected: true),
          LiquidMenuItem(label: 'Mentions', icon: Icons.alternate_email),
          LiquidMenuItem(label: 'Unread', icon: Icons.mark_email_unread),
        ],
        anchorBuilder: (BuildContext context, bool open, VoidCallback toggle) =>
            LiquidNavigationAction(
              backdrop: _backdrop,
              icon: Icons.tune,
              label: 'Filter',
              onPressed: toggle,
            ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // What the islands refract: the whole feed. Half-resolution capture,
        // because they blur what they sample anyway — the `appChrome` screen
        // measures what that is worth.
        Positioned.fill(
          child: BackdropLayer(
            backdrop: _backdrop,
            pixelRatio: 0.5,
            child: ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.only(
                top: viewPadding.top + bar.preferredSize.height,
                bottom: viewPadding.bottom + 200,
              ),
              itemCount: 40,
              itemBuilder: (BuildContext context, int index) => _FeedRow(
                index: index,
                onTap: () => setState(() => _lastTap = 'row ${index + 1}'),
              ),
            ),
          ),
        ),

        Positioned(top: 0, left: 0, right: 0, child: bar),

        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16 + viewPadding.bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _Controls(
                backdrop: _backdrop,
                contentColor: contentColor,
                fadeIndex: _fadeIndex,
                onFadeIndex: (int index) => setState(() => _fadeIndex = index),
                avatar: _avatar,
                onAvatar: (bool value) => setState(() => _avatar = value),
                longTitle: _longTitle,
                onLongTitle: (bool value) => setState(() => _longTitle = value),
                lastTap: _lastTap,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.backdrop,
    required this.contentColor,
    required this.fadeIndex,
    required this.onFadeIndex,
    required this.avatar,
    required this.onAvatar,
    required this.longTitle,
    required this.onLongTitle,
    required this.lastTap,
  });

  final Backdrop backdrop;
  final Color contentColor;
  final int fadeIndex;
  final ValueChanged<int> onFadeIndex;
  final bool avatar;
  final ValueChanged<bool> onAvatar;
  final bool longTitle;
  final ValueChanged<bool> onLongTitle;
  final String lastTap;

  Widget _caption(String text) => Text(
    text,
    style: TextStyle(
      color: contentColor.withValues(alpha: 0.55),
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _segment(String text) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(color: contentColor, fontSize: 13),
  );

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      spacing: 12,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: contentColor, fontSize: 13),
          ),
        ),
        LiquidToggle(selected: value, onSelect: onChanged, backdrop: backdrop),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiquidPanel(
      backdrop: backdrop,
      shape: const RoundedRectangle(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: <Widget>[
            _caption('scrim fade below the islands'),
            LiquidSegmentedControl(
              selectedIndex: fadeIndex,
              onSelected: onFadeIndex,
              backdrop: backdrop,
              segments: <Widget>[
                _segment('none'),
                _segment('24'),
                _segment('48'),
              ],
            ),
            _switchRow('Avatar in the island', avatar, onAvatar),
            _switchRow('Long title — ellipsised', longTitle, onLongTitle),
            Text(
              'last tap: $lastTap',
              style: TextStyle(
                color: contentColor.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A feed row of small type and hairlines, which is what makes a blur read as
/// a blur — a smooth gradient blurred is very nearly itself.
class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.index, required this.onTap});

  final int index;
  final VoidCallback onTap;

  static const List<Color> _accents = <Color>[
    Color(0xFF0088FF),
    Color(0xFFE5484D),
    Color(0xFF00A972),
    Color(0xFF8E5BFF),
    Color(0xFFF2A100),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color ink = isLight
        ? const Color(0xFF101010)
        : const Color(0xFFF2F2F2);
    final Color accent = _accents[index % _accents.length];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF101014),
        border: Border(
          bottom: BorderSide(color: ink.withValues(alpha: 0.10), width: 0.5),
        ),
      ),
      child: LiquidInteraction(
        borderRadius: BorderRadius.zero,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: <Color>[accent, accent.withValues(alpha: 0.55)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: <Widget>[
                      Text(
                        'Row ${index + 1} — scroll me under the chrome',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Tap a row that is still half under the scrim: only '
                        'the islands take input, so the row takes the tap.',
                        maxLines: 2,
                        style: TextStyle(
                          color: ink.withValues(alpha: 0.62),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          spacing: 3,
                          children: <Widget>[
                            for (int i = 0; i < 26; i++)
                              Container(
                                width: 1,
                                height: 9,
                                color: ink.withValues(alpha: 0.30),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
