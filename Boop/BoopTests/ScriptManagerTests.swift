//
//  ScriptManagerTests.swift
//  BoopTests
//
//  Created by Ivan on 3/21/20.
//

import XCTest

class ScriptManagerTests: XCTestCase {
    
    let manager = ScriptManager()


    func testManager() {
        XCTAssertFalse(manager.scripts.isEmpty)
    }

    // MARK: Picker search

    private func names(_ query: String, top: Int = 5) -> [String] {
        return manager.search(query).prefix(top).compactMap { $0.name }
    }

    func testEmptyQueryListsEverythingAlphabetically() {
        let all = manager.search("").compactMap { $0.name }
        XCTAssertEqual(all.count, manager.scripts.count)
        XCTAssertEqual(all, all.sorted())
    }

    func testNameMatchesRankAboveTagOnlyMatches() {
        let top = names("encode", top: 3)
        XCTAssertTrue(top.allSatisfy { $0.localizedCaseInsensitiveContains("encode") }, "\(top)")
    }

    func testWordStartAbbreviations() {
        XCTAssertEqual(names("b64e", top: 1), ["Base64 Encode"])
        XCTAssertEqual(names("fj", top: 1), ["Format JSON"])
    }

    func testMultipleTermsMustAllMatch() {
        XCTAssertEqual(names("url dec", top: 1), ["URL Decode"])
        XCTAssertTrue(manager.search("base64 zzzz").isEmpty)
    }

    func testCaseAndDiacriticsAreIgnored() {
        XCTAssertEqual(names("FORMAT json", top: 1), ["Format JSON"])
        XCTAssertEqual(names("fórmat", top: 1), names("format", top: 1))
    }

    func testNonsenseAndOverlongQueriesMatchNothing() {
        XCTAssertTrue(manager.search("qqqxxzz").isEmpty)
        XCTAssertTrue(manager.search(String(repeating: "a", count: 200)).isEmpty)
    }

    func testFuzzyMatcherRequiresLettersInOrder() {
        XCTAssertNotNil(FuzzyMatcher.score("ue", in: "URL Encode"))
        XCTAssertNil(FuzzyMatcher.score("eu", in: "URL"))
        XCTAssertGreaterThan(FuzzyMatcher.score("enc", in: "Encode")!, FuzzyMatcher.score("enc", in: "Mencode")!)
    }

}
