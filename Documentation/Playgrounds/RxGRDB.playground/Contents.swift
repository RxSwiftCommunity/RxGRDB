//: Playground - noun: a place where people can play

import GRDB
import RxGRDB

let dbQueue = DatabaseQueue()
try dbQueue.inDatabase { db in
    try db.create(table: "persons") { t in
        t.column("id", .integer).primaryKey()
        t.column("name", .text)
    }
}

let request = SQLRequest("SELECT * FROM persons")
request.rx
    .changes(in: dbQueue)
    .subscribe(onNext: { db in
        let count = try! request.fetchCount(db)
        print("Number of persons: \(count)")
    })
// Prints "Number of persons: 0"

try dbQueue.inDatabase { db in
    try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
    // Prints "Number of persons: 1"
    try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Barbara"])
    // Prints "Number of persons: 2"
}

try dbQueue.inTransaction { db in
    try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Craig"])
    try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["David"])
    return .commit
}
// Prints "Number of persons: 4"
