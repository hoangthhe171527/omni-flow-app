# UI audit — omni-flow-app, September 2026

Audited against `ui-ux-pro-max/references/pro-rules.md` (native/mobile app rules
and its pre-delivery checklist). Task D1 of the task-assignment plan.

**This is a report. Nothing here is fixed.** One defect found during the audit
*was* fixed, because it was introduced by this same branch rather than being
existing behaviour: the two new screens read colours off the light palette
directly and would have rendered white cards in dark mode (commit "the new task
and notification screens were pinned to light mode").

## How this was checked, and what that does not cover

Everything below comes from reading the source of all 139 Dart files under
`lib/`, plus contrast ratios computed from the hex values in
`lib/design/tokens/omni_colors.dart`.

Nothing was observed running on a device. There is no emulator or physical
device available in this environment, so the checklist items that require one —
behaviour at 375px, landscape, Dynamic Type at the largest system size, reduced
motion actually engaged, and the composed appearance of a modal scrim over a
real background — are **unverified**, not passed. They are listed at the end.

Findings are ordered by what a person would actually hit, not by rule number.

---

## 1. Secondary text fails AA contrast — everywhere it is used

`mutedForeground` (#777889) is the app's secondary text colour, used at body and
caption size in **82 places**.

| Pair | Ratio | Needs |
|------|-------|-------|
| `mutedForeground` on `card` (#FFFFFF) | **4.35:1** | 4.5:1 |
| `mutedForeground` on `background` (#F8F8FC) | **4.10:1** | 4.5:1 |

It misses on white and misses further on the page ground, which is where most of
it sits. Dark mode is fine (`darkMutedForeground` on `darkCard` is 6.92:1), so
this is a light-mode-only failure — exactly the case the rules call out, where
one theme is checked and the other is assumed.

It is close enough that it will not read as broken; it will read as slightly
hard to see, in a workshop, in daylight, to people who are mostly over forty.
Darkening the token to about #6B6C7D clears 4.5:1 on both grounds and is a
one-line change, but it moves every secondary line in the app, so it belongs in
its own change with a look at the result — not bundled into a feature.

## 2. Semantic colours are used as text at sizes where they fail

`success`, `warning` and `destructive` are used as a text colour in **19
places** — the overdue chip, status labels, error lines.

| Pair | Ratio | Needs (normal text) |
|------|-------|---------------------|
| `warning` #F59E0B on white | **2.15:1** | 4.5:1 |
| `success` #10B981 on white | **2.54:1** | 4.5:1 |
| `destructive` #EF4444 on white | **3.76:1** | 4.5:1 |

These are good *fill* colours and poor *text* colours; that is normal for this
family of palettes. They pass the 3:1 non-text threshold, so an icon or a bar in
these colours is fine — a sentence is not.

Mitigating: nothing in the app depends on these colours alone. The overdue chip
says "Quá hạn 3 ngày" in words, the due chip says "Hạn hôm nay". Somebody who
cannot resolve the colour still gets the fact. That is why this is second and
not first.

The fix is a darker text-weight variant per semantic colour (`successText`,
`warningText`, `destructiveText`), keeping the current values for fills and
icons.

## 3. Three icon-only controls announce nothing

| File | Control |
|------|---------|
| `lib/modules/auth/presentation/login_page.dart:140` | password visibility toggle |
| `lib/app/shell/more_page.dart:383` | password visibility toggle |
| `lib/design/components/omni_inputs.dart:66` | clear-search button |

`IconButton` with no `tooltip` and no `Semantics` label. TalkBack and VoiceOver
announce the icon's name or nothing at all. The password toggles are the worse
two: they are on the login screen, and they also fail to announce their state
(shown/hidden), so a screen-reader user cannot tell whether their password is
currently visible on screen.

The other 16 `IconButton`s in the app do carry tooltips.

## 4. Filter pills are a 34dp touch target

`OmniFilterPill` (`lib/design/components/omni_pills.dart:47`) is
`EdgeInsets.symmetric(horizontal: 14, vertical: 7)` around a label — roughly
34dp tall. The floor is 44pt on iOS and 48dp on Android.

Used on 5 screens including the bucket bar on "Việc của tôi", so this is the
control a worker taps first, with gloves on. It is also the one place a
too-small target is most likely to be hit: the pills sit in a horizontal row
where a miss lands on the neighbouring filter rather than on nothing.

Raising the vertical padding to 12 gives 44dp and costs nothing else.

## 5. No reduced-motion support at all

No reference to `MediaQuery.disableAnimations` or `accessibleNavigation`
anywhere in `lib/`. Every animation runs regardless of the OS setting.

This matters less here than in a marketing app — the motion in this app is short
transitions and a progress bar, not parallax — but "respect the setting" is a
one-line guard at the few animation sites, and someone who turns that setting on
usually has a reason.

## 6. Animation durations are ad-hoc

Twelve distinct durations across the app: 80, 140, 150, 160, 180, 220 (×4), 240,
280, 350, 500 (×2), 1100, 2500 ms. There is no duration token in
`lib/design/tokens/` — the spacing, radius, colour and type scales all have one,
so this is the gap in an otherwise complete token set.

220ms is clearly the de facto standard. Three tiers (fast ~140, base ~220, slow
~350) named in the token file would let the odd ones out be either justified or
corrected.

## 7. Nothing adapts to a tablet or to landscape

`LayoutBuilder` appears once in the whole app — the 900px navigation rail in
`lib/app/shell/app_shell.dart:57`. Below that width there is no adaptation at
all: the same 16dp gutter on a 375px phone and a 768px tablet, and long-form
text (task descriptions, message bodies) runs edge to edge on a wide screen.

Against the rules this is two items — adaptive gutters by breakpoint, and
readable text measure on large devices. Whether it is worth fixing depends on
whether anyone uses a tablet, which is a question for the team rather than a
defect on its own.

## 8. Minor: spacing values off the 4dp grid

In `lib/design/components/` there are hardcoded 2, 3, 5, 6, 7 and 14dp values
alongside the `OmniSpacing` scale. Small, mostly inside single components where
they do optical rather than structural work (a 2dp badge inset, a 3dp progress
inset). Worth noting because the token scale is otherwise followed closely, so
each of these is a deliberate-looking exception that may not have been
deliberate.

## 9. Minor: icon sizes are not tokenised

Fourteen distinct icon sizes: 13, 14, 15, 16, 17, 18, 20, 22, 23, 40, 42, 48,
52, 56. The rules ask for an `icon-sm/md/lg` token set. 16/18/20 carry most of
the usage and the outliers (13, 15, 17, 23) look incidental rather than chosen.

Icon *style* is consistent, which is the harder half: 133 `_rounded` and 51
`_outlined`, and spot-checking shows outlined used for inactive/secondary and
rounded for active/primary — a real hierarchy rather than a mix.

---

## What passes

Worth recording, because these are the things that usually fail:

- **No emoji used as icons.** Every icon is a Material vector.
- **Touch targets in the new task screens** are deliberate: the subtask row is
  56dp with the whole row as the target, action-bar buttons are 52dp, and there
  is a widget test holding the line (`test/tasks/subtask_row_test.dart`).
- **Colour is never the only signal.** Overdue, due-today, unread and failed
  states all carry words or a shape as well as a colour.
- **Safe areas** are handled in the 9 files that place fixed UI, including the
  new bottom action bar.
- **Dark mode is real** and driven by `ColorScheme` throughout, with a full dark
  token set — not a filter over the light theme.
- **Text scaling** is supported and clamped to 0.9–1.3× (`omni_app.dart:98`)
  rather than ignored. The clamp is a deliberate trade: past ~1.3× the inbox row
  breaks apart. It does mean the app does not honour the largest system sizes,
  which is a real limitation and an accepted one.
- **Haptics** on the actions that need confirming without looking.
- **Pressed feedback** is `InkWell`/`Material` throughout — no layout-shifting
  press transforms.

## Not verified

These need a device and are not claimed either way:

- Behaviour at 375px width, and in landscape
- Dynamic Type at the largest system size (the clamp means the app caps out at
  1.3×, but whether every screen survives even that was not observed)
- Reduced motion actually engaged
- Modal/drawer scrim legibility against a real background
- Screen-reader focus *order* — labels were read from source, traversal was not
- Keyboard/focus behaviour with a hardware keyboard attached

## Suggested order

1. §3 icon labels — three lines, no visual change, and it is the login screen.
2. §4 filter pill height — one line, fixes the most-tapped control.
3. §1 secondary text contrast — one token, but it moves every screen, so it
   wants its own change and a look.
4. §2 semantic text colours — new tokens, then migrate the 19 sites.
5. §6 duration tokens — cheap, and prevents the list growing to twenty.
6. §5, §7, §8, §9 — worth doing, none urgent.
