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

    // MARK: Built in modules

    private func run(_ name: String, _ text: String) -> String {
        guard let script = manager.scripts.first(where: { $0.name == name }) else {
            XCTFail("No script named \(name)")
            return ""
        }
        return manager.runScript(script, fullText: text)
    }

    func testHashesHashUTF8Text() {
        let text = "héllo 😀"
        XCTAssertEqual(run("MD5 Checksum", text), "207dd4f0cd7a4f13b4932646cd1f8f2b")
        XCTAssertEqual(run("SHA1 Hash", text), "628b3695e32b5f3b3789dcd4fe8100e5dba231da")
        XCTAssertEqual(run("SHA256 Hash", text), "a53c56966616f0ec3ed9db7ea07a6034430149528bbaba8966c284f9373669c2")
        XCTAssertEqual(run("SHA512 Hash", text), "60f5ad0f4b9c505aff0d48c8b83c958908fb2852e16351a96bb428a273032c0ca0953b5ad0848830cd278f57b6950082fd91c125329d68a5e763bed57202117f")
    }

    func testHMAC() {
        let code = ScriptNative.authenticationCode("sha256", key: Data("key".utf8), data: Data("msg".utf8))!
        XCTAssertEqual(ScriptNative.format(code, "hex"), "2d93cbc1be167bcb1637a4a23cbff01a7878f0c50ee833954ea5221bb1b8c628")
    }

    func testBase64RoundTripsUTF8() {
        XCTAssertEqual(run("Base64 Encode", "héllo 😀"), "aMOpbGxvIPCfmIA=")
        XCTAssertEqual(run("Base64 Decode", "aMOpbGxvIPCfmIA="), "héllo 😀")
        XCTAssertEqual(run("Base64 Decode", "aMOp bGxv\nIPCfmIA"), "héllo 😀")
    }

    func testBase64DecodeAcceptsURLSafeAlphabet() {
        XCTAssertEqual(run("Base64 Decode", "eyJuIjoiSsO2Pz4_PiJ9"), #"{"n":"Jö?>?>"}"#)
        XCTAssertEqual(ScriptNative.encode(Data(#"{"n":"Jö?>?>"}"#.utf8), urlSafe: true), "eyJuIjoiSsO2Pz4_PiJ9")
    }

    func testJWTDecode() {
        let token = "eyJhbGciOiJIUzI1NiJ9.eyJuIjoiSsO2Pz4_PiJ9.sig"
        let json = run("JWT Decode", token)
        XCTAssertTrue(json.contains(#""alg": "HS256""#), json)
        XCTAssertTrue(json.contains(#""n": "Jö?>?>""#), json)
    }

    func testHTMLEncodeEscapesOnlyMarkupCharacters() {
        XCTAssertEqual(run("HTML Encode", #"<a href="x">Café & 'ok' 😀</a>"#),
                       "&lt;a href=&quot;x&quot;&gt;Café &amp; &#39;ok&#39; 😀&lt;/a&gt;")
    }

    func testHTMLDecode() {
        XCTAssertEqual(run("HTML Decode", "&lt;b&gt; &amp;amp; &quot;&#39;&apos;"), #"<b> &amp; "''"#)
        XCTAssertEqual(run("HTML Decode", "caf&#233; caf&#xE9; &#x1F600;"), "café café 😀")
        XCTAssertEqual(run("HTML Decode", "a&nbsp;b &hellip; &mdash; &euro;"), "a\u{00A0}b … — €")
        XCTAssertEqual(run("HTML Decode", "&rarr; &amp &#0;"), "&rarr; &amp \u{FFFD}")
    }

    func testCaseConversions() {
        XCTAssertEqual(run("Camel Case", "XMLHttp request_id"), "xmlHttpRequestId")
        XCTAssertEqual(run("Kebab Case", "Don't café ПриветМир"), "dont-cafe-привет-мир")
        XCTAssertEqual(run("Snake Case", "fooBar 1st place"), "foo_bar_1st_place")
        XCTAssertEqual(run("Start Case", "HELLO_WORLD foo"), "Hello World Foo")
        XCTAssertEqual(run("Deburr", "Æsir straße Łódź déjà"), "Aesir strasse Lodz deja")
    }

    func testFormatXML() {
        let input = "<?xml version=\"1.0\"?><a x='1'><b>1</b><c><d/></c><p>Hi <i>you</i></p></a>"
        XCTAssertEqual(run("Format XML", input), """
            <?xml version="1.0"?>
            <a x="1">
                <b>1</b>
                <c>
                    <d/>
                </c>
                <p>Hi <i>you</i></p>
            </a>
            """)
        XCTAssertEqual(run("Minify XML", "<a>\n  <b>1</b>\n</a>"), "<a><b>1</b></a>")
        XCTAssertEqual(run("Format XML", "<a><b></a>"), "<a><b></a>", "malformed XML is left alone")
    }

    func testFormatXMLDoesNotLoadExternalEntities() {
        let input = #"<?xml version="1.0"?><!DOCTYPE a [<!ENTITY x SYSTEM "file:///etc/hosts">]><a>&x;</a>"#
        XCTAssertFalse(run("Format XML", input).contains("localhost"))
        XCTAssertFalse(run("Minify XML", input).contains("localhost"))
    }

    func testFormatCSSKeepsStringsAndURLsWhole() {
        XCTAssertEqual(run("Format CSS", #"a{content:";";background:url(data:x;base64,AA)}"#), """
            a {
                content: ";";
                background: url(data:x;base64,AA);
            }
            """)
        XCTAssertEqual(run("Minify CSS", "a , b > c { color : red ; } /* x */"), "a,b>c{color:red}")
    }

    func testYAMLToJSON() {
        XCTAssertEqual(run("YAML to JSON", "a: 1\nb:\n  - x\n  - 'é 😀'\n"), """
            {
              "a": 1,
              "b": [
                "x",
                "é 😀"
              ]
            }
            """)
    }

    func testJSONToYAML() {
        XCTAssertEqual(run("JSON to YAML", #"{"a":1,"b":["x","é 😀"]}"#), "a: 1\nb:\n  - x\n  - é 😀\n")
    }

    func testCSVToJSON() {
        XCTAssertEqual(run("CSV to JSON", "name,note\nAnn,\"a, \"\"b\"\"\""), """
            [
              {
                "name": "Ann",
                "note": "a, \\"b\\""
              }
            ]
            """)
    }

    func testFormatSQLKeepsStringLiterals() {
        XCTAssertEqual(run("Format SQL", "select a, b from t where s = 'a   b' and x in (select y from z)"), """
            select a,
                b
            from t
            where s = 'a   b'
                and x in (
                    select y
                    from z
                )
            """)
        XCTAssertEqual(run("Minify SQL", "SELECT  a -- c\nFROM t WHERE s = 'a   b'"), "SELECT a FROM t WHERE s = 'a   b'")
    }

}
