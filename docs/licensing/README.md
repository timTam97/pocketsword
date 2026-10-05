# PocketSword licensing assessment

Assessed 5 October 2026 against `25ea3fc718097556a2cfb839f3c95f469241520e`
(`improvements`) and the locally available upstream commit
`3b94aad8853ea4caf06d421755a2ae58a71d7af4` (`origin/main`).

**An open source release is feasible under GPLv2, with separately licensed
content and fonts. The current tree is not ready for an unqualified App Store
release.** The initial assessment identified App Store/GPL distribution,
Code2000's license, missing Robinson notices, UK KJV rights, and artwork
provenance as release concerns. Current remediation status is recorded below.

This is an engineering due-diligence assessment, not legal clearance. Findings
distinguish repository evidence from legal interpretation. No application code,
license grant, asset, or distribution setting was changed by the initial assessment.

## Follow-up work

On 5 October 2026, `release/rebrand` was created from `main` at `49f4748b`.
The user chose to remove Code2000 and give the app a new name and original
visual assets before publication.

- Code2000 has been removed from the working tree, Xcode project, font
  registration and picker. Existing saved preferences are left unchanged;
  there is no preference migration.
- The historical Code2000 findings below describe the assessed commit. The
  font remains in Git history; no history rewrite has been performed.
- The user selected SimpleScripture and the original Gilded Folio icon for
  the About page. The wider app rename is pending. The new About page
  preserves upstream credits and provides offline notices for all five study
  modules, both shipped fonts, GPLv2 and CC BY-SA 3.0. See
  [notice provenance and validation](about-notices.md).
- The initial simulator build was checked for absence of Code2000. Its
  preference migration and dedicated test were subsequently removed at the
  user's request; settings code and tests now match the branch's base commit.
- Attribution and license access are now implemented. The remaining release
  permission, corresponding-source and content-reuse findings remain open.

## Release decision

| Area | Finding | Action before release |
| --- | --- | --- |
| PocketSword-derived code and English localization | GPLv2-only and GPLv2-or-later notices coexist. GPLv2 is the common permitted version for the combined app. | Release the derivative app under GPLv2; retain individual grants and copyright notices. Do not relicense the whole fork MIT, Apache, or GPLv3 without the necessary rights. |
| App Store distribution | A material unresolved compatibility question remains between GPLv2 and Apple's distribution terms. | Have copyright counsel assess the intended distribution, or obtain a sufficiently broad exception/alternative license from the relevant rights holders. |
| Code2000 | The shipped font says shareware; a historical commit says GPL, and a later public post describes GPLv3 without a font exception. Exact-file permission is not established. | Prefer removal/replacement, or obtain documented permission covering this font and distribution method. |
| Robinson morphology | CC BY-SA 3.0, with explicit attribution and restrictions on imposing legal/technical barriers. The app dropped this metadata. | Restore the correct notices and access to the separately licensed content; assess App Store terms and actual restrictions on the data. |
| KJV | CrossWire grants broad use of its electronic work, but expressly acknowledges Crown rights in the base text. | Resolve UK distribution permission; do not describe the whole bundled KJV as unconditionally public domain worldwide. |
| SIL fonts | Gentium Plus is OFL 1.1; Ezra SIL also contains MIT/X11-licensed shaping code. | Preserve and expose the complete, font-specific notices. |
| Icons, artwork, branding | Inherited assets and contributor credits remain, without a clear separate asset-license inventory. | Establish the grant for retained artwork or replace it. Confirm use of the name and branding separately. |

Charging for the app is not itself prohibited by GPLv2, CC BY-SA, or the OFL's
permission to bundle fonts with software. The important questions are the rights
passed to recipients and the conditions of distribution. [L1, S3, S5]

## 1. The Swift migration did not remove the inherited code license

Evidence in the current tree:

- `Classes/PocketSwordAppDelegate.swift:12` retains CrossWire copyright and a
  GPL version 2 **or later** grant.
- `en.lproj/Localizable.strings:4` retains CrossWire copyright and an explicit
  GPL **version 2** grant, without “or later.”
- `Classes/PSModuleController.swift:8` identifies CrossWire copyright and GPLv2.
  Its upstream `Classes/PSModuleController.mm` explicitly specifies version 2.
- `Classes/globals.h:2` identifies MacSword2 and Manfred Bergmann; the history
  models retain CrossWire credits. `Classes/PSChapterAssembler.swift:5` describes
  its reproduction of the old chapter-assembly behavior.
- `Resources/doc/LICENSE.txt` contains GPLv2. The upstream and current READMEs
  both identify PocketSword as GPL software.

The practical release baseline is GPLv2 for the combined derivative app, while
preserving broader grants on individual files. A top-level statement should
explicitly exclude separately licensed fonts and module content. Do not infer
an “or later” grant for every file from the sample application notice at the end
of the GPL license document. [L1]

A language port can remain a modification of the original work: GPLv2 section 0
explicitly includes translation into another language. Whether particular new
code is independently copyrightable is a separate question; removing the C++
library or changing filenames does not establish that the entire fork is
independent. [L1]

For distributed GPL-covered binaries, provide the complete corresponding source
for the actual released version, including necessary build/installation scripts,
and meet one of GPLv2 section 3's distribution methods. A public repository is
useful, but an unrelated upstream link or a moving branch is not a substitute for
the source matching the binary. If relying on section 3(b), the written source
offer must meet its terms, including the three-year period. Retain notices and
mark modified files and modification dates as section 2(a) requires. [L1]

The current About screen links to the original Bitbucket project, rather than
the fork's corresponding source, and does not provide a GPL reader. The license
file is copied into the bundle, but merely being in the bundle is different from
being discoverable by an app user. See
`Classes/SwiftUISupportingViews.swift:1196` and `:1260`.

## 2. App Store distribution needs a deliberate licensing decision

The FSF's 2010 enforcement analysis identifies Apple's additional usage
restrictions as conflicting with GPLv2 section 6. That is a historical
enforcement position, not a new court ruling about this application. [S1]

I also checked Apple's live US Media Services terms, marked **14 September
2026**. Section F still imposes Usage Rules; section O permits a Custom EULA.
The Standard EULA restricts transfer and redistribution and includes an
open-source carve-out in its copying/modification clause. These provisions need
to be read together: selecting a custom GPL EULA alone does not establish that
every applicable restriction has been removed. The developer agreement, relevant
territories, and actual distribution mechanism also need review. [S2]

There is useful countervailing historical context: a 2012 CrossWire discussion
quotes Nic Carter as understanding the App Store to have become compatible
after earlier restrictions were lifted. This shows that upstream considered the
issue. It is not an express distribution exception, and it predates the terms
reviewed here. No explicit App Store exception was found in the inspected
repository material or that discussion. [S6]

Recommended route: ask Nic Carter/CrossWire about the ownership and authority
behind an App Store exception or alternative license covering the retained
work. Their permission must cover the relevant rights; a maintainer cannot
necessarily authorize every contributor's work, font, or content module.
Alternatively, obtain legal confirmation that the proposed distribution
already complies. Replacing independently owned problem components is another
route, but that would require a separate provenance plan.

Open sourcing the app and charging nothing do not, by themselves, answer this
distribution question. [L1, S1]

## 3. Bundled text is licensed separately from the program

I read `content_meta` in `Resources/PSContent.sqlite` and extracted the original
`mods.d/*.conf` files from the upstream ZIP archives in Git. Each of the five
archive versions matches the corresponding database version. The ZIP bytes are
also unchanged between the upstream commit above and
`59b89e7912e4d8cb79e3e9463c6596b844f61b20`, immediately before their removal.

| Module in this build | Evidence in the original module configuration | Assessment |
| --- | --- | --- |
| KJV 2.9 | `DistributionLicense=General public license for distribution for any purpose`; the About text grants use of CrossWire's electronic work for any purpose and acknowledges Crown rights. | Broad electronic-text permission, with the UK issue below. This wording is **not a GNU GPL grant**. |
| MHCC 1.1 | `DistributionLicense=Public Domain`; the About text identifies the electronic transcription and corrections. | Low license friction on the supplied evidence; preserve source/version provenance. |
| StrongsRealGreek 1.5-150704 | `DistributionLicense=Public Domain`; credits James Strong and Ulrik Sandborg-Petersen's electronic work. | Low license friction on the supplied evidence; retain those credits and provenance. |
| StrongsRealHebrew 1.090107 | `DistributionLicense=Public Domain`; credits James Strong and Jens Grebner's electronic work. | Low license friction on the supplied evidence; retain those credits and provenance. |
| Robinson 2.0 | Configuration specifies Creative Commons Attribution-ShareAlike **3.0** and credits CrossWire's 2002/2009 work. | Attribution/share-alike obligations remain after conversion to SQLite. |

The database metadata contains versions, types, language, direction and features,
but **no module copyright, About, or distribution-license fields**. The current
About UI does not replace that missing information.

For Robinson, restore the title, CrossWire attribution, license URI/text and
conversion notice. Preserve its separate CC BY-SA status. The original module
expressly permits modification and format shifting while prohibiting legal
threats or encryption that prevent reuse. CC BY-SA 3.0 sections 3–4 likewise
govern notices, adaptations and restrictive technological measures. This does
not automatically make the independent Swift application CC BY-SA. [S3, L2]

Publish an accessible, unencrypted copy of the licensed module data and explain
how to extract/reuse it. That is a practical compliance aid, not a claim that a
parallel download automatically cures restrictions on an App Store copy.
The current store uses zlib compression, which is not itself encryption; the
actual release packaging and terms still require assessment.

Cambridge's current policy states that UK KJV rights are vested in the Crown.
Its limited quotation permission does not cover bundling the entire Bible.
For a UK release, obtain the appropriate permission or choose another cleared
content/distribution arrangement. Also consider this when publishing a globally
accessible source/data release; excluding one App Store storefront does not
settle every distribution question. [S4]

## 4. Fonts: one unresolved component and several straightforward notices

These findings come from the actual TrueType `name` tables, rather than assuming
that a nearby `OFL.txt` covers every font.

| File | Version and embedded terms | Present in configured app resources? |
| --- | --- | --- |
| `Resources/fonts/code2000.ttf` | 1.171; James Kass; shareware with registration required after evaluation. | Yes, and registered in `UIAppFonts` and listed in the font picker. |
| `Resources/fonts/GentiumPlus-R.ttf` | 1.510; SIL, 2003–2012; OFL 1.1; reserved names Gentium and SIL. | Yes. |
| `Resources/fonts/SILEOT.ttf` | Ezra SIL 2.51; SIL font software under OFL 1.1; Hebrew layout intelligence by Ralph Hancock and John Hudson under MIT/X11. | Yes. |
| `Resources/fonts/CharisSILR.ttf` | 4.106; SIL, 1997–2009; OFL 1.1; reserved names Charis and SIL. | In the repository, not the current Copy Resources phase or `UIAppFonts`. |
| `Resources/Padauk.ttf` | 2.8; SIL; OFL 1.1; reserved name Padauk. | In the repository, not the current Copy Resources phase or `UIAppFonts`. |

The OFL permits bundling with commercial or open source software, subject to
its conditions. Preserve each font's copyright/license, retain the separate
font license, and respect reserved names for modified versions. The existing
`Resources/fonts/OFL.txt` has a Gentium-specific heading; it does not supply
Ezra's additional MIT/X11 notice. Embedded notices do exist, but the current
About screen only states that Ezra and Gentium use the OFL. Make the complete
notices accessible to users. [S5, L3]

Code2000 needs a separate decision. Commit
`7428eb91dcd18768a593fb611dd1101995e44aec` calls it “newly GPL'd,” but supplies
no font-specific grant. A Unicode mailing-list post attributed to James Kass,
dated 3 February 2012, describes GPLv3 **without** a font exception. That is
material additional evidence, but it does not identify the hash of this 1.171
binary or establish a complete source/distribution package for it. Do not
silently call it OFL, GPLv2, or GPL with a font exception. [S7, L3]

Replacing Code2000 with a suitably licensed font, or removing the font and
picker option, is likely simpler than resolving its provenance.
Do not infer that a separate font automatically
relicenses the application; its own distribution obligations still matter.

## 5. Artwork, identity, and historical dependencies

The tree retains original app icons, launch images, screenshots, `.acorn`
artwork sources and `Resources/crosswire.gif`. The upstream/current credits
include Cheree Lynley Designs and other contributors. I found no separate
asset-by-asset grant establishing which artwork is covered by which permission.
This is a provenance gap, not proof that every inherited image is unlicensed.

Confirm the grant for artwork retained in the app and public repository, or
replace it with assets having documented rights. Keep historical attribution.
Separately resolve product identity: do not imply official CrossWire
endorsement. The Distribution configuration still uses
`org.Crosswire.PocketSword` (`project.pbxproj:1291`), and the About screen says
the app was developed by Nic Carter and CrossWire without explaining the fork.
That bundle identifier is also a release-configuration issue, not evidence of
ownership or permission.

There are no vendored libraries, package-manager dependencies, or SWORD engine
sources in the current checkout/build phases. SDK SQLite/zlib and Apple
framework references are present. Consequently the old vendored libraries are
not additional runtime dependencies of this build.

They remain relevant if publishing the full Git history:

| Historical component | Evidence inspected | Scope |
| --- | --- | --- |
| SWORD and MacSword/Sword wrappers | GPLv2 headers in `swmgr.cpp` and `SwordManager.h`. | Removed implementations; do not assume their license vanished from retained derivatives or source history. |
| GCDWebServer | BSD 3-clause header. | Historical source redistribution must retain its notices. |
| minizip | zlib-style license in `externals/ZipArchive/minizip/LICENSE`. | Historical source redistribution must retain its notices. |
| libcurl | Headers refer to its own COPYING; static archives exist upstream. | An exact historical binary/source and notice audit remains outstanding. |
| CocoaHTTPServer, CCBottomRefreshControl, MBProgressHUD, SSZipArchive | Historical copies inspected, but complete original license packages were not established in this assessment. | Not current runtime blockers; clear them if republishing historical snapshots/binaries or representing the entire history as audited. |

Deletion from HEAD does not remove an object from a full-history public push.
This assessment does not certify every historical dependency or release.
A deliberately scoped current-source export and publication of the existing
Git history are different distributions and should be assessed accordingly.
No history rewriting or deletion is proposed as an automatic action.

The old `tools/swordbake` converter is available at `fa09511^`; it is not part
of the current checkout. Preserve a documented route to the exact input data,
converter revision, and generated store. Assess the preferred-source
requirements for any GPL-covered generated material; do not assert that CC
BY-SA itself requires publishing this converter.

## Recommended sequence

1. **Resolve the App Store permission strategy first.** Establish whether an
   existing grant suffices or request an exception/alternative grant covering
   the relevant retained work.
2. **Remove or clear Code2000.** Cover both the release payload and the chosen
   scope of public repository publication.
3. **Restore a content/license manifest and an accessible Legal screen.**
   Include Robinson CC BY-SA 3.0, KJV terms, public-domain provenance, complete
   font notices, GPLv2, fork attribution and corresponding-source access.
4. **Settle UK KJV rights and inherited artwork/branding.** Preserve written
   evidence of any permissions.
5. **Prepare the source release.** Add a clear top-level license scope,
   third-party notices, modified-file notices and an exact release tag/source
   archive with the required build inputs. Inventory historical distributions
   separately if making the full repository public.
6. **Verify the final release artifact.** Inspect the archived app for included
   fonts/assets/notices and test the Legal/source links. This assessment
   inspected source/build configuration; it did not build or inspect an IPA.

## Evidence and sources

Local evidence:

- **L1:** `Resources/doc/LICENSE.txt`, especially sections 0–3, 6–7 and 9;
  current and upstream source headers identified above.
- **L2:** `mods.d/kjv.conf`, `mhcc.conf`, `robinson.conf`,
  `strongsrealgreek.conf`, and `strongsrealhebrew.conf` inside the corresponding
  `Resources/*.zip` files at upstream commit `3b94aad8`. Versions and archive
  identity checked against the pre-removal commit and current SQLite metadata.
- **L3:** Embedded TrueType name records 0, 1, 5, 13 and 14 in the five font files;
  `Resources/fonts/OFL.txt`; Copy Resources phase and `misc/Info.plist:65`.
- **L4:** Current `PSContent.sqlite` SHA-256:
  `ec77a0d620130f67fa703fd21e704d847074a52f2112cc78eefa2db195b89a60`.
  Current Code2000 SHA-256:
  `7bc1d47e3aeda96cfe5cb2d0727e1b0552ec60f9b2340fe63b8b30c912513aea`.

Primary web sources read on 5 October 2026:

- **S1 — FSF, More about the App Store GPL Enforcement**, 26 May 2010.
  `https://www.fsf.org/blogs/licensing/more-about-the-app-store-gpl-enforcement`
- **S2 — Apple Media Services Terms and Conditions (US)**, page marked updated
  14 September 2026, sections F and O including the Standard EULA.
  `https://www.apple.com/legal/internet-services/itunes/us/terms.html`
- **S3 — Creative Commons Attribution-ShareAlike 3.0 Unported, legal code**,
  especially sections 1, 3 and 4.
  `https://creativecommons.org/licenses/by-sa/3.0/legalcode`
- **S4 — Cambridge University Press, Bibles rights and permissions**, King James
  Version section.
  `https://www.cambridge.org/au/universitypress/bibles/about/rights-and-permissions`
- **S5 — SIL Open Font License Official Text**, version 1.1.
  `https://openfontlicense.org/open-font-license-official-text/`
- **S6 — CrossWire sword-devel, GPL restrictions**, 12 August 2012; includes
  quoted correspondence from Nic Carter and discussion of the FSF position.
  `https://crosswire.org/pipermail/sword-devel/2012-August/038245.html`
- **S7 — Unicode mailing-list archive, Code2000 on SourceForge**, post
  attributed to James Kass, 3 February 2012.
  `https://www.unicode.org/mail-arch/unicode-ml/y2012-m02/0016.html`

Search results were used for discovery; the conclusions above use the
underlying primary pages and the exact local files. Private permissions,
copyright assignments and the user's Apple developer agreement were not
available for inspection.
