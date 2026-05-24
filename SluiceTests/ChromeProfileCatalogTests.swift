import XCTest
@testable import Sluice

final class ChromeProfileCatalogTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sluice-chrome-profiles-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    private func writeFixture(_ json: String) throws -> URL {
        let url = tempDir.appendingPathComponent("Local State")
        try Data(json.utf8).write(to: url, options: .atomic)
        return url
    }

    func testParsesProfilesFromFixture() throws {
        let json = """
        {
          "profile": {
            "info_cache": {
              "Default": { "name": "Personal", "user_name": "me@gmail.com" },
              "Profile 1": { "name": "Work", "user_name": "me@company.com" }
            }
          }
        }
        """
        let url = try writeFixture(json)
        let catalog = ChromeProfileCatalog(localStateURL: url)
        let profiles = catalog.profiles()
        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles[0].directory, "Default")
        XCTAssertEqual(profiles[0].name, "Personal")
        XCTAssertEqual(profiles[0].userName, "me@gmail.com")
        XCTAssertEqual(profiles[1].directory, "Profile 1")
        XCTAssertEqual(profiles[1].name, "Work")
        XCTAssertEqual(profiles[1].userName, "me@company.com")
    }

    func testMissingFileReturnsEmpty() {
        let missing = tempDir.appendingPathComponent("Does Not Exist")
        let catalog = ChromeProfileCatalog(localStateURL: missing)
        XCTAssertEqual(catalog.profiles(), [])
    }

    func testMalformedJSONReturnsEmpty() throws {
        let url = try writeFixture("{ this is not json")
        let catalog = ChromeProfileCatalog(localStateURL: url)
        XCTAssertEqual(catalog.profiles(), [])
    }

    func testSortOrderDefaultFirstThenAlphabeticalByName() throws {
        let json = """
        {
          "profile": {
            "info_cache": {
              "Profile 2": { "name": "Zeta", "user_name": null },
              "Default": { "name": "Personal", "user_name": "me@gmail.com" },
              "Profile 1": { "name": "Alpha", "user_name": "me@company.com" },
              "Profile 3": { "name": "Mu", "user_name": "" }
            }
          }
        }
        """
        let url = try writeFixture(json)
        let catalog = ChromeProfileCatalog(localStateURL: url)
        let profiles = catalog.profiles()
        XCTAssertEqual(profiles.map(\.directory), ["Default", "Profile 1", "Profile 3", "Profile 2"])
        XCTAssertNil(profiles.first(where: { $0.directory == "Profile 2" })?.userName)
        XCTAssertNil(profiles.first(where: { $0.directory == "Profile 3" })?.userName)
    }
}
