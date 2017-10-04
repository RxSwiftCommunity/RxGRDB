import UIKit
import GRDB

// The shared database pool
var dbPool: DatabasePool!

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        try! setupDatabase(application)
        return true
    }
    
    private func setupDatabase(_ application: UIApplication) throws {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString
        let databasePath = documentsPath.appendingPathComponent("db.sqlite")
        dbPool = try AppDatabase.openDatabase(atPath: databasePath)
        
        // Be a nice iOS citizen, and don't consume too much memory
        // See https://github.com/groue/GRDB.swift/#memory-management
        dbPool.setupMemoryManagement(in: application)
    }
}
