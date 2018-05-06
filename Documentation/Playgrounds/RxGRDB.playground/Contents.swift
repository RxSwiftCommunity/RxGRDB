//: To run this playground:
//:
//: - Run `pod install` in the terminal
//: - Open RxGRDB.xcworkspace
//: - Select the RxGRDBmacOS scheme: menu Product > Scheme > RxGRDBmacOS
//: - Build: menu Product > Build
//: - Select the playground in the Playgrounds Group
//: - Run the playground
import GRDB
import RxGRDB
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

//: Create a database:
let dbQueue = DatabaseQueue()
try dbQueue.write { db in
    try db.create(table: "player") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("name", .text).notNull()
        t.column("score", .integer).notNull()
    }
}

//: Define a Player record:
struct Player: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var name: String
    var score: Int
    
    static let databaseTableName = "player"
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

//: Track the number of players:
Player.all().rx
    .fetchCount(in: dbQueue)
    .subscribe(onNext: { count in
        print("Number of players: \(count)")
    })

//: Modify the database:
try dbQueue.write { db in
    var player = Player(id: nil, name: "Arthur", score: 100)
    try player.insert(db)
}

try dbQueue.write { db in
    var player = Player(id: nil, name: "Barbara", score: 250)
    try player.insert(db)
    player = Player(id: nil, name: "Craig", score: 150)
    try player.insert(db)
}
