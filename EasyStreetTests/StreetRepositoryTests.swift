import XCTest
@testable import EasyStreet

class StreetRepositoryTests: XCTestCase {

    let repo = StreetRepository.shared

    // MARK: - parseCoordinatesJSON Tests

    func testParseCoordinatesValid() {
        let result = repo.parseCoordinatesJSON("[[37.78,-122.41],[37.79,-122.42]]")
        XCTAssertEqual(result.count, 2, "Should parse 2 coordinates")
        XCTAssertEqual(result[0][0], 37.78, accuracy: 0.001)
        XCTAssertEqual(result[0][1], -122.41, accuracy: 0.001)
    }

    func testParseCoordinatesEmpty() {
        let result = repo.parseCoordinatesJSON("[]")
        XCTAssertTrue(result.isEmpty, "Empty array JSON should return empty")
    }

    func testParseCoordinatesEmptyString() {
        let result = repo.parseCoordinatesJSON("")
        XCTAssertTrue(result.isEmpty, "Empty string should return empty")
    }

    func testParseCoordinatesInvalidJSON() {
        let result = repo.parseCoordinatesJSON("not json")
        XCTAssertTrue(result.isEmpty, "Invalid JSON should return empty")
    }

    func testParseCoordinatesWrongType() {
        let result = repo.parseCoordinatesJSON("[1,2,3]")
        XCTAssertTrue(result.isEmpty, "Flat array (wrong type) should return empty")
    }

    func testParseCoordinatesSingle() {
        let result = repo.parseCoordinatesJSON("[[37.78,-122.41]]")
        XCTAssertEqual(result.count, 1, "Should parse single coordinate")
    }

    func testParseCoordinatesMalformedInner() {
        let result = repo.parseCoordinatesJSON("[[37.78]]")
        XCTAssertEqual(result.count, 1, "Should parse inner array with 1 element")
        XCTAssertEqual(result[0].count, 1, "Inner array should have 1 element")
    }

    // MARK: - parseWeeksJSON Tests

    func testParseWeeksValid() {
        let result = repo.parseWeeksJSON("[1,3]")
        XCTAssertEqual(result, [1, 3])
    }

    func testParseWeeksEmpty() {
        let result = repo.parseWeeksJSON("[]")
        XCTAssertTrue(result.isEmpty, "Empty array JSON should return empty")
    }

    func testParseWeeksEmptyString() {
        let result = repo.parseWeeksJSON("")
        XCTAssertTrue(result.isEmpty, "Empty string should return empty")
    }

    func testParseWeeksInvalidJSON() {
        let result = repo.parseWeeksJSON("bad")
        XCTAssertTrue(result.isEmpty, "Invalid JSON should return empty")
    }

    func testParseWeeksAllFive() {
        let result = repo.parseWeeksJSON("[1,2,3,4,5]")
        XCTAssertEqual(result, [1, 2, 3, 4, 5])
    }

    func testParseWeeksNegative() {
        let result = repo.parseWeeksJSON("[-1,0,6]")
        XCTAssertEqual(result, [-1, 0, 6], "Should pass through values without validation")
    }

    func testParseWeeksStringArray() {
        let result = repo.parseWeeksJSON("[\"a\",\"b\"]")
        XCTAssertTrue(result.isEmpty, "String array should return empty (not [Int])")
    }
}
