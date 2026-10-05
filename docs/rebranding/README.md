# Rebranding work

Branch: `release/rebrand`, created from `main` at `49f4748b` on 5 October 2026.

The app will receive a new name and original visual assets before publication.
The user requested help choosing the name and style, then proposed
**SimpleScripture**. On 5 October 2026, the user chose SimpleScripture and
Gilded Folio for the redesigned About page. Its icon is now included in the
application bundle; the wider app metadata and Home Screen rename are pending.

## Selected About direction: SimpleScripture

The name directly communicates the purpose of the app and fits a focused Bible
reader with commentary, search and lexicons. “Simple” describes the interface;
it does not require removing the study tools. “Simple Scripture” is an optional
spaced form for visible titles; the user's proposed spelling is SimpleScripture.

The first visual proposal was an open book with one brass bookmark, on deep pine.
Palette: pine `#254E47`, paper `#F9F8F2`, brass `#D4B875`, sage `#93ABA1`.
Use a clear sans serif for the brand; leave the reading font under user control.
The editable master is `simplescripture.svg`; `simplescripture-concept.png`
shows the concept at large and small sizes. These are provisional, original
vector shapes, not final application assets.

### Latest icon: Gilded Folio

On 5 October 2026, the user requested a maximalist, skeuomorphic direction
inspired by the tactile character of the original PocketSword icon.
`simplescripture-heritage.af` is the editable Affinity master. The revised
pine-leather Bible is upright and fills the square icon, with a solid gold cross
(`#E3BC67`), a plain embossed oval, gilt page edges, index tabs, and an oxblood
satin bookmark. The cross has a fine bronze outline and a soft shadow; its face
remains one colour. Botanical ornaments, the oval's inward rays and lower
diamond-and-dot ornament, and the cross's gradients, bevels, and hairlines have
been removed at the user's request.

- `simplescripture-heritage.png`: exported from Affinity and verified as
  1024 × 1024, RGB, sRGB IEC61966-2.1, without an alpha channel.
- `simplescripture-heritage-preview.png`: a 640 px preview for review.
- `simplescripture-heritage.svg`: original vector source with embedded,
  procedurally generated material textures. No inherited icon pixels or font
  files are included.

The detailed source was prepared programmatically after Affinity's custom
controls rejected computer-use input, then imported, visually inspected, saved
as a native document, and exported through Affinity. The revision used an SVG
export of the user's straightened Affinity document as its base. The binding
was widened to fill the square while preserving the cross and oval proportions.
Book and background are separate groups; the book contains editable component
groups. The updated PNG was checked at 60, 120, and 256 px, and the cross's
interior was verified to contain one RGB colour. The PNG is now installed as
the `SimpleScriptureAbout` image set. The Home Screen app icon still awaits
the wider branding update.

On 5 October 2026, the primary website at
`https://www.simplescripture.co.za/` was checked. It uses “Simple Scripture” for
Christian books and resources. A limited search of indexed Apple App Store
pages did not surface an exact app-title match. This does not establish App
Store Connect availability or trademark clearance. Existing use in the same
subject area is a reason to review differentiation before publication.

## Name and visual directions

| Working name | Character | Icon concept | Palette |
| --- | --- | --- | --- |
| Scripture Folio | A focused tool for reading and studying a text. More editorial than devotional. | A folded page with a marked passage. | Mulberry `#512D4C`, pale lavender `#D9C3DD`, paper `#FAF7FC`, annotation gold `#EDCA84`. |
| Daymark Bible | A warm, approachable name suggesting guidance and a place to return to. | An open book beneath a rising light. | Deep teal `#153E42`, amber `#FFBE55`, light teal `#7FAAA7`, paper `#FFF6E6`. |

For typography, Scripture Folio pairs a serif name with simple supporting text;
Daymark uses a friendly sans serif. Both marks use a simple silhouette that can
work at Home Screen sizes. The comparison uses Georgia and Avenir installed on
the development Mac; no font files are copied into the repository or app.

These were the initial alternatives before the user proposed SimpleScripture.
Scripture Folio emphasizes the reading, commentary and lexicon functions; its
longer Home Screen label should be reviewed on device. Daymark Bible is the
shorter-brand option, using Daymark as a possible Home Screen label.

Initial web searches on 5 October 2026 did not surface an exact Bible-app match
for these two full names. Daymark is already used by unrelated planning and
journaling apps; “scripture folio” is also a descriptive phrase for paper craft
products. Neither name has received an App Store Connect availability check or
trademark clearance. Do that before final adoption.

Other candidates were dropped when searches surfaced closely related uses:
Leaf and Lamp (Christian writing), Versefield (Scripture music), and Versefold
(an existing Bible app). Search results are preliminary screening, not an
ownership determination.

## Design intent

The SimpleScripture board shows its name, a large icon, palette and smaller icon
previews. Labels are left aligned; the icon silhouette does most of the work.
There are no inherited PocketSword images, stock marks, or copied competitor
graphics.

The original idea of cream backgrounds and generic book illustrations was
narrowed to two clear marks: a single marked page and a book carrying light.
The first palette uses plum rather than the old app's blue; the second gets
its personality from teal and amber. These are identity proposals, not a
request to tint every reader surface or change the current navigation.

The earlier editable alternatives are `scripture-folio.svg` and
`daymark-bible.svg`. Preview images use a rounded mask; the masters themselves
remain square. They are provisional artwork, not final App Store exports.

## Implementation inventory once the name is selected

- Display name and product metadata in `misc/Info.plist` and Xcode settings.
- Launch/error labels, microphone permission copy, and denied-access guidance
  in `en.lproj/Localizable.strings` and `misc/Info.plist`.
- About title, icon, feedback subject, project link and fork attribution in
  `Classes/SwiftUISupportingViews.swift`. Replace the inherited upstream
  feedback email with a destination owned by this fork; the current GitHub
  repository is available as a project/support destination.
- Settings-bundle visible labels, including the reset action.
- App icon asset catalog and legacy icon/launch-image references in the
  project and plist; remove superseded inherited art and screenshots from the
  chosen publication scope.
- Confirm bundle identifiers and iCloud/key-value-store entitlements. The
  Distribution configuration and an entitlement still refer to CrossWire.
  Changing these can change which existing app/container data is accessible.
- Keep original copyright and license notices. Identify PocketSword as the
  upstream project in attribution rather than presenting the fork as the
  original developer's release.
- Preserve persisted preference keys, serialization formats and supported
  deep links unless a separate compatibility migration is deliberately made.
  Internal `PS` class names do not need a mechanical rename to change branding.

## Completed preparation

- Code2000 removed from source resources, Copy Resources, `UIAppFonts` and
  the font picker (8,377,000 bytes).
- Existing saved preferences are left unchanged. The user requested font
  removal without migrating existing selections.
- The initial Xcode MCP build-for-testing succeeded for iPhone 18 Pro, iOS 27.
- That built simulator app contains no Code2000 file and registers only
  Gentium Plus and Ezra SIL.
- The preference migration and its dedicated test were subsequently removed;
  settings code and tests now match the branch's base commit.
- Git history and the remaining licensing findings have not been changed.

## About page

The About page now uses the approved SimpleScripture name and Gilded Folio icon.
The icon supplies the pine-and-gold detail; a system-type header, adaptive
pine/sage links and native grouped rows keep the surrounding page quiet.
Text sizes follow Dynamic Type. The page describes the app as an independent
continuation of PocketSword and directs source/support links to the fork's
public GitHub repository.

Credits & licenses opens an offline index with PocketSword's original
contributors and copyright notices, GPLv2, all five bundled study modules,
Gentium Plus's OFL 1.1, Ezra SIL's OFL 1.1 and MIT/X11, and complete CC BY-SA 3.0.
Robinson's notice includes its CrossWire credit and format-conversion notice.
See [notice provenance and release boundaries](../licensing/about-notices.md).

Implementation: `Classes/SwiftUIAboutView.swift`, `Resources/Notices`, the
`SimpleScriptureAbout` and `AboutAccent` asset sets, and English localization.
The old About implementation was extracted from `SwiftUISupportingViews.swift`.

Validation: Xcode MCP build-for-testing and the three focused tests passed.
The final Xcode command-line run also passed all three tests, zero skips, after
the license reader's display wrapping was refined. Its UI test captures the
About page, credits index, GPL, Robinson, CC BY-SA and Ezra screens, and verifies
scrolling to Robinson's complete-license link, following it, and opening Ezra's
MIT/X11 notice.

Portrait screenshots on iPhone 18 Pro Max / iOS 27 were visually reviewed at the
default text size in light mode. Text is readable and rows/headings wrap without
clipping. Landscape, accessibility text sizes, dark mode and iPad remain
unverified. Xcode MCP's device sessions repeatedly disappeared after installation;
the visual evidence therefore comes from successful XCUITest screenshot
attachments. No source changes were needed for the session problem.

Final result bundle: `/tmp/simplescripture-about-final.xcresult`. The six screenshots
are in the chat's visualization directory under
`/Users/timsam/.codex/visualizations/2026/10/05/01a10b49-f1c6-7122-95c8-5742e15b0047/`.
