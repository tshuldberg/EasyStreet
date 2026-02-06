package com.easystreet.data.db

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.io.FileOutputStream

class DatabaseInitException(message: String, cause: Throwable? = null) : Exception(message, cause)

class StreetDatabase(private val context: Context) {

    val database: SQLiteDatabase by lazy {
        try {
            copyDatabaseIfNeeded()
            SQLiteDatabase.openDatabase(
                getDatabasePath().absolutePath,
                null,
                SQLiteDatabase.OPEN_READONLY,
            )
        } catch (e: Exception) {
            throw DatabaseInitException("Failed to open street database: ${e.message}", e)
        }
    }

    private fun getDatabasePath(): File {
        return context.getDatabasePath(dbName)
    }

    private fun copyDatabaseIfNeeded() {
        val dbFile = getDatabasePath()
        if (dbFile.exists()) return

        dbFile.parentFile?.mkdirs()

        context.assets.open(dbName).use { input ->
            FileOutputStream(dbFile).use { output ->
                input.copyTo(output)
            }
        }
    }

    companion object {
        private const val dbName = "easystreet.db"
    }
}
