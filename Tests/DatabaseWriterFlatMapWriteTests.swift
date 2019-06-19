import GRDB
import RxBlocking
import RxGRDB
import RxSwift
import XCTest

private struct Player: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    var name: String
    var score: Int?
    
    static func createTable(_ db: Database) throws {
        try db.create(table: "player") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("score", .integer)
        }
    }
}

class DatabaseWriterFlatMapWriteTests : XCTestCase { }

extension DatabaseWriterFlatMapWriteTests {
    func testRxFlatMapWrite() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        try Test(testRxFlatMapWrite).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxFlatMapWrite).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxFlatMapWrite<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let observable: Observable<Int> = writer.rx.flatMapWrite { db in
            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            let newPlayerCount = try Player.fetchCount(db)
            return Observable.just(newPlayerCount)
        }
        try XCTAssertEqual(writer.read(Player.fetchCount), 0)
        let count = try observable.toBlocking(timeout: 1).single()
        XCTAssertEqual(count, 1)
    }
}

@available(OSX 10.12, iOS 10.0, watchOS 3.0, *)
extension DatabaseWriterWriteTests {
    func testRxFlatMapWriteScheduler() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
            }
            return writer
        }
        try Test(testRxFlatMapWriteScheduler).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxFlatMapWriteScheduler).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxFlatMapWriteScheduler<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        do {
            let queue = DispatchQueue(label: "test")
            let single = writer.rx
                .flatMapWrite { db -> Observable<Int> in
                    try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                    let newPlayerCount = try Player.fetchCount(db)
                    return Observable
                        .just(newPlayerCount)
                        .observeOn(SerialDispatchQueueScheduler(queue: queue, internalSerialQueueName: "test"))
                }
                .do(onNext: { _ in
                    dispatchPrecondition(condition: .onQueue(.main))
                })
            _ = try single.toBlocking(timeout: 1).single()
        }
        do {
            let queue = DispatchQueue(label: "test")
            let single = writer.rx
                .flatMapWrite(
                    observeOn: SerialDispatchQueueScheduler(queue: queue, internalSerialQueueName: "test"),
                    updates: { db -> Observable<Int> in
                        try Player(id: 2, name: "Barbara", score: nil).insert(db)
                        let newPlayerCount = try Player.fetchCount(db)
                        return Observable.just(newPlayerCount)
                })
                .do(onNext: { _ in
                    dispatchPrecondition(condition: .onQueue(queue))
                })
            _ = try single.toBlocking(timeout: 1).single()
        }
    }
}

extension DatabaseWriterFlatMapWriteTests {
    func testRxFlatMapWriteIsAsynchronous() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
            }
            return writer
        }
        try Test(testRxFlatMapWriteIsAsynchronous).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxFlatMapWriteIsAsynchronous).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxFlatMapWriteIsAsynchronous<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let observable: Observable<Int> = writer.rx.flatMapWrite { db in
            // Make sure this block executes asynchronously
            semaphore.wait()
            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            let newPlayerCount = try Player.fetchCount(db)
            return Observable.just(newPlayerCount)
        }
        
        let count = try observable
            .asObservable()
            .do(onSubscribed: {
                semaphore.signal()
            })
            .toBlocking(timeout: 1)
            .single()
        XCTAssertEqual(count, 1)
    }
}

extension DatabaseWriterFlatMapWriteTests {
    func testRxFlatMapWriteSingle() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        try Test(testRxFlatMapWriteSingle).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxFlatMapWriteSingle).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxFlatMapWriteSingle<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let single: Single<Int> = writer.rx.flatMapWrite { db in
            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            let newPlayerCount = try Player.fetchCount(db)
            return Single.just(newPlayerCount)
        }
        try XCTAssertEqual(writer.read(Player.fetchCount), 0)
        let count = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(count, 1)
    }
}

extension DatabaseWriterFlatMapWriteTests {
    func testRxFlatMapWriteConcurrentRead() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        try Test(testRxFlatMapWriteConcurrentRead).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxFlatMapWriteConcurrentRead).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxFlatMapWriteConcurrentRead<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let single: Single<Int> = writer.rx.flatMapWrite { db in
            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            return writer.rx.concurrentRead { db in
                try Player.fetchCount(db)
            }
        }
        try XCTAssertEqual(writer.read(Player.fetchCount), 0)
        let count = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(count, 1)
    }
}
