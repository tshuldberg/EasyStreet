package com.easystreet.data.db

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.io.FileOutputStream

class StreetDatabase(private val context: Context) {

    private val dbName = "easystreet.db"

    val database: SQLiteDatabase by lazy {
        copyDatabaseIfNeeded()
        SQLiteDatabase.openDatabase(
            getDatabasePath().absolutePath,
            null,
            SQLiteDatabase.OPEN_READONLY,
        )
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
}
