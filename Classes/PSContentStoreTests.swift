//
//  PSContentStoreTests.swift
//  PocketSwordTests
//
//  Tests for the baked content store (Resources/PSContent.sqlite) and the
//  pure-Swift reader that Phase 3 of the SWORD-removal plan builds on top of it.
//
//  This file starts with the one thing the rest of Phase 3 depends on: the
//  artifacts are actually in the app bundle. They are bundled by path, so a
//  converter re-run replaces them in place without touching the pbxproj — but a
//  missing Copy-Resources entry would make every later reader test fail for a
//  reason that has nothing to do with the reader.
//

import XCTest
@testable import PocketSword

final class PSContentStoreTests: XCTestCase {

    // MARK: - Bundling (plan step 1)

    func testContentArtifactsAreBundled() throws {
        let store = Bundle.main.url(forResource: "PSContent", withExtension: "sqlite")
        XCTAssertNotNil(store, "PSContent.sqlite is missing from the app bundle's Copy Resources phase")

        let versification = Bundle.main.url(forResource: "Versification-KJV", withExtension: "json")
        XCTAssertNotNil(versification, "Versification-KJV.json is missing from the app bundle")

        // Non-empty and readable, not just present: a Copy Resources entry that
        // points at a stale path would still resolve to a zero-byte file.
        if let store {
            let size = try FileManager.default.attributesOfItem(atPath: store.path)[.size] as? Int ?? 0
            XCTAssertGreaterThan(size, 1_000_000, "PSContent.sqlite looks truncated (\(size) bytes)")
        }
        if let versification {
            let json = try Data(contentsOf: versification)
            XCTAssertGreaterThan(json.count, 1000, "Versification-KJV.json looks truncated")
        }
    }
}
