import Foundation

/// Layer 2 of the colour system: the roles.
///
/// **This is the only colour vocabulary the app is allowed to speak.** A screen
/// asks for "the page", "the ink on an action button", "the boundary of a
/// control". It never asks for "the sixth warm grey". Naming by role rather than
/// by appearance is what makes a colour decision changeable in one place, and it
/// is what makes the accessibility measurements below meaningful — a measurement
/// is about a *pairing* (this ink on that ground), and only roles say which
/// pairings are intended.
///
/// **Every role is defined for both light and dark, and the compiler proves it.**
/// A role that exists in one appearance and not the other is a bug: it means
/// somebody's screen is unreadable at night. Rather than hoping two separate
/// light and dark tables stay in step, this type resolves both at once through a
/// single `switch` over every case (see `pair`). Swift requires a `switch` over
/// an enum to handle every case, so adding a role without giving it *both* an
/// light and a dark value does not compile. That is the enforcement; the comment
/// is only the explanation.
///
/// **How to read the contrast numbers.** WCAG states contrast as a ratio between
/// 1:1 (invisible) and 21:1 (black on white). The floors that apply here:
/// - **4.5:1** — normal-size text (WCAG 1.4.3, level AA).
/// - **3:1** — the boundary or fill that tells you a control *is* a control
///   (WCAG 1.4.11).
/// Numbers written below were measured by the design system's own audit tool and
/// re-checked against these exact values. Where a pairing sits under a floor it
/// says so, and says which written exemption applies. Nothing is under a floor by
/// accident.
///
/// **If you are writing a contrast test, read this first.** "Every ink on every
/// ground" is *not* the rule, because not every combination is one this design
/// system intends to draw. Two groups of pairings are deliberately exempt and
/// will fail a blanket assertion:
///
/// 1. **Anything on `surfaceInset` in light.** That ground exists only under a
///    disabled control, which WCAG 1.4.3 exempts. `textSubtle` measures 4.13:1
///    there, and the coloured inks — `action`, `warningText`, `dangerText`,
///    `focus` — land between 4.28:1 and 4.47:1.
/// 2. **`border`.** It is decorative and measures 1.09–1.66:1 by design. Only
///    `borderStrong` is held to the 3:1 floor, and it clears it on every ground
///    in both appearances (lowest measured: 3.12:1).
///
/// Every other ink-on-ground pairing clears its floor in both appearances.
///
/// `Sendable` means these values are safe to read from any concurrent piece of
/// work; that is free here, because a role is just a name and the colours behind
/// it never change at runtime.
enum ColorRole: String, CaseIterable, Sendable {
  // MARK: Surfaces

  /// The page itself. Everything else in the app sits on top of this.
  ///
  /// Warm off-white rather than pure white, near-black slate rather than pure
  /// black. The screen should read as paper and ink, not as an empty browser.
  case surfacePrimary

  /// A raised block sitting on the page — a card, or a sheet slid up from the
  /// bottom. In dark this is *lighter* than the page, because a dark interface
  /// signals height by lifting a surface towards the light rather than by
  /// casting a shadow downwards.
  case surfaceRaised

  /// A recess: an inert or inactive control, pressed into the page.
  ///
  /// In dark this is *darker* than the page, which is the mirror image of the
  /// rule above and is correct for the same reason — if raising means lighter,
  /// then sinking has to mean darker.
  ///
  /// **This ground means "switched off", and that constrains what may sit on
  /// it.** In light it is a distinctly darker warm grey than the page, and every
  /// *coloured* ink in this file lands between 4.28:1 and 4.47:1 on it —
  /// just under the 4.5:1 text floor. That is not a defect, because the only
  /// thing ever drawn on this ground is a disabled control, which WCAG 1.4.3
  /// exempts. But it does mean the pairing is only legal while the control is
  /// disabled. Putting `action`, `warningText`, `dangerText`, `focus` or
  /// `textSubtle` on an *enabled* inset ground is a bug.
  ///
  /// Grey ink is fine here: `textPrimary` measures 12.09:1 light / 14.41:1 dark
  /// and `textMuted` 5.43:1 / 7.97:1, both comfortably over the floor.
  case surfaceInset

  // MARK: Text

  /// Body and heading ink. 14.10:1 light, 13.54:1 dark against the page — far
  /// past the 4.5:1 floor, which is what you want for the text someone actually
  /// reads.
  case textPrimary

  /// Supporting ink: captions, secondary lines, anything that should be present
  /// but not competing. 6.34:1 light, 7.49:1 dark against the page.
  case textMuted

  /// The quietest ink: placeholder text, and the label on a control that is
  /// switched off. 4.81:1 light, 5.14:1 dark against the page.
  ///
  /// **Known exemption.** On `surfaceInset` in light this measures **4.13:1**,
  /// below the 4.5:1 floor. That is deliberate and legal: the pairing occurs only
  /// inside a control that is *disabled*, and WCAG 1.4.3 explicitly exempts
  /// inactive components. It is exactly the pairing on this app's Start button.
  /// In dark the same pairing measures 5.47:1 and passes outright.
  ///
  /// It is the *grey* inks that stay safe everywhere else: on the page and on a
  /// raised card this role measures 4.81 / 5.25 light and 5.14 / 4.61 dark, all
  /// over the floor. See `surfaceInset` for the full list of inks that dip under
  /// it on that one ground, and why that is expected rather than wrong.
  ///
  /// Consequence for anyone writing a screen: using this ink on an *enabled*
  /// inset ground is a bug, not a style choice.
  case textSubtle

  // MARK: Borders

  /// **Decorative only** — dividers, and edges that are pleasant rather than
  /// necessary. It measures 1.27:1 light and 1.56:1 dark, i.e. it is nearly
  /// invisible, and that is intended: WCAG 1.4.11 governs the visual information
  /// needed to *identify* a control, not every line drawn on a screen.
  ///
  /// Drawing the boundary of an interactive control with this is a defect. Use
  /// `borderStrong`. A contrast test that asserts 3:1 across all border roles
  /// must exclude this one.
  case border

  /// **Functional** — the boundary that tells you something is a control. Held
  /// to the 3:1 floor on every ground in both appearances: 3.64 / 3.97 / 3.12 in
  /// light and 4.17 / 3.74 / 4.44 in dark, against the page, a raised card and a
  /// recess respectively.
  ///
  /// Both appearances use the same value, and that is not a copy-paste mistake.
  /// The palette originally gave dark its own slightly different grey, whose
  /// 3.2:1 had been measured against the page alone; on a raised card it dropped
  /// to 2.86:1, so any control inside a card was non-compliant. It was lifted to
  /// the value light already used, and the old one was deleted from the palette.
  /// Do not "restore" a separate dark value.
  case borderStrong

  // MARK: Action
  //
  // Brand sage is `Palette.sage500`. It measures 4.33:1 against the page — under
  // the 4.5:1 text floor — so the action role takes one step deeper in light.
  // See the doc comment on `Palette.sage500`. Do not "correct" `action` back to
  // the brand hex; it fails as text.

  /// The colour of something you can do. 5.01:1 light, 5.80:1 dark against the
  /// page, and 5.46:1 / 5.20:1 against a raised card — passing as text, which
  /// matters because this role is used for text labels as well as for fills.
  ///
  /// The one ground it does not clear is `surfaceInset` in light (4.29:1), which
  /// is a disabled control and therefore exempt; see `surfaceInset`.
  case action

  /// The pointer-hover step, transcribed from the source system for
  /// completeness of the ramp.
  ///
  /// **It has no consumer on iPhone and is not expected to gain one.** A finger
  /// does not hover; a touch either has not happened or is a press, and a press
  /// is `actionActive`. The role is carried so that this Swift table and the
  /// design system's SCSS table stay line-for-line comparable — a future diff
  /// between the two systems would otherwise be misleading. If you are styling a
  /// control, you want `action` or `actionActive`.
  case actionHover

  /// The touch-down step: what an action control looks like while a finger is on
  /// it. `onAction` measures 8.44:1 light and 8.73:1 dark against it.
  ///
  /// On the web this step is called `:active`, and `:active` genuinely *is* the
  /// pointer-down state — so mapping "pressed" onto it is a faithful
  /// translation rather than a compromise.
  case actionActive

  /// Ink drawn *on top of* an action fill.
  ///
  /// Accents invert between appearances: in light a deep green fill carries pale
  /// ink; in dark a pale green fill carries dark ink. That inversion is the whole
  /// reason this is a role at all. Never assume the ink on a coloured button is
  /// white — half the time it must not be.
  case onAction

  /// A pale action-toned **background tint**, not an ink. It measures 1.11:1 in
  /// light and is completely invisible as text.
  ///
  /// Use it as a ground and put `textPrimary` on top (12.67:1 light, 10.82:1
  /// dark). This role changed meaning in the source system's second version and
  /// kept its name, which makes it the one most likely to be misused; this
  /// comment is the only warning that exists.
  case actionSubtle

  // MARK: Warning

  /// A **fill** weight of amber. Never amber text on a pale ground — the light
  /// weight measures 3.07:1 there and the dark weight 2.23:1, against a text
  /// floor of 4.5:1. Legible as a shape, not as words. For text, use
  /// `warningText`. (The same two figures are recorded on the amber ramp in
  /// `Palette`; they are stated in both places because this is the role a
  /// screen actually reaches for.)
  ///
  /// The design system's discipline is that amber marks exactly one thing per
  /// screen; a visible warning state counts as that one thing.
  case warning

  /// Ink on an amber fill. 4.59:1 in light — over the floor with 0.09 to spare,
  /// which means amber cannot be deepened any further without breaking this
  /// pairing.
  case onWarning

  /// The text weight of amber. 5.22:1 light, 7.79:1 dark against the page.
  case warningText

  /// A **fill** weight of red. 4.99:1 light, 5.00:1 dark against the page.
  ///
  /// The light red is 2.3:1 on a dark ground and fails there outright, which is
  /// why danger *lightens* in dark rather than staying put.
  case danger

  /// Ink on a red fill.
  case onDanger

  /// Danger **as text**. In light this is the same value as `danger`; in dark it
  /// deliberately breaks that alias and takes one step lighter.
  ///
  /// The reason is worth keeping: dark's `danger` measures 5.00:1 against the
  /// page but only 4.49:1 against a raised card — over the floor by a hundredth
  /// in one place and under it in another — and error text sits inside a card far
  /// more often than bare on the page. The lighter step measures 5.90:1 on the
  /// page and 5.29:1 on a card, and is not a new colour: it is the step dark
  /// already uses for the pressed weight.
  case dangerText

  // MARK: Focus

  /// The ring drawn around whatever the keyboard is currently on.
  ///
  /// Focus is sage, drawn as a ring held slightly off the control. The *offset*
  /// is what keeps it visible even on a sage fill, which is why focus needs no
  /// hue of its own and why it is measured against the *surfaces* rather than
  /// against `action` — those two colours never actually touch. It is the same
  /// value as `action` and measures the same: 5.01 / 5.46 light and 5.80 / 5.20
  /// dark on the page and on a raised card.
  ///
  /// iOS draws its own focus ring for hardware-keyboard and Full Keyboard Access
  /// navigation. Use this role only where a custom ring is drawn by hand.
  case focus

  // MARK: Internal

  /// The colour to use when the device is in light appearance.
  var light: RGBColor {
    pair.light
  }

  /// The colour to use when the device is in dark appearance.
  var dark: RGBColor {
    pair.dark
  }

  // MARK: Private

  /// Both appearances of a role, resolved together.
  ///
  /// This is the enforcement mechanism described in the type's documentation.
  /// Because it is one `switch` over every case returning a *pair*, Swift will
  /// not compile a new role that is missing either half. Two separate light and
  /// dark tables would compile happily while silently drifting apart.
  private var pair: (light: RGBColor, dark: RGBColor) {
    switch self {
    case .surfacePrimary: (light: Palette.stone50, dark: Palette.slate900)
    case .surfaceRaised: (light: Palette.stone0, dark: Palette.slate800)
    case .surfaceInset: (light: Palette.stone200, dark: Palette.slate950)

    case .textPrimary: (light: Palette.slate850, dark: Palette.stone150)
    case .textMuted: (light: Palette.stone800, dark: Palette.stone400)
    case .textSubtle: (light: Palette.stone700, dark: Palette.stone500)

    case .border: (light: Palette.stone300, dark: Palette.slate600)
    case .borderStrong: (light: Palette.stone600, dark: Palette.stone600)

    case .action: (light: Palette.sage600, dark: Palette.sage400)
    case .actionHover: (light: Palette.sage700, dark: Palette.sage300)
    case .actionActive: (light: Palette.sage800, dark: Palette.sage200)
    case .onAction: (light: Palette.stone50, dark: Palette.slate900)
    case .actionSubtle: (light: Palette.sage50, dark: Palette.sage900)

    case .warning: (light: Palette.amber500, dark: Palette.amber400)
    case .onWarning: (light: Palette.slate850, dark: Palette.slate900)
    case .warningText: (light: Palette.amber700, dark: Palette.amber300)

    case .danger: (light: Palette.red600, dark: Palette.red500)
    case .onDanger: (light: Palette.stone0, dark: Palette.slate900)
    case .dangerText: (light: Palette.red600, dark: Palette.red400)

    case .focus: (light: Palette.sage600, dark: Palette.sage400)
    }
  }
}
