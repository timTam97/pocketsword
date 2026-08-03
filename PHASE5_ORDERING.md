# Phase 5 — a cycle in the plan's step order, and how it was resolved

Scratch note written while implementing `SWORD_REMOVAL_PLAN.md` Phase 5. Folded
into the plan's own "findings that correct the plan" section by step 13; delete
this file then.

## The cycle

The plan runs **7 (delete the bridge) → 8 (port the engine) → 9 (delete the zips
and the seeding) → 12 (retarget the tests)**. Those four cannot happen in that
order. Three separate dependencies point backwards:

**A. Step 7 cannot precede step 9.**
Step 7 deletes `PSModuleController.swordManager`. But `installModulesFromZip`
(`PSModuleController.swift:249`) and `setPreferences`
(`PSModuleController.swift:230-243`) both use it, and those are not removed until
step 9. Deleting the manager first leaves a non-building commit.

**B. Step 9 cannot precede step 12.**
Step 9 deletes the module zips. Every engine-driven test polls
`isModuleInstalled(name)` with a 90-second timeout and then `XCTSkip`s
(`PSDifferentialTests`, `PSRefSemanticsTests`, `PSSearchIndexParityTests`,
`SwordOracleCaptureTests`). With no zips they all **skip rather than fail** — the
plan's own "watch for false green" warning, arrived at from the other direction.
The suite would go from 102/7 to something like 60/49 and still report zero
failures.

**C. Step 9 cannot precede step 7 either — which closes the loop.**
`reloadLastBible` resolves `primaryBible` through
`swordManager?.module(withName:)` (`PSModuleController.swift:588`). Delete the
seeding without step 7's name-based `primary*` properties and `primaryBible`
becomes nil, so `getBibleChapter` renders the "NoModulesInstalled" placeholder
instead of a chapter. The app builds and the tests pass; it just shows no text.

A + C mean 7 and 9 are **mutually dependent**: neither can go first.

## Resolution

    12  →  9 + 7 (one commit)  →  8  →  10  →  11  →  13

* **12 first.** The tests it deletes are engine-vs-reader comparisons, and their
  replacement oracles are already committed and asserting: the pre-work captured
  `search-index-KJV.digest` and `chapter-loop-counters.tsv`, Phase 4 captured
  `versification-KJV-oracle.txt`, and step 4 added
  `testBakedModuleMetadataMatchesTheModuleConfs`. Nothing is lost by retargeting
  before the engine goes, and it removes dependency B entirely.
* **9 and 7 combined.** Forced by A + C. It is a big commit, but the alternative
  is a commit that builds and silently renders nothing — exactly what the plan's
  per-commit "leaves the suite green" rule is meant to prevent, and what the suite
  cannot catch (the reading pane is a WKWebView; no test sees it).
* **8 after**, unchanged: it needs `PSSearchEngine.mm` to be the last `.mm`.

## One consequence worth noting

`SwordOracleCaptureTests.testFoldForIndexAgreesBetweenObjCAndSwift` guarded that
Obj-C `PSFoldForIndex` and Swift `PSSearchQuery.foldForIndex` agree. Step 12
deletes that file, and step 8 deletes `PSFoldForIndex`, so there is a window where
the duplication is unguarded. Nothing modifies either copy in that window, but to
avoid weakening the algorithm's coverage, step 12 pins the **Swift** fold against
known vectors in a surviving test rather than simply dropping the guard.
