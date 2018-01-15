RxGRDB [![Swift](https://img.shields.io/badge/swift-4-orange.svg?style=flat)](https://developer.apple.com/swift/) [![Platforms](https://img.shields.io/cocoapods/p/RxGRDB.svg)](https://developer.apple.com/swift/) [![License](https://img.shields.io/github/license/RxSwiftCommunity/RxGRDB.svg?maxAge=2592000)](/LICENSE) [![Build Status](https://travis-ci.org/RxSwiftCommunity/RxGRDB.svg?branch=master)](https://travis-ci.org/RxSwiftCommunity/RxGRDB)
======

### A set of reactive extensions for SQLite and [GRDB.swift](http://github.com/groue/GRDB.swift)

**Latest release**: October 18, 2017 &bull; version 0.7.0 &bull; [Release Notes](CHANGELOG.md)

**Requirements**: iOS 8.0+ / macOS 10.10+ / watchOS 2.0+ &bull; Swift 4.0 / Xcode 9+

| Swift version | RxGRDB version                                                  |
| ------------- | --------------------------------------------------------------- |
| Swift 3       | [v0.3.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.3.0) |
| Swift 3.1     | [v0.6.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.6.0) |
| Swift 3.2     | [v0.6.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.6.0) |
| **Swift 4**   | **v0.7.0**                                                      |


---

## Usage

RxGRDB produces observable sequences from database requests. For example:

```swift
Player.order(score.desc).limit(10)
    .rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { players: [Player] in
        print("Best ten players have changed")
    })

Player.filter(key: 1)
    .rx
    .fetchOne(in: dbQueue)
    .subscribe(onNext: { player: Player? in
        print("Player 1 has changed")
    })
```

To connect to the database and define the tracked requests, please refer to [GRDB](https://github.com/groue/GRDB.swift), the database library that supports RxGRDB.


Documentation
=============

- [Installation](#installation)
- [What is Database Observation?](#what-is-database-observation)
- [Observing Individual Requests](#observing-individual-requests)
- [Observing Multiple Requests](#observing-multiple-requests)
- [Diffs](#diffs)


## Installation

You can install RxGRDB with [CocoaPods](http://cocoapods.org/):

1. Install cocoapods version 1.1 or higher

2. Specify in your Podfile:

    ```ruby
    use_frameworks!
    pod 'RxGRDB'
    ```

3. In your application files, import the modules you need:
    
    ```swift
    import RxSwift
    import RxGRDB
    import GRDB
    ```

In order to use databases encrypted with [SQLCipher](https://www.zetetic.net/sqlcipher/), do instead:

1. Install cocoapods version 1.1 or higher

2. Specify in your Podfile:

    ```ruby
    use_frameworks!
    pod 'RxGRDB/GRDBCipher'
    ```

3. In your application files, import the modules you need:
    
    ```swift
    import RxSwift
    import RxGRDB
    import GRDBCipher
    ```


## What is Database Observation?

**RxGRDB notifies changes that have been committed in the database.** No insertion, update, or deletion in tracked tables is missed. This includes indirect changes triggered by [foreign keys](https://www.sqlite.org/foreignkeys.html#fk_actions) or [SQL triggers](https://www.sqlite.org/lang_createtrigger.html).

> :point_up: **Note**: some special changes are not notified: changes to SQLite system tables (such as `sqlite_master`), and changes to [`WITHOUT ROWID`](https://www.sqlite.org/withoutrowid.html) tables. See [Data Change Notification Callbacks](https://www.sqlite.org/c3ref/update_hook.html) for more information.

To function correctly, RxGRDB requires that a unique [database connection] is kept open during the whole duration of the observation.

**To define which part of the database should be observed, you provide a database request.** Requests can be expressed with GRDB's [query interface], as in `Player.all()`, or with SQL, as in `SELECT * FROM players`. Both would observe the full "players" database table. Observed requests can involve several database tables, and generally be as complex as you need them to be.

**Change notifications may happen even though the request results are the same.** RxGRDB often notifies of *potential changes*, not of *actual changes*. A transaction triggers a change notification if and only if a statement has actually modified the tracked tables and columns by inserting, updating, or deleting a row.

For example, if you track `Player.select(max(scoreColumn))`, then you'll get a notification for all changes performed on the `score` column of the `players` table (updates, insertions and deletions), even if they do not modify the value of the maximum score. However, you will not get any notification for changes performed on other database tables, or updates to other columns of the `players` table.

It is possible to avoid notifications of identical consecutive values. For example you can use the [`distinctUntilChanged`](http://reactivex.io/documentation/operators/distinct.html) operator of RxSwift. You can also let RxGRDB perform efficient deduplication at the database level: see the documentation of each reactive method for more information.

**RxGRDB observables are based on GRDB's [TransactionObserver] protocol.** If your application needs change notifications that are not built in RxGRDB, this versatile protocol will probably provide a solution.


## Observing Individual Requests

**When your application observes a request, it gets notified each time a change in the results of the request has been committed in the database.**

If you are only interested in the *values* fetched by the request, then RxGRDB can fetch them for you after each database modification, and emit them in order, ready for consumption. See the [rx.fetchCount](#requestrxfetchcountinsynchronizedstartscheduler), [rx.fetchOne](#typedrequestrxfetchoneinsynchronizedstartscheduler), and [rx.fetchAll](#typedrequestrxfetchallinsynchronizedstartscheduler) methods, depending on whether you want to track the number of results, the first one, or all of them:

```swift
let request = Player.all()
request.rx.fetchCount(in: dbQueue) // Observable<Int>
request.rx.fetchOne(in: dbQueue)   // Observable<Player?>
request.rx.fetchAll(in: dbQueue)   // Observable<[Player]>
```

Some applications need to be synchronously notified right after any impactful transaction has been committed, and before any further database modification. This feature is provided by the [rx.changes](#requestrxchangesinsynchronizedstart) method:

```swift
let request = Player.all()
request.rx.changes(in: dbQueue)    // Observable<Database>
```

- [`rx.changes`](#requestrxchangesinsynchronizedstart)
- [`rx.fetchCount`](#requestrxfetchcountinsynchronizedstartscheduler)
- [`rx.fetchOne`](#typedrequestrxfetchoneinsynchronizedstartschedulerdistinctuntilchanged)
- [`rx.fetchAll`](#typedrequestrxfetchallinsynchronizedstartschedulerdistinctuntilchanged)


---

#### `Request.rx.changes(in:synchronizedStart:)`

Emits a database connection after each [impactful](#what-is-database-observation) database transaction:

```swift
let request = Player.all()
request.rx.changes(in: dbQueue) // or dbPool
    .subscribe(onNext: { db: Database in
        print("Players table has changed.")
    })

try dbQueue.inDatabase { db in
    try Player.deleteAll(db)
    // Prints "Players table has changed."
}

try dbQueue.inTransaction { db in
    try Player(name: "Arthur").insert(db)
    try Player(name: "Barbara").insert(db)
    return .commit
    // Prints "Players table has changed."
}
```

All elements are emitted on the database writer dispatch queue, serialized with all database updates. If you set `synchronizedStart` to true (the default value), the first element is emitted right upon subscription. See [GRDB Concurrency Guide] for more information.

**You can also track SQL requests:**

```swift
let request = SQLRequest("SELECT * FROM players")
request.rx.changes(in: dbQueue)
    .subscribe(onNext: { db: Database in
        print("Players table has changed.")
    })

try dbQueue.inDatabase { db in
    try db.execute("DELETE FROM players")
    // Prints "Players table has changed."
}
```

> :point_up: **Note**: see [GRDB requests] for more information about requests in general, and SQLRequest in particular.


---

#### `Request.rx.fetchCount(in:synchronizedStart:scheduler:)`

Emits a count after each [impactful](#what-is-database-observation) database transaction:

```swift
let request = Player.all()
request.rx.fetchCount(in: dbQueue) // or dbPool
    .subscribe(onNext: { count: Int in
        print("Number of players: \(count)")
    })

try dbQueue.inTransaction { db in
    try Player.deleteAll(db)
    try Player(name: "Arthur").insert(db)
    return .commit
    // Eventually prints "Number of players: 1"
}
```

All elements are emitted on `scheduler`, which defaults to `MainScheduler.instance`. If you set `synchronizedStart` to true (the default value), the first element is emitted right upon subscription.

**This observable may emit identical consecutive values**, because RxGRDB tracks [potential](#what-is-database-observation) changes. Use the [`distinctUntilChanged`](http://reactivex.io/documentation/operators/distinct.html) operator in order to avoid duplicates:

```swift
request.rx.fetchCount(in: dbQueue).distinctUntilChanged()...
```


---

#### `TypedRequest.rx.fetchOne(in:synchronizedStart:scheduler:distinctUntilChanged:)`

Emits a value after each [impactful](#what-is-database-observation) database transaction:

```swift
let playerId = 42
let request = Player.filter(key: playerId)
request.rx.fetchOne(in: dbQueue) // or dbPool
    .subscribe(onNext: { player: Player? in
        print("Player has changed")
    })

try dbQueue.inDatabase { db in
    guard let player = Player.fetchOne(key: playerId) else { return }
    
    player.score += 100
    try player.update(db)
    // Eventually prints "Player has changed"
    
    try player.delete(db)
    // Eventually prints "Player has changed"
}
```

All elements are emitted on `scheduler`, which defaults to `MainScheduler.instance`. If you set `synchronizedStart` to true (the default value), the first element is emitted right upon subscription.

**You can also track SQL requests, and choose the fetched type** (database [row](https://github.com/groue/GRDB.swift/blob/master/README.md#row-queries), plain [value](https://github.com/groue/GRDB.swift/blob/master/README.md#values), custom [record](https://github.com/groue/GRDB.swift/blob/master/README.md#records)). The sample code below tracks an `Int` value fetched from a custom SQL request:

```swift
let request = SQLRequest("SELECT MAX(score) FROM rounds").asRequest(of: Int.self)
request.rx.fetchOne(in: dbQueue)
    .subscribe(onNext: { maxScore: Int? in
        print(maxScore)
    })
```

When tracking a *value*, you get nil in two cases: either the request yielded no database row, or one row with a NULL value.

> :point_up: **Note**: see [GRDB requests] for more information about requests in general, and SQLRequest in particular.

**This observable may emit identical consecutive values**, because RxGRDB tracks [potential](#what-is-database-observation) changes. Use the `distinctUntilChanged` parameter in order to avoid duplicates:

```swift
request.rx.fetchOne(in: dbQueue, distinctUntilChanged: true)...
```

The `distinctUntilChanged` parameter does not involve the fetched type, and simply performs comparisons of raw database values.


---

#### `TypedRequest.rx.fetchAll(in:synchronizedStart:scheduler:distinctUntilChanged:)`

Emits an array of values after each [impactful](#what-is-database-observation) database transaction:

```swift
let request = Player.order(Column("name"))
request.rx.fetchAll(in: dbQueue) // or dbPool
    .subscribe(onNext: { players: [Player] in
        print(players.map { $0.name })
    })

try dbQueue.inTransaction { db in
    try Player.deleteAll(db)
    try Player(name: "Arthur").insert(db)
    try Player(name: "Barbara").insert(db)
    return .commit
    // Eventually prints "[Arthur, Barbara]"
}
```

All elements are emitted on `scheduler`, which defaults to `MainScheduler.instance`. If you set `synchronizedStart` to true (the default value), the first element is emitted right upon subscription.

**You can also track SQL requests, and choose the fetched type** (database [row](https://github.com/groue/GRDB.swift/blob/master/README.md#row-queries), plain [value](https://github.com/groue/GRDB.swift/blob/master/README.md#values), custom [record](https://github.com/groue/GRDB.swift/blob/master/README.md#records)). The sample code below tracks an array of `URL` values fetched from a custom SQL request:

```swift
let request = SQLRequest("SELECT url FROM links").asRequest(of: URL.self)
request.rx.fetchAll(in: dbQueue)
    .subscribe(onNext: { urls: [URL] in
        print(urls)
    })
```

When tracking *values*, make sure to ask for optionals when database may contain NULL:

```swift
let request = SQLRequest("SELECT email FROM players").asRequest(of: Optional<String>.self)
request.rx.fetchAll(in: dbQueue)
    .subscribe(onNext: { emails: [String?] in
        print(emails)
    })
```

> :point_up: **Note**: see [GRDB requests] for more information about requests in general, and SQLRequest in particular.

**This observable may emit identical consecutive values**, because RxGRDB tracks [potential](#what-is-database-observation) changes. Use the `distinctUntilChanged` parameter in order to avoid duplicates:

```swift
request.rx.fetchAll(in: dbQueue, distinctUntilChanged: true)...
```

The `distinctUntilChanged` parameter does not involve the fetched type, and simply performs comparisons of raw database values.


## Observing Multiple Requests

We have seen above how to [observe individual requests](#observing-individual-requests):

```swift
let request = Player.all()
request.rx.changes(in: dbQueue)    // Observable<Database>
request.rx.fetchCount(in: dbQueue) // Observable<Int>
request.rx.fetchOne(in: dbQueue)   // Observable<Player?>
request.rx.fetchAll(in: dbQueue)   // Observable<[Player]>
```

Those observables can be composed together using [RxSwift operators](https://github.com/ReactiveX/RxSwift). However, be careful: those operators are unable to fulfill some database-specific requirements:

To get a single notification when a transaction has modified several requests, use [DatabaseWriter.rx.changes](#databasewriterrxchangesinsynchronizedstart).

When you need to fetch from several requests with the guarantee of consistent results, that is to say when you need values that come alltogether from a single database transaction, see [Change Tokens](#change-tokens).

- [`DatabaseWriter.rx.changes`](#databasewriterrxchangesinsynchronizedstart)
- [Change Tokens](#change-tokens)
- [`DatabaseWriter.rx.changeTokens`](#databasewriterrxchangetokensinsynchronizedstartscheduler)
- [`Observable.mapFetch`](#observablemapfetch_)


---

#### `DatabaseWriter.rx.changes(in:synchronizedStart:)`

Emits a database connection after each database transaction that has an [impact](#what-is-database-observation) on any of the tracked requests:

```swift
let players = Player.all()
let teams = Team.all()
dbQueue.rx.changes(in: [players, teams]) // or dbPool
    .subscribe(onNext: { db: Database in
        print("Changes in players or teams table")
    })

try dbQueue.inDatabase { db in
    try Player.deleteAll(db)
    // Prints "Changes in players or teams table"
}

try dbQueue.inTransaction { db in
    let team = Team(name: "Blue")
    try team.insert(db)
    try Player(name: "Arthur", teamId: team.id).insert(db)
    return .commit
    // Prints "Changes in players or teams table"
}
```

All elements are emitted on the database writer dispatch queue, serialized with all database updates. If you set `synchronizedStart` to true (the default value), the first element is emitted right upon subscription. See [GRDB Concurrency Guide] for more information.

**You can also track SQL requests:**

```swift
let players = SQLRequest("SELECT * FROM players")
let teams = SQLRequest("SELECT * FROM teams")
dbQueue.rx.changes(in: [players, teams])
    .subscribe(onNext: { db: Database in
        print("Changes in players or teams table")
    })

try dbQueue.inDatabase { db in
    try db.execute("DELETE FROM players")
    // Prints "Changes in players or teams table"
}
```

> :point_up: **Note**: see [GRDB requests] for more information about requests in general, and SQLRequest in particular.


---

### Change Tokens

**Generally speaking, *change tokens* let you turn notifications of database changes into fetched values. But the requests you observe don't have to be the same as the requests you fetch from.**

To introduce them, let's start with a simple request observable:

```swift
let request = Player.all()
request.rx.fetchAll(in: dbQueue) // Observable<[Player]>
```

After each modification of the players database table, the observable above emits a fresh array of players (see [rx.fetchAll](#typedrequestrxfetchallinsynchronizedstartschedulerdistinctuntilchanged) for more options).

The job performed by this observable is decomposed into two steps: observe database modifications, and fetch fresh results after each modification. These two steps are made visible below:

```swift
// The very same Observable<[Player]>
dbQueue.rx
    .changeTokens(in: [request])        // 1. observe modifications
    .mapFetch { (db: Database) in       // 2. fetch fresh results
        return try request.fetchAll(db)
    }
```

`changeTokens` emits *change tokens* for all database transactions that modifies some requests. Those change tokens are opaque values that are turned into the fetched results of your choice by the `mapFetch` operator.

When a single request is involved, it is used as both the source of tracked changes, and the source of the fetched results. But you can observe some requests and fetch from other ones:

```swift
// When the players table is changed, fetch the ten best ones, as well as the
// total number of players:
dbQueue.rx
    .changeTokens(in: [Player.all()])
    .mapFetch { (db: Database) -> ([Player], Int) in
        let players = try Player.order(scoreColumn.desc).limit(10).fetchAll(db)
        let count = try Player.fetchCount(db)
        return (players, count)
    }
    .subscribe(onNext: { (players, count) in
        print("Best ten players out of \(count): \(players)")
    })
```

- [`DatabaseWriter.rx.changeTokens`](#databasewriterrxchangetokensinsynchronizedstartscheduler)
- [`Observable.mapFetch`](#observablemapfetch_)


---

#### `DatabaseWriter.rx.changeTokens(in:synchronizedStart:scheduler:)`

Emits a [change token](#change-tokens) after each database transaction that has an [impact](#what-is-database-observation) on any of the tracked requests:

```swift
let players = Player.all()
let teams = Team.all()

// Observable<ChangeToken>
let changeTokens = dbQueue.rx.changeTokens(in: [players, teams]) // or dbPool
```

Change tokens are opaque values: you can't use them directly. Instead, sequences of change tokens are designed to be consumed by the [mapFetch](#observablemapfetch_) operator.

The `scheduler` and `synchronizedStart` parameters are used to control the delivery of fetched elements by the mapFetch operator. See below.

> :point_up: **Note**: RxGRDB does not support any alteration of change tokens sequences by the way of any RxSwift operator. Don't skip elements, don't merge sequences, etc.


---

#### `Observable.mapFetch(_:)`

The `mapFetch` operator transforms a sequence of [change tokens](#change-tokens) into fetched values.

```swift
let changeTokens = dbQueue.rx.changeTokens(in: ...)
    
// Observable<[Player]>
let players = changeTokens.mapFetch { (db: Database) in
    try Player.fetchAll(db)
}
```

The `scheduler` and `synchronizedStart` parameters are used to build the sequence of change tokens control the delivery of fetched elements:

All elements are emitted on `scheduler`, which defaults to `MainScheduler.instance`. If you set `synchronizedStart` to true (the default value), the first element is emitted right upon subscription.

**The closure provided to `mapFetch` is guaranteed an immutable view of the last committed state of the database.** This means that you can perform several fetches without fearing eventual concurrent writes to mess with your application logic:

```swift
// When the players table is changed, fetch the ten best ones, as well
// as the total number of players:
dbQueue.rx
    .changeTokens(in: [Player.all()])
    .mapFetch { (db: Database) -> ([Player], Int) in
        // players and count are guaranteed to be consistent:
        let players = try Player.order(scoreColumn.desc).limit(10).fetchAll(db)
        let count = try Player.fetchCount(db)
        return (players, count)
    }
    .subscribe(onNext: { (players, count) in
        print("Best players out of \(count): \(players)")
    })
```


## Diffs

Since RxGRDB is able to track database changes, it is a natural desire to compute diffs between two consecutive request results.

**There are several diff algorithms**: you'll have to pick the one that suits your needs.

RxGRDB ships with one diff algorithm which computes the inserted, updated, and deleted elements between two record arrays. This algorithm is well suited for collections whose order does not matter, such as annotations in a map view. See [`PrimaryKeyDiffScanner`](#primarykeydiffscanner).

For other diff algorithms, we advise you to have a look to [Differ](https://github.com/tonyarnold/Differ), [Dwifft](https://github.com/jflinter/Dwifft), or your favorite diffing library. RxGRDB ships with a [demo application](Documentation/RxGRDBDemo) that uses Differ in order to animate the content of a table view.


---

#### PrimaryKeyDiffScanner

PrimaryKeyDiffScanner computes diffs between collections whose order does not matter. It is well suited, for example, for synchronizing annotations in a map view with the contents of the database.

Its algorithm has a low complexity of `O(max(N,M))`, where `N` and `M` are the sizes of two consecutive request results.

```swift
struct PrimaryKeyDiffScanner<Record: RowConvertible & MutablePersistable> {
    let diff: PrimaryKeyDiff<Record>
    func diffed(from rows: [Row]) -> PrimaryKeyDiffScanner
}

struct PrimaryKeyDiff<Record> {
    let inserted: [Record]
    let updated: [Record]
    let deleted: [Record]
}
```

Everything starts from a GRDB [record type](https://github.com/groue/GRDB.swift/blob/master/README.md#records), and a request, ordered by primary key, whose results are used to compute diffs after each [impactful](#what-is-database-observation) database transaction:

```swift
let request = Place.order(Column("id"))
```

> :point_up: **Note**: if the primary key contains string column(s), then they must be sorted according to the default [BINARY collation](https://www.sqlite.org/datatype3.html#collation) of SQLite (which lexicographically sorts the UTF8 representation of strings).

You then create the PrimaryKeyDiffScanner, with a database connection and an eventual initial array of records which is used to compute the first diff:

```swift
let scanner = try dbQueue.inDatabase { db in
    try PrimaryKeyDiffScanner(
        database: db,
        request: request,
        initialRecords: []) // initial records must be sorted by primary key
}
```

Now is the time to compute diffs. Diffs are computed from raw database rows, so we need to turn the record request into a row request before feeding the scanner:

```swift
let rowRequest = request.asRequest(of: Row.self)

// The scanner is designed to feed the built-in RxSwift `scan` operator:
rowRequest.rx
    .fetchAll(in: dbQueue)
    .scan(scanner) { (scanner, rows) in scanner.diffed(from: rows) }
    .subscribe(onNext: { scanner in
        let diff = scanner.diff
        print("inserted \(diff.inserted.count) records")
        print("updated \(diff.updated.count) records")
        print("deleted \(diff.deleted.count) records")
    })
```

Check the [demo application](Documentation/RxGRDBDemo) for an example app that uses `PrimaryKeyDiffScanner` to synchronize the content of a map view with the content of the database.


[database connection]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections
[database pool]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-pools
[database queue]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-queues
[GRDB Concurrency Guide]: https://github.com/groue/GRDB.swift/blob/master/README.md#concurrency
[query interface]: https://github.com/groue/GRDB.swift/blob/master/README.md#requests
[GRDB requests]: https://github.com/groue/GRDB.swift/blob/master/README.md#requests
[TransactionObserver]: https://github.com/groue/GRDB.swift/blob/master/README.md#transactionobserver-protocol
