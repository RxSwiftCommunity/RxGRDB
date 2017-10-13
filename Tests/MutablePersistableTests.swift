import XCTest
import GRDB
import RxSwift
import RxGRDB

class MutablePersistableTests : XCTestCase { }

extension RequestTests {
    func testObserveRecordRowID() throws {
        try Test(testObserveRecordRowID)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testObserveRecordRowID(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        struct Player: MutablePersistable, RowConvertible {
            var id: Int64?
            let name: String
            let score: Int
            
            static let databaseTableName = "players"
            static let databaseSelection: [SQLSelectable] = [Column("id"), Column("name"), Column("score")]
            
            init(row: Row) {
                id = row["id"]
                name = row["name"]
                score = row["score"]
            }
            
            func encode(to container: inout PersistenceContainer) {
                container["id"] = id
                container["name"] = name
                container["score"] = score
            }
            
            mutating func didInsert(with rowID: Int64, for column: String?) {
                id = rowID
            }
        }
        
        var player1 = Player(row: ["name": "Arthur", "score": 500])
        var player2 = Player(row: ["name": "Barbara", "score": 1000])
        var player3 = Player(row: ["name": "Craig", "score": 1500])

        try writer.write { db in
            try db.create(table: "players") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text).notNull()
                t.column("score", .integer).notNull()
                t.column("ignored", .text)
            }
            try player1.insert(db)
            try player2.insert(db)
        }

        let expectedRecords: [Player] = [
            Player(row: ["id": 1, "name": "Arthur", "score": 500]),     // (1)
            Player(row: ["id": 1, "name": "Arthur", "score": 750]),     // (2)
        ]
        let recorder = EventRecorder<Player>(expectedEventCount: expectedRecords.count + 1)
        
        // (1)
        Observable.from(record: player1, in: writer)
            .subscribe { event in
                // events are expected to be delivered on the subscription queue
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try writer.write { db in
            // No change to player1
            try db.execute("UPDATE players SET name = name")
            
            // (2)
            try db.execute("UPDATE players SET score = 750 WHERE id = ?", arguments: [player1.id])
            
            // No change to player1
            try db.execute("UPDATE players SET ignored = ?", arguments: ["foo"])
            try player2.delete(db)
            try player3.insert(db)
            
            // completed
            try db.execute("DELETE FROM players")
            
            // too late
            try player1.insert(db)
        }
        wait(for: recorder, timeout: 1)
        
        for (event, expectedPlayer) in zip(recorder.recordedEvents.prefix(upTo: expectedRecords.count + 1), expectedRecords) {
            XCTAssertEqual(event.element!.id, expectedPlayer.id)
            XCTAssertEqual(event.element!.name, expectedPlayer.name)
            XCTAssertEqual(event.element!.score, expectedPlayer.score)
        }
        switch recorder.recordedEvents.last! {
        case .completed: break
        default: XCTFail("Expected completed event")
        }
    }
}

extension RequestTests {
    func testObserveRecordSingleColumnPrimaryKey() throws {
        try Test(testObserveRecordSingleColumnPrimaryKey)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testObserveRecordSingleColumnPrimaryKey(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        struct Player: Persistable, RowConvertible {
            var id: String
            let name: String
            let score: Int
            
            static let databaseTableName = "players"
            static let databaseSelection: [SQLSelectable] = [Column("id"), Column("name"), Column("score")]

            init(row: Row) {
                id = row["id"]
                name = row["name"]
                score = row["score"]
            }
            
            func encode(to container: inout PersistenceContainer) {
                container["id"] = id
                container["name"] = name
                container["score"] = score
            }
        }
        
        let player1 = Player(row: ["id": "foo", "name": "Arthur", "score": 500])
        let player2 = Player(row: ["id": "bar", "name": "Barbara", "score": 1000])
        let player3 = Player(row: ["id": "baz", "name": "Craig", "score": 1500])
        
        try writer.write { db in
            try db.create(table: "players") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("score", .integer).notNull()
                t.column("ignored", .integer)
            }
            try player1.insert(db)
            try player2.insert(db)
        }
        
        let expectedRecords: [Player] = [
            Player(row: ["id": "foo", "name": "Arthur", "score": 500]),     // (1)
            Player(row: ["id": "foo", "name": "Arthur", "score": 750]),     // (2)
        ]
        let recorder = EventRecorder<Player>(expectedEventCount: expectedRecords.count + 1)
        
        // (1)
        Observable.from(record: player1, in: writer)
            .subscribe { event in
                // events are expected to be delivered on the subscription queue
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try writer.write { db in
            // No change to player1
            try db.execute("UPDATE players SET name = name")
            
            // (2)
            try db.execute("UPDATE players SET score = 750 WHERE id = ?", arguments: [player1.id])
            
            // No change to player1
            try db.execute("UPDATE players SET ignored = ?", arguments: ["foo"])
            try player2.delete(db)
            try player3.insert(db)
            
            // completed
            try db.execute("DELETE FROM players")
            
            // too late
            try player1.insert(db)
        }
        wait(for: recorder, timeout: 1)
        
        for (event, expectedPlayer) in zip(recorder.recordedEvents.prefix(upTo: expectedRecords.count + 1), expectedRecords) {
            XCTAssertEqual(event.element!.id, expectedPlayer.id)
            XCTAssertEqual(event.element!.name, expectedPlayer.name)
            XCTAssertEqual(event.element!.score, expectedPlayer.score)
        }
        switch recorder.recordedEvents.last! {
        case .completed: break
        default: XCTFail("Expected completed event")
        }
    }
}

extension RequestTests {
    func testObserveRecordCompoundPrimaryKey() throws {
        try Test(testObserveRecordCompoundPrimaryKey)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testObserveRecordCompoundPrimaryKey(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        struct Passport: Persistable, RowConvertible {
            var countryCode: String
            let citizenId: Int
            let expired: Bool
            
            static let databaseTableName = "passports"
            static let databaseSelection: [SQLSelectable] = [Column("countryCode"), Column("citizenId"), Column("expired")]

            init(row: Row) {
                countryCode = row["countryCode"]
                citizenId = row["citizenId"]
                expired = row["expired"]
            }
            
            func encode(to container: inout PersistenceContainer) {
                container["countryCode"] = countryCode
                container["citizenId"] = citizenId
                container["expired"] = expired
            }
        }
        
        let passport1 = Passport(row: ["countryCode": "FR", "citizenId": 1, "expired": false])
        let passport2 = Passport(row: ["countryCode": "FR", "citizenId": 2, "expired": false])
        let passport3 = Passport(row: ["countryCode": "US", "citizenId": 1, "expired": true])
        
        try writer.write { db in
            try db.create(table: "passports") { t in
                t.column("countryCode", .text).notNull()
                t.column("citizenId", .integer).notNull()
                t.column("expired", .boolean).notNull()
                t.column("ignored", .integer)
                t.primaryKey(["countryCode", "citizenId"])
            }
            try passport1.insert(db)
            try passport2.insert(db)
        }
        
        let expectedRecords: [Passport] = [
            Passport(row: ["countryCode": "FR", "citizenId": 1, "expired": false]),    // (1)
            Passport(row: ["countryCode": "FR", "citizenId": 1, "expired": true]),     // (2)
        ]
        let recorder = EventRecorder<Passport>(expectedEventCount: expectedRecords.count + 1)
        
        // (1)
        Observable.from(record: passport1, in: writer)
            .subscribe { event in
                // events are expected to be delivered on the subscription queue
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try writer.write { db in
            // No change to passport1
            try db.execute("UPDATE passports SET citizenId = citizenId")
            
            // (2)
            try db.execute("UPDATE passports SET expired = ?", arguments: [true])
            
            // No change to passport1
            try db.execute("UPDATE passports SET ignored = ?", arguments: ["foo"])
            try passport2.delete(db)
            try passport3.insert(db)
            
            // completed
            try db.execute("DELETE FROM passports")
            
            // too late
            try passport1.insert(db)
        }
        wait(for: recorder, timeout: 1)
        
        for (event, expectedPassport) in zip(recorder.recordedEvents.prefix(upTo: expectedRecords.count + 1), expectedRecords) {
            XCTAssertEqual(event.element!.countryCode, expectedPassport.countryCode)
            XCTAssertEqual(event.element!.citizenId, expectedPassport.citizenId)
            XCTAssertEqual(event.element!.expired, expectedPassport.expired)
        }
        switch recorder.recordedEvents.last! {
        case .completed: break
        default: XCTFail("Expected completed event")
        }
    }
}

extension RequestTests {
    func testObserveSingleRecordNilRowIDWithoutSynchronizedStart() throws {
        try Test(testObserveSingleRecordNilRowIDWithoutSynchronizedStart)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testObserveSingleRecordNilRowIDWithoutSynchronizedStart(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        struct Player: MutablePersistable, RowConvertible {
            var id: Int64?
            
            static let databaseTableName = "players"
            
            init(row: Row) {
                id = row["id"]
            }
            
            func encode(to container: inout PersistenceContainer) {
                container["id"] = id
            }
            
            mutating func didInsert(with rowID: Int64, for column: String?) {
                id = rowID
            }
        }
        
        try writer.write { db in
            try db.create(table: "players") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        let recorder = EventRecorder<Player>(expectedEventCount: 1)
        let player = Player(row: ["id": nil])
        Observable.from(record: player, in: writer, synchronizedStart: false)
            .subscribe { event in
                // events are expected to be delivered on the subscription queue
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        wait(for: recorder, timeout: 1)
        
        switch recorder.recordedEvents[0] {
        case .completed: break
        default: XCTFail("Expected completed event")
        }
    }
}

extension RequestTests {
    func testObserveSingleRecordNilRowIDWithSynchronizedStart() throws {
        try Test(testObserveSingleRecordNilRowIDWithSynchronizedStart)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testObserveSingleRecordNilRowIDWithSynchronizedStart(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        struct Player: MutablePersistable, RowConvertible {
            var id: Int64?
            
            static let databaseTableName = "players"
            
            init(row: Row) {
                id = row["id"]
            }
            
            func encode(to container: inout PersistenceContainer) {
                container["id"] = id
            }
            
            mutating func didInsert(with rowID: Int64, for column: String?) {
                id = rowID
            }
        }
        
        try writer.write { db in
            try db.create(table: "players") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        let recorder = EventRecorder<Player>(expectedEventCount: 2)
        let player = Player(row: ["id": nil])
        Observable.from(record: player, in: writer, synchronizedStart: true)
            .subscribe { event in
                // events are expected to be delivered on the subscription queue
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        wait(for: recorder, timeout: 1)
        
        switch recorder.recordedEvents[0] {
        case .next: break
        default: XCTFail("Expected next event")
        }
        
        switch recorder.recordedEvents[1] {
        case .completed: break
        default: XCTFail("Expected completed event")
        }
    }
}

extension RequestTests {
    func testObserveRecordNilSingleColumnPrimaryKeyWithSynchronizedStart() throws {
        try Test(testObserveRecordNilSingleColumnPrimaryKeyWithSynchronizedStart)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testObserveRecordNilSingleColumnPrimaryKeyWithSynchronizedStart(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        struct Player: Persistable, RowConvertible {
            var id: String?
            
            static let databaseTableName = "players"
            
            init(row: Row) {
                id = row["id"]
            }
            
            func encode(to container: inout PersistenceContainer) {
                container["id"] = id
            }
        }
        
        try writer.write { db in
            try db.create(table: "players") { t in
                t.column("id", .text).primaryKey()
            }
        }
        
        let recorder = EventRecorder<Player>(expectedEventCount: 2)
        
        // (1)
        let player = Player(row: ["id": nil])
        Observable.from(record: player, in: writer, synchronizedStart: true)
            .subscribe { event in
                // events are expected to be delivered on the subscription queue
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        wait(for: recorder, timeout: 1)
        
        switch recorder.recordedEvents[0] {
        case .next: break
        default: XCTFail("Expected next event")
        }

        switch recorder.recordedEvents[1] {
        case .completed: break
        default: XCTFail("Expected completed event")
        }
    }
}

extension RequestTests {
    func testObserveRecordNilSingleColumnPrimaryKeyWithoutSynchronizedStart() throws {
        try Test(testObserveRecordNilSingleColumnPrimaryKeyWithoutSynchronizedStart)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testObserveRecordNilSingleColumnPrimaryKeyWithoutSynchronizedStart(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        struct Player: Persistable, RowConvertible {
            var id: String?
            
            static let databaseTableName = "players"
            
            init(row: Row) {
                id = row["id"]
            }
            
            func encode(to container: inout PersistenceContainer) {
                container["id"] = id
            }
        }
        
        try writer.write { db in
            try db.create(table: "players") { t in
                t.column("id", .text).primaryKey()
            }
        }
        
        let recorder = EventRecorder<Player>(expectedEventCount: 1)
        
        // (1)
        let player = Player(row: ["id": nil])
        Observable.from(record: player, in: writer, synchronizedStart: false)
            .subscribe { event in
                // events are expected to be delivered on the subscription queue
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        wait(for: recorder, timeout: 1)
        
        switch recorder.recordedEvents[0] {
        case .completed: break
        default: XCTFail("Expected completed event")
        }
    }
}

extension RequestTests {
    func testObserveRecordNilCompoundPrimaryKeyWithSynchronizedStart() throws {
        try Test(testObserveRecordNilCompoundPrimaryKeyWithSynchronizedStart)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testObserveRecordNilCompoundPrimaryKeyWithSynchronizedStart(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        struct Passport: Persistable, RowConvertible {
            var countryCode: String?
            let citizenId: Int?
            
            static let databaseTableName = "passports"
            
            init(row: Row) {
                countryCode = row["countryCode"]
                citizenId = row["citizenId"]
            }
            
            func encode(to container: inout PersistenceContainer) {
                container["countryCode"] = countryCode
                container["citizenId"] = citizenId
            }
        }
        
        try writer.write { db in
            try db.create(table: "passports") { t in
                t.column("countryCode", .text).notNull()
                t.column("citizenId", .integer).notNull()
                t.primaryKey(["countryCode", "citizenId"])
            }
        }
        
        let recorder = EventRecorder<Passport>(expectedEventCount: 2)
        let passport = Passport(row: ["countryCode": nil, "citizenId": nil])
        Observable.from(record: passport, in: writer, synchronizedStart: true)
            .subscribe { event in
                // events are expected to be delivered on the subscription queue
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        wait(for: recorder, timeout: 1)
        
        switch recorder.recordedEvents[0] {
        case .next: break
        default: XCTFail("Expected next event")
        }

        switch recorder.recordedEvents[1] {
        case .completed: break
        default: XCTFail("Expected completed event")
        }
    }
}

extension RequestTests {
    func testObserveRecordNilCompoundPrimaryKeyWithoutSynchronizedStart() throws {
        try Test(testObserveRecordNilCompoundPrimaryKeyWithoutSynchronizedStart)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testObserveRecordNilCompoundPrimaryKeyWithoutSynchronizedStart(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        struct Passport: Persistable, RowConvertible {
            var countryCode: String?
            let citizenId: Int?
            
            static let databaseTableName = "passports"
            
            init(row: Row) {
                countryCode = row["countryCode"]
                citizenId = row["citizenId"]
            }
            
            func encode(to container: inout PersistenceContainer) {
                container["countryCode"] = countryCode
                container["citizenId"] = citizenId
            }
        }
        
        try writer.write { db in
            try db.create(table: "passports") { t in
                t.column("countryCode", .text).notNull()
                t.column("citizenId", .integer).notNull()
                t.primaryKey(["countryCode", "citizenId"])
            }
        }
        
        let recorder = EventRecorder<Passport>(expectedEventCount: 1)
        let passport = Passport(row: ["countryCode": nil, "citizenId": nil])
        Observable.from(record: passport, in: writer, synchronizedStart: false)
            .subscribe { event in
                // events are expected to be delivered on the subscription queue
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        wait(for: recorder, timeout: 1)
        
        switch recorder.recordedEvents[0] {
        case .completed: break
        default: XCTFail("Expected completed event")
        }
    }
}
