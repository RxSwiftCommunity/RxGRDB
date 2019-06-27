import GRDB

/// A type responsible for initializing an application database.
struct AppDatabase {
    
    /// Prepares a fully initialized database at path
    func setup(_ database: DatabaseWriter) throws {
        // Use DatabaseMigrator to define the database schema
        // See https://github.com/groue/GRDB.swift/#migrations
        try migrator.migrate(database)
        
        // Other possible setup include: custom functions, collations,
        // full-text tokenizers, etc.
    }
    
    /// The DatabaseMigrator that defines the database schema.
    // See https://github.com/groue/GRDB.swift/#migrations
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        #if DEBUG
        // Speed up development by nuking the database when migrations change
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        
        migrator.registerMigration("v1.0") { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull().collate(.localizedCaseInsensitiveCompare)
                t.column("score", .integer).notNull()
            }
            
            try db.create(table: "place") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
            }
        }
        
        return migrator
    }
}
