import GRDB

/// A type responsible for initializing the application database.
///
/// See AppDelegate.setupDatabase()
struct AppDatabase {
    
    /// Creates a fully initialized database at path
    static func openDatabase(atPath path: String) throws -> DatabasePool {
        // Connect to the database
        // See https://github.com/groue/GRDB.swift/#database-connections
        let dbPool = try DatabasePool(path: path)
        
        // Use DatabaseMigrator to define the database schema
        // See https://github.com/groue/GRDB.swift/#migrations
        try migrator.migrate(dbPool)
        
        return dbPool
    }
    
    /// The DatabaseMigrator that defines the database schema.
    // See https://github.com/groue/GRDB.swift/#migrations
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("v1.0") { db in
            try db.create(table: "players") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text).notNull().collate(.localizedCaseInsensitiveCompare)
                t.column("score", .integer).notNull()
            }
            
            try db.create(table: "places") { t in
                t.column("id", .integer).primaryKey()
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
            }
        }
        
        migrator.registerMigration("fixtures") { db in
            for _ in 0..<10 {
                var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                try player.insert(db)
            }
            for _ in 0..<10 {
                var place = Place(id: nil, coordinate: Place.randomCoordinate())
                try place.insert(db)
            }
        }
        
        return migrator
    }
}
