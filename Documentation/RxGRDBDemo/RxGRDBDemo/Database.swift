import UIKit
import GRDB
import CoreLocation

func openDatabase(_ application: UIApplication) throws -> DatabasePool {
    // Connect to the database
    // See https://github.com/groue/GRDB.swift/#database-connections
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
    let databasePath = documentsPath.appendingPathComponent("db.sqlite")
    let dbPool = try DatabasePool(path: databasePath)
    
    // Be a nice iOS citizen, and don't consume too much memory
    // See https://github.com/groue/GRDB.swift/#memory-management
    dbPool.setupMemoryManagement(in: application)
    
    // Use DatabaseMigrator to setup the database
    // See https://github.com/groue/GRDB.swift/#migrations
    try databaseMigrator.migrate(dbPool)
    
    return dbPool
}

var databaseMigrator: DatabaseMigrator {
    var migrator = DatabaseMigrator()
    
    migrator.registerMigration("v1.0") { db in
        try db.create(table: "players") { t in
            t.column("id", .integer).primaryKey()
            t.column("name", .text).notNull().collate(.localizedCaseInsensitiveCompare)
            t.column("score", .integer).notNull()
        }
    }
    
    migrator.registerMigration("fixtures") { db in
        for _ in 0..<10 {
            var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
            try player.insert(db)
        }
    }
    
    return migrator
}
