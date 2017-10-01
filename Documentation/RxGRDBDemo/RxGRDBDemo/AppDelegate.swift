import UIKit
import GRDB
import RxSwift

var dbPool: DatabasePool!

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let disposeBag = DisposeBag()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        dbPool = try! openDatabase(application)
        return true
    }
}
