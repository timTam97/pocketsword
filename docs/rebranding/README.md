# Rebranding work

Branch: `release/rebrand`, created from `main` at `49f4748b` on 5 October 2026.

The app will receive a new name and original visual assets before publication.
The user requested help choosing the name and style, then proposed
**SimpleScripture**. On 5 October 2026, the user chose SimpleScripture and
Gilded Folio for the redesigned About page. Its icon is now included in the
application bundle. The display name and visible application messages now use
SimpleScripture. Gilded Folio is also installed as the app icon, and all build
configurations use the fork's new application identity.

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
the `SimpleScriptureAbout` image set and the universal 1024 px iOS `AppIcon`
source. Xcode generates the required device icon sizes from the approved PNG.

The obsolete icon sets, launch images, screenshots, `.acorn` artwork and unused
bitmap controls have been removed from the current checkout and Xcode resources
(170 files, 17,240,098 bytes). The SwiftUI UI uses SF Symbols plus the new About
image; the launch storyboard is a plain background. Copyright/contributor
notices and Git history are preserved.

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

## Application integration

Completed on 5 October 2026:

- Home Screen/display name, bundle name, launch progress and failure messages,
  microphone permission and denied-access text, the morphology help message,
  and system Settings labels use SimpleScripture.
- The approved Gilded Folio PNG supplies both the app icon and About image.
  Legacy icon plist keys, inherited launch-image assets, unused bitmap controls,
  artwork sources and old screenshots have been removed from the current tree.
- About uses the fork's project/support destination and preserves upstream
  attribution and the offline notices described below.
- `Debug`, `Release` and `Distribution` build `SimpleScripture.app`, with
  executable `SimpleScripture`, bundle ID `org.timsam.SimpleScripture`, automatic
  signing and the existing fork team `7SZUJ26BQ2`. Test bundle IDs are
  `org.timsam.SimpleScriptureTests` and `org.timsam.SimpleScriptureUITests`.
- All app configurations use `SimpleScripture.entitlements`. Its iCloud
  key-value-store identifier is
  `$(TeamIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)`. The old CrossWire
  keychain group and hardcoded `get-task-allow` entitlement are removed;
  signing supplies the app's default identity.
- Project/target/scheme names and the Swift module remain `PocketSword`.
  Shared schemes and the test host point to the renamed app product.
- `sword://` remains registered. Its URL-type name and the search-index
  background-task identifier now derive from the new bundle ID.

This is a **new app identity**, not an update to any old PocketSword bundle ID.
Existing PocketSword local containers, preferences, bookmarks and cloud history
are not automatically migrated, shared or deleted. Debug, Release and
Distribution use the same new installation and cloud namespace. Persisted keys
(including `reset_PocketSword`), serialization formats and routing code are
unchanged.

Verification to date:

- Xcode MCP build-for-testing passed after the icon cleanup and again after
  the product/identifier changes.
- All 27 focused tests passed, with zero skips: the 18 persisted-format tests,
  seven state/notice/routing/background tests, and two UI tests covering the
  four workspaces and Settings → About → offline credits/licenses.
- Resolved build settings match across all three configurations. The built
  simulator app contains the new names, generated iPhone/iPad icon entries,
  `sword` scheme and `org.timsam.SimpleScripture.search-index` task identifier.
  Xcode expanded the simulated key-value-store entitlement to
  `7SZUJ26BQ2.org.timsam.SimpleScripture`.
- A clean, unsigned Distribution archive succeeded at
  `/tmp/simplescripture-rebrand.xcarchive`. Its compiled asset catalog contains
  only `AppIcon`, `SimpleScriptureAbout` and `AboutAccent`; only Gentium Plus
  and Ezra SIL fonts are included. Both content files, all nine notices and
  GPLv2 match their source bytes. The Settings labels and reset key were checked
  in the archived bundle. No `CompileC` tasks ran.
- On iPhone 18 Pro Max / iOS 27, the Home Screen shows Gilded Folio and the
  complete SimpleScripture label without truncation, alongside the separate
  old PocketSword installation. Settings → Apps shows the new name/icon and
  opens a SimpleScripture page with “Reset SimpleScripture?”; the toggle was
  left off. Screenshots and hierarchy captures are saved under
  `/Users/timsam/.codex/visualizations/2026/10/05/01a10b67-8f76-7ea1-92f4-81aeec954085/rebrand-runtime/`.
- Signed-device provisioning, App Store registration and live iCloud sync
  have not been verified by the simulator build/tests.

The root README/public listing, name availability checks and broader visual
validation remain separate follow-up work. Release permission/source/data
requirements remain in the licensing assessment.

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
