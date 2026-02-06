import Foundation
import SQLite3

// MARK: - Database Errors

enum DatabaseError: Error, LocalizedError {
    case openFailed(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            return "Database open failed: \(message)"
        case .queryFailed(let message):
            return "Database query failed: \(message)"
        }
    }
}

// MARK: - DatabaseManager

class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.easystreet.databasemanager", qos: .userInitiated)

    init() {}

    deinit {
        close()
    }

    // MARK: - Open / Close

    /// Opens the bundled easystreet.db in read-only mode.
    func open() throws {
        try dbQueue.sync {
            // Don't reopen if already open
            if db != nil {
                #if DEBUG
                print("[EasyStreet] DatabaseManager: already open")
                #endif
                return
            }

            guard let dbPath = Bundle.main.path(forResource: "easystreet", ofType: "db") else {
                #if DEBUG
                print("[EasyStreet] DatabaseManager: easystreet.db NOT FOUND in bundle")
                #endif
                throw DatabaseError.openFailed(
                    "easystreet.db not found in app bundle. "
                    + "Ensure the database file is included in the Xcode project's Copy Bundle Resources build phase."
                )
            }
            #if DEBUG
            print("[EasyStreet] DatabaseManager: opening database at \(dbPath)")
            #endif

            var dbPointer: OpaquePointer?
            let flags = SQLITE_OPEN_READONLY
            let result = sqlite3_open_v2(dbPath, &dbPointer, flags, nil)

            if result != SQLITE_OK {
                let message: String
                if let errorPointer = sqlite3_errmsg(dbPointer) {
                    message = String(cString: errorPointer)
                } else {
                    message = "Unknown error (code \(result))"
                }
                // Clean up on failure
                sqlite3_close(dbPointer)
                throw DatabaseError.openFailed(message)
            }

            db = dbPointer
        }
    }

    /// Opens a database at the given file-system path (for testing).
    /// Uses READWRITE | CREATE flags so in-memory databases work.
    func open(at path: String) throws {
        try dbQueue.sync {
            if db != nil {
                return
            }

            var dbPointer: OpaquePointer?
            let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
            let result = sqlite3_open_v2(path, &dbPointer, flags, nil)

            if result != SQLITE_OK {
                let message: String
                if let errorPointer = sqlite3_errmsg(dbPointer) {
                    message = String(cString: errorPointer)
                } else {
                    message = "Unknown error (code \(result))"
                }
                sqlite3_close(dbPointer)
                throw DatabaseError.openFailed(message)
            }

            db = dbPointer
        }
    }

    /// Closes the database connection if open.
    func close() {
        dbQueue.sync {
            if let db = db {
                sqlite3_close(db)
                self.db = nil
            }
        }
    }

    // MARK: - Query Execution

    /// Execute a SQL query with optional parameter binding.
    ///
    /// Parameters are bound positionally and support `String`, `Int`, and `Double` types.
    /// The `rowHandler` closure is called once for each result row, receiving the prepared
    /// statement pointer so callers can extract column values using the static helper methods.
    ///
    /// - Parameters:
    ///   - sql: The SQL query string with `?` placeholders for parameters.
    ///   - parameters: An array of values to bind. Supported types: `String`, `Int`, `Double`.
    ///   - rowHandler: A closure invoked for each result row with the statement pointer.
    /// - Throws: `DatabaseError.queryFailed` if preparation or execution fails.
    func query(_ sql: String, parameters: [Any] = [], rowHandler: (OpaquePointer) -> Void) throws {
        try dbQueue.sync {
            guard let db = db else {
                throw DatabaseError.queryFailed("Database is not open. Call open() first.")
            }

            var stmt: OpaquePointer?
            let prepareResult = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)

            guard prepareResult == SQLITE_OK, let statement = stmt else {
                let message: String
                if let errorPointer = sqlite3_errmsg(db) {
                    message = String(cString: errorPointer)
                } else {
                    message = "Unknown error (code \(prepareResult))"
                }
                sqlite3_finalize(stmt)
                throw DatabaseError.queryFailed("Failed to prepare statement: \(message)")
            }

            defer {
                sqlite3_finalize(statement)
            }

            // Bind parameters
            for (index, param) in parameters.enumerated() {
                let bindIndex = Int32(index + 1) // SQLite parameters are 1-indexed

                var bindResult: Int32
                if let stringValue = param as? String {
                    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                    bindResult = sqlite3_bind_text(statement, bindIndex, (stringValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else if let intValue = param as? Int {
                    bindResult = sqlite3_bind_int64(statement, bindIndex, Int64(intValue))
                } else if let doubleValue = param as? Double {
                    bindResult = sqlite3_bind_double(statement, bindIndex, doubleValue)
                } else {
                    throw DatabaseError.queryFailed(
                        "Unsupported parameter type at index \(index). "
                        + "Only String, Int, and Double are supported."
                    )
                }

                if bindResult != SQLITE_OK {
                    let message: String
                    if let errorPointer = sqlite3_errmsg(db) {
                        message = String(cString: errorPointer)
                    } else {
                        message = "Unknown error (code \(bindResult))"
                    }
                    throw DatabaseError.queryFailed("Failed to bind parameter at index \(index): \(message)")
                }
            }

            // Step through results
            while sqlite3_step(statement) == SQLITE_ROW {
                rowHandler(statement)
            }
        }
    }

    // MARK: - Metadata

    /// Retrieve a value from the metadata table.
    /// Note: This method acquires dbQueue internally, so it must NOT be called
    /// from within an existing dbQueue.sync block.
    func metadataValue(for key: String) -> String? {
        guard db != nil else { return nil }
        var result: String?
        try? query("SELECT value FROM metadata WHERE key = ?", parameters: [key]) { stmt in
            result = DatabaseManager.string(from: stmt, column: 0)
        }
        return result
    }

    // MARK: - Column Accessors

    /// Extract a String value from the given column of a result row.
    ///
    /// - Parameters:
    ///   - stmt: The prepared statement pointer (from the rowHandler callback).
    ///   - column: The zero-based column index.
    /// - Returns: The column value as a String, or an empty string if NULL.
    static func string(from stmt: OpaquePointer, column: Int32) -> String {
        if let cString = sqlite3_column_text(stmt, column) {
            return String(cString: cString)
        }
        return ""
    }

    /// Extract a Double value from the given column of a result row.
    ///
    /// - Parameters:
    ///   - stmt: The prepared statement pointer (from the rowHandler callback).
    ///   - column: The zero-based column index.
    /// - Returns: The column value as a Double.
    static func double(from stmt: OpaquePointer, column: Int32) -> Double {
        return sqlite3_column_double(stmt, column)
    }

    /// Extract an Int value from the given column of a result row.
    ///
    /// - Parameters:
    ///   - stmt: The prepared statement pointer (from the rowHandler callback).
    ///   - column: The zero-based column index.
    /// - Returns: The column value as an Int.
    static func int(from stmt: OpaquePointer, column: Int32) -> Int {
        return Int(sqlite3_column_int(stmt, column))
    }
}
