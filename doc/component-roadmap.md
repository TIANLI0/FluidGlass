# Where FluidGlass can become more useful

The project already has strong material, motion and selection primitives. Its
largest gap was composed product workflows: developers had to assemble input,
state, accessibility and feedback themselves. The command center and UI
essentials now cover complete search, form, selection and settings workflows.

| Priority | Opportunity | Useful scope |
| --- | --- | --- |
| Delivered | Command center | Search, groups, keyboard, touch, async feedback, recovery and modal presentation |
| Delivered | Form inputs | Labeled text/search, controller ownership, IME, descriptions, errors, validation/save/reset and debounce |
| Delivered | Settings sections | Shared glass group, information/navigation rows, labeled switches and sliders, units and lifecycle hooks |
| Delivered | Feedback surfaces | Four notice severities, native queued toast actions, cancellable progress and scroll-safe empty states |
| Delivered | Selection and filters | Mixed checkboxes, typed radio groups, choice/filter chips and searchable generic single-select with a Form variant |
| Next | Complex selection | Multi-select with Apply/Cancel, date/time/range fields and autocomplete; explicit state and validation contracts |
| Later | Adaptive navigation | Coordinated compact tabs and desktop rail/sidebar, with selection and route ownership kept explicit |

The goal is a coherent Flutter UI family with its own character. A few rules
should guide additions:

1. Use one glass surface for one semantic group. Readable information should
   not require a shader or become transparent just because glass is available.
2. Color, type, spacing and motion communicate hierarchy; avoid relying on
   larger blur, stronger shine or permanent animation to make a component feel
   special.
3. Keep controlled values, async ownership, keyboard behavior, pointer
   cancellation, localization and screen-reader semantics part of the API.
4. Make motion interruptible. Preserve input state through layout changes and
   treat reduced motion as a supported presentation.
5. Prefer shared paint-time movement and lazy content over per-frame widget
   construction. Verify work counts, then profile actual devices before making
   frame-rate claims.
6. Add composed components when they remove repeated application work. Avoid
   expanding the export list with decorative variations of existing controls.

The current iOS-like defaults remain compatible. New composed surfaces can
establish a quieter, more adaptable style without changing the shader math or
forcing existing consumers to adopt a new theme.
