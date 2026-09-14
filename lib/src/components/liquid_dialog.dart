import 'package:flutter/material.dart';

import '../../fluid_glass.dart';

/// One action in a [LiquidDialog].
@immutable
class LiquidDialogAction {
  const LiquidDialogAction({
    required this.label,
    this.isPrimary = false,
    this.isDestructive = false,
    this.onPressed,
  });

  final String label;

  /// Fills the action with the theme's accent — the one thing the dialog is
  /// asking for. At most one action should carry it.
  final bool isPrimary;

  /// Tints the action red, for one that removes something. Combined with
  /// [isPrimary] it fills with red instead of the accent.
  final bool isDestructive;

  /// What the action does — **including dismissing the dialog**.
  ///
  /// Unlike [LiquidSheet], this widget never pops for you. A sheet is a
  /// chooser, so every row ends it; a dialog's actions do not all end it — one
  /// may open a policy the reader wants to consult *before* choosing, and
  /// several return different values to the same caller. Deciding that here
  /// would be deciding it wrong for those.
  final VoidCallback? onPressed;
}

/// How a dialog lays its actions out.
enum LiquidDialogActionsAxis {
  /// One row, each action an equal share of the width.
  horizontal,

  /// One per line, full width, in the order given.
  vertical,

  /// [horizontal] for up to two actions, [vertical] beyond that.
  ///
  /// Three equal columns is where labels start breaking mid-word — and a
  /// dialog's labels are verbs the reader has to be able to tell apart.
  automatic,
}

/// A centred modal panel of liquid glass: a title, a message, and the actions
/// that answer it.
///
/// This is the shape a question with a small, fixed set of answers belongs in.
/// For a choice out of a list use [LiquidSheet]; for one attached to an anchor
/// use [LiquidMenu].
///
/// Two things are the caller's, as everywhere in this package:
///
/// - **The [backdrop]** — a glass widget cannot invent what it refracts.
///   [showLiquidDialog] defaults it to [nativeBackdrop], which is almost always
///   right here: the dialog sits *over* what it filters, so the compositor can
///   do it with no capture at all, and the modal barrier's dim is included for
///   free. The trade is that there is then no texture to bend, so the element
///   is pinned to [GlassQuality.plain] — blur and tint, no refraction.
///   **To get the refraction, pass a [LayerBackdrop] whose captured subtree
///   already contains the dim**; a capture taken without it makes the dialog
///   read as a lit window floating over a darkened page, and the dim cannot be
///   added afterwards because the glass samples the capture, not the screen.
/// - **Getting it on screen.** [showLiquidDialog] wires the modal route for
///   you; use this widget directly for a dialog that is not a route.
///
/// The actions never dismiss on their own — see [LiquidDialogAction.onPressed].
class LiquidDialog extends StatelessWidget {
  const LiquidDialog({
    super.key,
    required this.backdrop,
    this.title,
    this.message,
    this.child,
    this.actions = const <LiquidDialogAction>[],
    this.actionsAxis = LiquidDialogActionsAxis.automatic,
    this.surfaceColor,
    this.cornerRadius = 48,
    this.scrollable = false,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 40,
      vertical: 24,
    ),
    this.maxWidth = 560,
  });

  /// What the glass refracts.
  final Backdrop backdrop;

  final String? title;

  /// The body text. Ignored when [child] is given.
  final String? message;

  /// Free-form content instead of [message] — a text field, an image, a list of
  /// checkboxes.
  ///
  /// Not wrapped in a scroll view of its own; set [scrollable] if it needs one,
  /// and do not nest a second scrollable inside it.
  final Widget? child;

  final List<LiquidDialogAction> actions;

  final LiquidDialogActionsAxis actionsAxis;

  /// The tint over the refracted backdrop. Defaults to the theme's `container`.
  ///
  /// A dialog wants a heavier tint than a bar does: it carries whole sentences,
  /// and their contrast is otherwise decided by whatever the dialog happens to
  /// be over. Pass an opaque colour to drop the glass entirely — which is what
  /// an app should do under high-contrast settings, or when it could not
  /// capture a backdrop.
  final Color? surfaceColor;

  final double cornerRadius;

  /// Scrolls the body when it is taller than the room available, keeping the
  /// title and the actions where they are.
  ///
  /// A long disclosure otherwise pushes the actions off screen — and the
  /// actions are the part the reader has to reach.
  final bool scrollable;

  /// The gap kept between the panel and the screen's edges.
  final EdgeInsets insetPadding;

  /// The panel stops widening here, so the message keeps a readable measure on
  /// a tablet instead of running the full width of the screen.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final LiquidGlassColors colors = LiquidGlassTheme.of(context);

    Widget? body;
    if (child != null) {
      body = child;
    } else if (message case final String text) {
      body = Text(
        text,
        style: TextStyle(
          color: colors.content.withValues(alpha: 0.68),
          fontSize: 15,
          height: 1.45,
        ),
      );
    }
    if (body != null) {
      body = Padding(
        padding: EdgeInsets.fromLTRB(28, title == null ? 24 : 12, 28, 12),
        child: body,
      );
      if (scrollable) body = SingleChildScrollView(child: body);
    }

    return Padding(
      // The keyboard is added to the inset, as the framework's own dialog does:
      // a dialog with a field in it otherwise sits under the keyboard it just
      // raised.
      padding: MediaQuery.viewInsetsOf(context) + insetPadding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: LiquidPanel(
            backdrop: backdrop,
            surfaceColor: surfaceColor ?? colors.container,
            shape: RoundedRectangle(cornerRadius),
            // A dialog is large and looked at straight on, so the thicker
            // reading of the rim is legible here in a way it is not on a bar.
            blurRadius: 16,
            refractionHeight: 24,
            refractionAmount: 48,
            depthEffect: true,
            child: ClipPath(
              // The body scrolls, and a panel's tint is drawn, not clipped —
              // without this the text rides out over the rounded corners.
              clipper: GlassShapeClipper(RoundedRectangle(cornerRadius)),
              // Transparent, so the panel stays the only surface — but present,
              // because [child] is free-form and the material widgets that show
              // up in one (a field, a checkbox, a list tile) assert without a
              // Material ancestor. The framework's own dialog does the same.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (title case final String heading)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
                        child: Text(
                          heading,
                          style: TextStyle(
                            color: colors.content,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (body != null) Flexible(child: body),
                    if (actions.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          title == null && body == null ? 24 : 12,
                          24,
                          24,
                        ),
                        child: _Actions(
                          actions: actions,
                          axis: actionsAxis,
                          colors: colors,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.actions,
    required this.axis,
    required this.colors,
  });

  final List<LiquidDialogAction> actions;
  final LiquidDialogActionsAxis axis;
  final LiquidGlassColors colors;

  @override
  Widget build(BuildContext context) {
    final bool horizontal = switch (axis) {
      LiquidDialogActionsAxis.horizontal => true,
      LiquidDialogActionsAxis.vertical => false,
      LiquidDialogActionsAxis.automatic => actions.length <= 2,
    };

    final List<Widget> buttons = <Widget>[
      for (final LiquidDialogAction action in actions)
        _ActionButton(action: action, colors: colors),
    ];

    if (!horizontal) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        // In the order given — the caller decides which answer sits nearest the
        // thumb, because which one that should be depends on what is being
        // asked (an affirmative at the bottom, a destructive one further up).
        children: buttons,
      );
    }
    return Row(
      spacing: 16,
      children: <Widget>[
        for (final Widget button in buttons) Expanded(child: button),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.colors});

  final LiquidDialogAction action;
  final LiquidGlassColors colors;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color label;
    if (action.isPrimary) {
      fill = action.isDestructive ? colors.destructive : colors.accent;
      label = const Color(0xFFFFFFFF);
    } else {
      fill = colors.content.withValues(alpha: 0.08);
      label = action.isDestructive ? colors.destructive : colors.content;
    }

    // Material's ink, not a LiquidButton: an action sits *on* the panel, and a
    // second piece of glass on top of the first covers the very refraction it
    // would be there to show (the same reason the panel's own primary action is
    // a solid fill). The press feedback is the ink and the fill, not a lens.
    return ClipPath(
      clipper: const GlassShapeClipper(Capsule()),
      child: Material(
        color: fill,
        child: InkWell(
          onTap: action.onPressed,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: label,
                    fontSize: 16,
                    fontWeight: action.isPrimary
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a [LiquidDialog] as a modal route.
///
/// The framework's own dialog surface is made transparent so the panel is the
/// only one, and [barrierColor] is the dim the panel's [nativeBackdrop] filter
/// sits above. When passing a [LayerBackdrop] instead, that dim has to be
/// inside the captured subtree — see [LiquidDialog].
Future<T?> showLiquidDialog<T>({
  required BuildContext context,
  Backdrop backdrop = nativeBackdrop,
  String? title,
  String? message,
  Widget? child,
  List<LiquidDialogAction> actions = const <LiquidDialogAction>[],
  LiquidDialogActionsAxis actionsAxis = LiquidDialogActionsAxis.automatic,
  Color? barrierColor,
  Color? surfaceColor,
  bool barrierDismissible = true,
  double cornerRadius = 48,
  bool scrollable = false,
  bool useRootNavigator = true,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    builder: (BuildContext dialogContext) => LiquidDialog(
      backdrop: backdrop,
      title: title,
      message: message,
      actions: actions,
      actionsAxis: actionsAxis,
      surfaceColor: surfaceColor,
      cornerRadius: cornerRadius,
      scrollable: scrollable,
      child: child,
    ),
  );
}
