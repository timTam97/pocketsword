# About notices

Implemented on 5 October 2026 for the SimpleScripture About page.

`Classes/SwiftUIAboutView.swift` provides the About page, credits index and
offline, selectable notice reader. `Resources/Notices` is copied into the app
as a folder. The existing `Resources/doc/LICENSE.txt` remains the GPLv2 source.
The notices apply to the currently bundled components, not every historical
PocketSword dependency.

## Provenance

| Notice | Source |
| --- | --- |
| `Application.txt` | Retained source copyright headers, the original About contributor list in `en.lproj/Localizable.strings`, and the fork's repository identity. All names in the original contributor list are preserved verbatim. |
| `KJV.txt` | `Resources/KJV.zip`, `mods.d/kjv.conf`, version 2.9. |
| `MHCC.txt` | `Resources/MHCC.zip`, `mods.d/mhcc.conf`, version 1.1. |
| `StrongsRealGreek.txt` | `Resources/strongsrealgreek.zip`, `mods.d/strongsrealgreek.conf`, version 1.5-150704. |
| `StrongsRealHebrew.txt` | `Resources/strongsrealhebrew.zip`, `mods.d/strongsrealhebrew.conf`, version 1.090107. |
| `Robinson.txt` | `Resources/Robinson.zip`, `mods.d/robinson.conf`, version 2.0. Includes CrossWire's 2002/2009 credit, the original distribution notice and a new format-conversion notice. |
| `GentiumPlus.txt` | Name records 0, 7, 9 and 13 in the shipped `GentiumPlus-R.ttf` version 1.510. Includes the complete OFL 1.1 and reserved names. |
| `EzraSIL.txt` | Name records 0, 9 and 13 in the shipped `SILEOT.ttf` version 2.51. Includes both the complete OFL 1.1 and the MIT/X11 notice for Hebrew layout intelligence. |
| `CC-BY-SA-3.0.txt` | Complete official English legal code retrieved from `https://creativecommons.org/licenses/by-sa/3.0/legalcode.txt` on 5 October 2026. SHA-256: `3f941b3b89cf7b8370ceb83cc76d2120d471b58735d8ca60238a751a48d7f72f`. |

All module archives above were read directly from Git revision
`3b94aad8853ea4caf06d421755a2ae58a71d7af4`. Every module version was checked
against the current `PSContent.sqlite`. The original `About`,
`DistributionLicense`, `DistributionNotes` (when present) and `TextSource`
wording is preserved. RTF paragraph/alignment markers and whitespace are
normalized for plain-text display. Historical contact addresses are labeled
as historical. Added explanatory paragraphs are outside the original notices.
The reader reflows fixed-column GPL and CC license paragraphs to the display
width; the bundled license files remain unchanged.

The two complete font licenses were checked against the embedded name records,
ignoring only whitespace. Exact font SHA-256 values:

- Gentium Plus: `262cd4cbbcc7ce593122ad4ff81e8ab2b85fb97ea61ab56afb9393422dec1581`.
- Ezra SIL: `53c98ab95d2b5bd615527cdd05da42d7dd77f2690b79c043e9f90753d4930dce`.

The About icon is a copy of the approved
`docs/rebranding/simplescripture-heritage.png`, stored in the
`SimpleScriptureAbout` image set. The historical artwork contributors remain
credited without attributing the new icon to them.

## Source and support

The project and feedback links use the public fork at
`https://github.com/timTam97/pocketsword`. Its public visibility and enabled
issue tracker were verified with GitHub on 5 October 2026. The issue link
opens a draft containing app/build and OS versions; the app does not submit it.
The original Bitbucket project remains identified in the upstream notice.

The project link identifies development source. Before distributing a binary,
prepare and verify the complete corresponding source for that exact release.
An About-page link to the repository does not perform that release step.

## Verification

- Xcode MCP `PocketSword` build-for-testing succeeded on iOS 27.
- Three focused tests passed, zero skips: fork feedback URL, bundled notice
  coverage and module versions, and Settings → About → credits → GPL navigation.
  The final UI test also follows Robinson's full CC license link and opens the
  Ezra MIT/X11 notice. It preserves six screenshots in its test result bundle.
- Every added notice in the built simulator app matched its source file byte
  for byte. No `CompileC` tasks ran.
- iPhone 18 Pro Max portrait screenshots were visually reviewed; further
  runtime layout boundaries are recorded in the rebranding README.

## Remaining release work

This implements attribution and license access, not release clearance.
The [licensing assessment](README.md) still tracks App Store/GPL distribution,
UK KJV permissions, inherited artwork provenance, exact release source, and
reuse/access arrangements for the CC BY-SA module data. No release, remote
publication, source offer or permission grant was created by this change.
Code2000 is already removed from the current app; historical distribution
questions remain outside this About-page update.
