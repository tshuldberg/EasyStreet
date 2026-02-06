import XCTest
import SQLite3
@testable import EasyStreet

class DatabaseManagerTests: XCTestCase {

    var dbManager: DatabaseManager!

    override func setUp() {
        super.setUp()
        dbManager = DatabaseManager()
    }

    override func tearDown() {
        dbManager.close()
        dbManager = nil
        super.tearDown()
    }

    // MARK: - Open / Close Tests

    func testOpenInMemorySucceeds() {
        XCTAssertNoThrow(try dbManager.open(at: ":memory:"),
                         "Opening an in-memory database should not throw")
    }

    func testQueryOnClosedDatabaseThrows() {
        // dbManager has NOT been opened
        XCTAssertThrowsError(try dbManager.query("SELECT 1") { _ in }) { error in
            guard let dbError = error as? DatabaseError else {
                XCTFail("Expected DatabaseError, got \(error)")
                return
            }
            if case .queryFailed(let msg) = dbError {
                XCTAssertTrue(msg.contains("not open"),
                              "Error should mention database not open, got: \(msg)")
            } else {
                XCTFail("Expected queryFailed, got \(dbError)")
            }
        }
    }

    func testOpenTwiceDoesNotThrow() {
        XCTAssertNoThrow(try dbManager.open(at: ":memory:"))
        XCTAssertNoThrow(try dbManager.open(at: ":memory:"),
                         "Opening an already-open database should be idempotent")
    }

    func testCloseAndReopenWorks() {
        XCTAssertNoThrow(try dbManager.open(at: ":memory:"))
        dbManager.close()
        XCTAssertNoThrow(try dbManager.open(at: ":memory:"),
                         "Should be able to reopen after closing")
        // Verify it works after reopen
        var count = 0
        XCTAssertNoThrow(try dbManager.query("SELECT 1") { _ in count += 1 })
        XCTAssertEqual(count, 1)
    }

    // MARK: - Query Tests

    func testSimpleSelectQuery() throws {
        try dbManager.open(at: ":memory:")
        try dbManager.query("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)") { _ in }
        try dbManager.query("INSERT INTO test (id, name) VALUES (1, 'hello')") { _ in }

        var resultName = ""
        try dbManager.query("SELECT name FROM test WHERE id = 1") { stmt in
            resultName = DatabaseManager.string(from: stmt, column: 0)
        }
        XCTAssertEqual(resultName, "hello")
    }

    func testParameterBindingString() throws {
        try dbManager.open(at: ":memory:")
        try dbManager.query("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)") { _ in }
        try dbManager.query("INSERT INTO test (id, name) VALUES (1, 'alice')") { _ in }
        try dbManager.query("INSERT INTO test (id, name) VALUES (2, 'bob')") { _ in }

        var resultID = 0
        try dbManager.query("SELECT id FROM test WHERE name = ?", parameters: ["bob"]) { stmt in
            resultID = DatabaseManager.int(from: stmt, column: 0)
        }
        XCTAssertEqual(resultID, 2)
    }

    func testParameterBindingInt() throws {
        try dbManager.open(at: ":memory:")
        try dbManager.query("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)") { _ in }
        try dbManager.query("INSERT INTO test (id, name) VALUES (42, 'answer')") { _ in }

        var resultName = ""
        try dbManager.query("SELECT name FROM test WHERE id = ?", parameters: [42]) { stmt in
            resultName = DatabaseManager.string(from: stmt, column: 0)
        }
        XCTAssertEqual(resultName, "answer")
    }

    func testParameterBindingDouble() throws {
        try dbManager.open(at: ":memory:")
        try dbManager.query("CREATE TABLE test (id INTEGER PRIMARY KEY, val REAL)") { _ in }
        try dbManager.query("INSERT INTO test (id, val) VALUES (1, 3.14)") { _ in }
        try dbManager.query("INSERT INTO test (id, val) VALUES (2, 2.72)") { _ in }

        var resultID = 0
        try dbManager.query("SELECT id FROM test WHERE val = ?", parameters: [3.14]) { stmt in
            resultID = DatabaseManager.int(from: stmt, column: 0)
        }
        XCTAssertEqual(resultID, 1)
    }

    func testUnsupportedParameterTypeThrows() throws {
        try dbManager.open(at: ":memory:")
        try dbManager.query("CREATE TABLE test (id INTEGER PRIMARY KEY, flag INTEGER)") { _ in }

        XCTAssertThrowsError(
            try dbManager.query("INSERT INTO test (id, flag) VALUES (1, ?)", parameters: [true]) { _ in }
        ) { error in
            guard let dbError = error as? DatabaseError else {
                XCTFail("Expected DatabaseError, got \(error)")
                return
            }
            if case .queryFailed(let msg) = dbError {
                XCTAssertTrue(msg.contains("Unsupported parameter type"),
                              "Error should mention unsupported type, got: \(msg)")
            } else {
                XCTFail("Expected queryFailed, got \(dbError)")
            }
        }
    }

    func testInvalidSQLThrows() throws {
        try dbManager.open(at: ":memory:")

        XCTAssertThrowsError(
            try dbManager.query("SELETC * FORM nonexistent") { _ in }
        ) { error in
            guard let dbError = error as? DatabaseError else {
                XCTFail("Expected DatabaseError, got \(error)")
                return
            }
            if case .queryFailed = dbError {
                // Expected
            } else {
                XCTFail("Expected queryFailed, got \(dbError)")
            }
        }
    }

    // MARK: - Column Accessor Tests

    func testColumnAccessorString() throws {
        try dbManager.open(at: ":memory:")
        try dbManager.query("CREATE TABLE test (name TEXT)") { _ in }
        try dbManager.query("INSERT INTO test (name) VALUES ('world')") { _ in }

        var result = ""
        try dbManager.query("SELECT name FROM test") { stmt in
            result = DatabaseManager.string(from: stmt, column: 0)
        }
        XCTAssertEqual(result, "world")
    }

    func testColumnAccessorInt() throws {
        try dbManager.open(at: ":memory:")
        try dbManager.query("CREATE TABLE test (val INTEGER)") { _ in }
        try dbManager.query("INSERT INTO test (val) VALUES (99)") { _ in }

        var result = 0
        try dbManager.query("SELECT val FROM test") { stmt in
            result = DatabaseManager.int(from: stmt, column: 0)
        }
        XCTAssertEqual(result, 99)
    }

    func testColumnAccessorDouble() throws {
        try dbManager.open(at: ":memory:")
        try dbManager.query("CREATE TABLE test (val REAL)") { _ in }
        try dbManager.query("INSERT INTO test (val) VALUES (1.618)") { _ in }

        var result = 0.0
        try dbManager.query("SELECT val FROM test") { stmt in
            result = DatabaseManager.double(from: stmt, column: 0)
        }
        XCTAssertEqual(result, 1.618, accuracy: 0.0001)
    }

    func testNullColumnReturnsEmpty() throws {
        try dbManager.open(at: ":memory:")
        try dbManager.query("CREATE TABLE test (name TEXT)") { _ in }
        try dbManager.query("INSERT INTO test (name) VALUES (NULL)") { _ in }

        var result = "non-empty"
        try dbManager.query("SELECT name FROM test") { stmt in
            result = DatabaseManager.string(from: stmt, column: 0)
        }
        XCTAssertEqual(result, "", "NULL text column should return empty string")
    }

    func testMultipleRowsIterated() throws {
        try dbManager.open(at: ":memory:")
        try dbManager.query("CREATE TABLE test (id INTEGER PRIMARY KEY)") { _ in }
        for i in 1...5 {
            try dbManager.query("INSERT INTO test (id) VALUES (\(i))") { _ in }
        }

        var rowCount = 0
        try dbManager.query("SELECT id FROM test") { _ in
            rowCount += 1
        }
        XCTAssertEqual(rowCount, 5, "Should iterate over all 5 rows")
    }
}
