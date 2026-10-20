import 'dart:async';

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

enum _WorkspaceKind { personal, studio, organization }

enum _Delivery { immediate, daily }

const _workspaceKinds = <LiquidSelectOption<_WorkspaceKind>>[
  LiquidSelectOption(
    value: _WorkspaceKind.personal,
    label: 'Personal space',
    description: 'A little room for your own ideas',
    icon: Icons.person_outline_rounded,
  ),
  LiquidSelectOption(
    value: _WorkspaceKind.studio,
    label: 'Creative studio',
    description: 'Bring a few good minds together',
    icon: Icons.workspaces_outline,
  ),
  LiquidSelectOption(
    value: _WorkspaceKind.organization,
    label: 'Organization',
    description: 'Coming soon to this preview',
    icon: Icons.apartment_rounded,
    enabled: false,
  ),
];

const _projects =
    <({String title, String category, String detail, bool pinned})>[
      (
        title: 'Blue hour',
        category: 'Design',
        detail: 'A study in light and motion',
        pinned: true,
      ),
      (
        title: 'Small discoveries',
        category: 'Notes',
        detail: 'Good things worth keeping',
        pinned: false,
      ),
      (
        title: 'A quieter interface',
        category: 'Design',
        detail: 'Less noise. A little more clarity.',
        pinned: false,
      ),
    ];

/// A working composition of the public form, selection and feedback components.
/// All edits belong to this page's lifetime; no account or network is involved.
class ComponentKitContent extends StatefulWidget {
  const ComponentKitContent({super.key, this.initialDark = false});

  final bool initialDark;

  @override
  State<ComponentKitContent> createState() => _ComponentKitContentState();
}

class _ComponentKitContentState extends State<ComponentKitContent> {
  final _form = GlobalKey<FormState>();
  final _search = TextEditingController();
  Timer? _saveTimer;
  late bool _dark = widget.initialDark;
  bool _notifications = true;
  bool _weekly = false;
  bool _pinned = false;
  bool _dirty = false;
  bool _saving = false;
  bool _saved = false;
  double _progress = 0;
  double _volume = 0.6;
  String _name = 'Fluid studio';
  String _query = '';
  String _category = 'All';
  String? _validationMessage;
  _Delivery _delivery = _Delivery.daily;

  @override
  void dispose() {
    _saveTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _edit(VoidCallback change) {
    setState(() {
      change();
      _dirty = true;
      _saved = false;
      _validationMessage = null;
    });
  }

  void _reset() {
    _form.currentState?.reset();
    setState(() {
      _notifications = true;
      _weekly = false;
      _volume = 0.6;
      _delivery = _Delivery.daily;
      _name = 'Fluid studio';
      _dirty = false;
      _saved = false;
      _validationMessage = null;
    });
  }

  void _cancelSave() {
    _saveTimer?.cancel();
    setState(() => _saving = false);
  }

  void _save(BuildContext context) {
    if (_saving) return;
    if (!_form.currentState!.validate()) {
      setState(() => _validationMessage = 'Give your workspace a name first.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _form.currentState!.save();
    setState(() {
      _saving = true;
      _saved = false;
      _progress = 0;
      _validationMessage = null;
    });
    // A cancellable local preview of an asynchronous save, not a remote request.
    _saveTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _progress = timer.tick / 10);
      if (timer.tick < 10) return;
      timer.cancel();
      setState(() {
        _saving = false;
        _dirty = false;
        _saved = true;
      });
      showLiquidToast(
        context: context,
        title: 'Changes saved',
        message: '$_name is ready for this session.',
        severity: LiquidNoticeSeverity.success,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = _dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
    final ink = _dark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final outerTheme = Theme.of(context);
    final theme = ThemeData(
      brightness: _dark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: accent,
      fontFamily: outerTheme.textTheme.bodyMedium?.fontFamily,
      fontFamilyFallback: outerTheme.textTheme.bodyMedium?.fontFamilyFallback,
      splashFactory: LiquidInkHighlight.splashFactory,
    );
    return AnimatedTheme(
      data: theme,
      duration: still ? Duration.zero : const Duration(milliseconds: 240),
      child: LiquidGlassTheme(
        colors: LiquidGlassColors.forBrightness(theme.brightness).copyWith(
          accent: accent,
          toggleAccent: accent,
          content: ink,
          glow: const Color(0xFFD8EAFF),
        ),
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: Colors.transparent,
            body: AnimatedContainer(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _dark
                      ? const [
                          Color(0xFF101B2E),
                          Color(0xFF14171F),
                          Color(0xFF1B2639),
                        ]
                      : const [
                          Color(0xFFF7F9FD),
                          Color(0xFFEDF3FF),
                          Color(0xFFE7EEFA),
                        ],
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    return SingleChildScrollView(
                      key: const PageStorageKey('component-kit-scroll'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        wide ? 56 : 20,
                        76,
                        wide ? 56 : 20,
                        40,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.blur_on_rounded,
                                    color: accent,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'fluid / essentials',
                                      style: TextStyle(
                                        color: ink,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Switch appearance',
                                    onPressed: () =>
                                        setState(() => _dark = !_dark),
                                    icon: Icon(
                                      _dark
                                          ? Icons.light_mode_outlined
                                          : Icons.dark_mode_outlined,
                                      color: ink,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Your workspace,\nyour way.',
                                style: TextStyle(
                                  color: ink,
                                  fontSize: wide ? 48 : 36,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -1.8,
                                  height: 1.12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'A calm place to create. Make the little things feel right.',
                                style: TextStyle(
                                  color: ink.withValues(alpha: 0.65),
                                  fontSize: 15,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 36),
                              Form(
                                key: _form,
                                child: wide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: _workspace(context)),
                                          const SizedBox(width: 32),
                                          Expanded(
                                            child: _preferences(context),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          _workspace(context),
                                          const SizedBox(height: 28),
                                          _preferences(context),
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 24),
                              if (still)
                                _statusNotice()
                              else
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  child: _statusNotice(),
                                ),
                              // Fixed slot keeps the action row in place throughout save/cancel.
                              LiquidProgress(
                                value: _saving ? _progress : 1,
                                label: _saving
                                    ? 'Saving your preview'
                                    : _dirty
                                    ? 'You have unsaved changes'
                                    : 'Ready when you are',
                                description:
                                    'Try every control. Changes stay in this preview only.',
                                showPercentage: _saving,
                                onCancel: _saving ? _cancelSave : null,
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  LiquidButton(
                                    backdrop: emptyBackdrop,
                                    tint: accent,
                                    onPressed: _saving
                                        ? null
                                        : () => _save(context),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                      child: Text(
                                        'Save changes',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _saving ? null : _reset,
                                    child: const Text('Reset defaults'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 42),
                              Divider(color: ink.withValues(alpha: 0.1)),
                              const SizedBox(height: 28),
                              _library(context),
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
    );
  }

  Widget _statusNotice() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_validationMessage != null)
        LiquidNotice(
          title: 'One small thing',
          message: _validationMessage,
          severity: LiquidNoticeSeverity.warning,
        ),
      if (_saved)
        LiquidNotice(
          title: 'Everything is in place',
          message: 'Your choices are saved for this preview.',
          severity: LiquidNoticeSeverity.success,
          onDismiss: () => setState(() => _saved = false),
        ),
      if (_validationMessage != null || _saved) const SizedBox(height: 16),
    ],
  );

  Widget _workspace(BuildContext context) => LiquidSettingsSection(
    title: '01  Workspace',
    description: 'A name, a purpose, a space of your own.',
    showDividers: false,
    padding: const EdgeInsets.all(20),
    children: [
      LiquidTextField(
        key: const ValueKey('workspace-name'),
        initialValue: 'Fluid studio',
        label: 'Workspace name',
        hintText: 'Give your ideas a home',
        leading: const Icon(Icons.edit_outlined, size: 20),
        enabled: !_saving,
        textInputAction: TextInputAction.next,
        validator: (value) => value == null || value.trim().isEmpty
            ? 'A workspace name is required.'
            : null,
        onChanged: (_) => _edit(() {}),
        onSaved: (value) => _name = value!.trim(),
      ),
      const SizedBox(height: 16),
      LiquidSelectFormField<_WorkspaceKind>(
        options: _workspaceKinds,
        initialValue: _WorkspaceKind.personal,
        label: 'Space type',
        enabled: !_saving,
        onChanged: (_) => _edit(() {}),
        helperText: 'Choose what fits. You can always change it.',
      ),
      const SizedBox(height: 14),
      LiquidCheckbox(
        label: 'A little weekly inspiration',
        helperText: 'Fresh ideas, at your pace.',
        value: _weekly,
        onChanged: _saving ? null : (value) => _edit(() => _weekly = value!),
      ),
      const Divider(height: 28),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          'Delivery rhythm',
          style: TextStyle(
            color: LiquidGlassTheme.of(context).content,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(height: 4),
      LiquidRadioGroup<_Delivery>(
        label: 'Delivery rhythm',
        options: const [
          LiquidSelectOption(
            value: _Delivery.immediate,
            label: 'As things happen',
            description: 'For the moments that matter now',
          ),
          LiquidSelectOption(
            value: _Delivery.daily,
            label: 'One daily summary',
            description: 'Everything together, once a day',
          ),
        ],
        value: _delivery,
        onChanged: _saving ? null : (value) => _edit(() => _delivery = value!),
      ),
    ],
  );

  Widget _preferences(BuildContext context) => LiquidSettingsSection(
    title: '02  Make yourself comfortable',
    description: 'Thoughtful defaults. Room to make them yours.',
    footer: const Padding(
      padding: EdgeInsets.only(top: 8),
      child: LiquidNotice(
        title: 'A quieter kind of workspace',
        message: 'Your settings should be easy to find and easy to change.',
        liveRegion: false,
      ),
    ),
    children: [
      LiquidSwitchTile(
        title: 'Stay in the loop',
        subtitle: 'Allow workspace notifications',
        value: _notifications,
        onChanged: _saving
            ? null
            : (value) => _edit(() => _notifications = value),
      ),
      LiquidSliderTile(
        title: 'Sound level',
        subtitle: 'A gentle nudge, or a little more presence.',
        value: _volume,
        divisions: 10,
        onChanged: _saving ? null : (value) => _edit(() => _volume = value),
      ),
      const LiquidSettingsTile(
        title: 'Storage',
        subtitle: 'Available for this preview session',
        leading: Icon(Icons.shield_outlined),
      ),
      LiquidSettingsTile(
        title: 'About this space',
        subtitle: 'Made for focus, built around you',
        leading: const Icon(Icons.info_outline_rounded),
        onTap: () => showLiquidToast(
          context: context,
          message: 'A local, interactive preview. No account needed.',
        ),
      ),
    ],
  );

  Widget _library(BuildContext context) {
    final colors = LiquidGlassTheme.of(context);
    final results = _projects
        .where(
          (project) =>
              (_category == 'All' || project.category == _category) &&
              (!_pinned || project.pinned) &&
              '${project.title} ${project.detail}'.toLowerCase().contains(
                _query.trim().toLowerCase(),
              ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'A few things in progress',
          style: TextStyle(
            color: colors.content,
            fontSize: 23,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Find an idea. Pick up where you left off.',
          style: TextStyle(
            color: colors.content.withValues(alpha: 0.65),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        LiquidSearchField(
          controller: _search,
          hintText: 'Search your projects',
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final category in ['All', 'Design', 'Notes'])
              LiquidChoiceChip(
                label: category,
                selected: _category == category,
                onSelected: (_) => setState(() => _category = category),
              ),
            LiquidFilterChip(
              label: 'Pinned only',
              avatar: const Icon(Icons.push_pin_outlined, size: 16),
              selected: _pinned,
              onSelected: (value) => setState(() => _pinned = value),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (results.isEmpty)
          LiquidEmptyState(
            icon: Icons.search_rounded,
            title: 'Room for another idea',
            message:
                'No projects match these filters. Try a different word or start fresh.',
            actionLabel: 'Clear filters',
            onAction: () {
              _search.clear();
              setState(() {
                _query = '';
                _category = 'All';
                _pinned = false;
              });
            },
          )
        else
          LiquidSettingsSection(
            children: [
              for (final project in results)
                LiquidSettingsTile(
                  title: project.title,
                  subtitle: project.detail,
                  leading: Icon(
                    project.category == 'Design'
                        ? Icons.auto_awesome_mosaic_outlined
                        : Icons.notes_rounded,
                    color: colors.accent,
                  ),
                  trailing: project.pinned
                      ? Icon(
                          Icons.push_pin_rounded,
                          size: 18,
                          color: colors.accent,
                        )
                      : null,
                  onTap: () => showLiquidToast(
                    context: context,
                    title: project.title,
                    message: 'Selected in this preview.',
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
