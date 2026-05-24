import XCTest
@testable import SluiceCore

final class LinkUnwrapperTests: XCTestCase {
    private func unwrap(_ string: String) -> URL {
        LinkUnwrapper.unwrap(URL(string: string)!)
    }

    func testGoogleSafelinkUnwrapsQParam() {
        let result = unwrap("https://www.google.com/url?q=https%3A%2F%2Fexample.com%2Farticle&sa=U")
        XCTAssertEqual(result, URL(string: "https://example.com/article")!)
    }

    func testGoogleSafelinkWithoutQParamReturnsOriginal() {
        let input = "https://www.google.com/url?url=https%3A%2F%2Fexample.com&dest=foo"
        let result = unwrap(input)
        XCTAssertEqual(result, URL(string: input)!)
    }

    func testGoogleSafelinkWithMissingQValueReturnsOriginal() {
        let input = "https://www.google.com/url?sa=U"
        let result = unwrap(input)
        XCTAssertEqual(result, URL(string: input)!)
    }

    func testGoogleAmpUnwrapsToHttpsTarget() {
        let result = unwrap("https://www.google.com/amp/s/example.com/article")
        XCTAssertEqual(result, URL(string: "https://example.com/article")!)
    }

    func testOutlookSafelinkUnwraps() {
        let result = unwrap("https://eu-west-1.safelinks.protection.outlook.com/?url=https%3A%2F%2Fexample.com&data=x")
        XCTAssertEqual(result, URL(string: "https://example.com")!)
    }

    func testOutlookSafelinkSubdomainMatchesCaseInsensitive() {
        let result = unwrap("https://NAM10.safelinks.PROTECTION.outlook.com/?url=https%3A%2F%2Ffoo.test%2Fpath")
        XCTAssertEqual(result, URL(string: "https://foo.test/path")!)
    }

    func testLinkedInRedirectUnwraps() {
        let result = unwrap("https://www.linkedin.com/redir/redirect?url=https%3A%2F%2Fexample.com%2Fpost")
        XCTAssertEqual(result, URL(string: "https://example.com/post")!)
    }

    func testLinkedInRedirSubpathUnwraps() {
        let result = unwrap("https://www.linkedin.com/redir/general-malware-page?url=https%3A%2F%2Fexample.com")
        XCTAssertEqual(result, URL(string: "https://example.com")!)
    }

    func testNestedGoogleWrappingOutlookUnwrapsTwice() {
        let inner = "https://eu-west-1.safelinks.protection.outlook.com/?url=https%3A%2F%2Ffinal.example.com%2Fx"
        let innerEncoded = inner.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let outer = "https://www.google.com/url?q=\(innerEncoded)"
        let result = unwrap(outer)
        XCTAssertEqual(result, URL(string: "https://final.example.com/x")!)
    }

    func testNonWrapperURLReturnsUnchanged() {
        let input = "https://figma.com/file/abc"
        let result = unwrap(input)
        XCTAssertEqual(result, URL(string: input)!)
    }

    func testNonWrapperHttpsURLWithQueryReturnsUnchanged() {
        let input = "https://example.com/path?q=hello&utm_source=test"
        let result = unwrap(input)
        XCTAssertEqual(result, URL(string: input)!)
    }

    func testIterationCapStopsAfterFour() {
        // Build a 6-deep chain of Google wrappers. The unwrapper should stop
        // after 4 iterations, leaving 2 wrappers still in place — i.e. the
        // result must still be a google.com URL, not the final destination.
        let destination = "https://final.example.com/"
        var current = destination
        for _ in 0..<6 {
            let encoded = current.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
            current = "https://www.google.com/url?q=\(encoded)"
        }
        let result = LinkUnwrapper.unwrap(URL(string: current)!)
        XCTAssertEqual(result.host?.lowercased(), "www.google.com")
        XCTAssertNotEqual(result, URL(string: destination)!)
    }

    func testCaseInsensitiveHostMatch() {
        let result = unwrap("https://WWW.GOOGLE.COM/url?q=https%3A%2F%2Fexample.com%2Fa")
        XCTAssertEqual(result, URL(string: "https://example.com/a")!)
    }

    func testGoogleBareHostUnwraps() {
        let result = unwrap("https://google.com/url?q=https%3A%2F%2Fexample.com%2Fb")
        XCTAssertEqual(result, URL(string: "https://example.com/b")!)
    }

    func testOutlookSafelinkWithoutUrlParamReturnsOriginal() {
        let input = "https://eu-west-1.safelinks.protection.outlook.com/?data=x"
        let result = unwrap(input)
        XCTAssertEqual(result, URL(string: input)!)
    }
}
