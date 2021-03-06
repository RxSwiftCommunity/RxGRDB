import UIKit
import GRDB

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Setup the Current World
        let dbPool = try! setupDatabase(application)
        Current = World(database: { dbPool })
        
        // Application is nicer looking if it starts populated
        try! Current.players().populateIfEmpty()
        
        return true
    }
    
    private func setupDatabase(_ application: UIApplication) throws -> DatabasePool {
        // Create a DatabasePool for efficient multi-threading
        let databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("db.sqlite")
        let dbPool = try DatabasePool(path: databaseURL.path)
        
        // Setup the database
        try AppDatabase().setup(dbPool)
        
        return dbPool
    }
}
