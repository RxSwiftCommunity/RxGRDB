RxGRDB [![Swift](https://img.shields.io/badge/swift-4-orange.svg?style=flat)](https://developer.apple.com/swift/) [![Platforms](https://img.shields.io/cocoapods/p/RxGRDB.svg)](https://developer.apple.com/swift/) [![License](https://img.shields.io/github/license/RxSwiftCommunity/RxGRDB.svg?maxAge=2592000)](/LICENSE)
======

### A set of reactive extensions for SQLite and [GRDB.swift](http://github.com/groue/GRDB.swift)

**Latest release**: October 18, 2017 &bull; version 0.7.0 &bull; [Release Notes](CHANGELOG.md)

**Requirements**: iOS 8.0+ / macOS 10.10+ / watchOS 2.0+ &bull; Swift 4.0 / Xcode 9+

| Swift version | GRDB version                                                    |
| ------------- | --------------------------------------------------------------- |
| Swift 3       | [v0.3.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.3.0) |
| Swift 3.1     | [v0.6.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.6.0) |
| Swift 3.2     | [v0.6.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.6.0) |
| **Swift 4**   | **v0.7.0**                                                      |


---

## Usage

RxGRDB produces observable sequences from database requests. For example:

```swift
let request = Player.order(score.desc).limit(10)

request.rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { players: [Player] in
        print("Best ten players have changed")
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

If you are only interested in the *values* fetched by the request, then RxGRDB can fetch them for you after each database modification, and emit them in order, ready for consumption. See the [rx.fetchCount](#requestrxfetchcountinsynchronizedstartresultqueue), [rx.fetchOne](#typedrequestrxfetchoneinsynchronizedstartresultqueue), and [rx.fetchAll](#typedrequestrxfetchallinsynchronizedstartresultqueue) methods, depending on whether you want to track the number of results, the first one, or all of them:

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
- [`rx.fetchCount`](#requestrxfetchcountinsynchronizedstartresultqueue)
- [`rx.fetchOne`](#typedrequestrxfetchoneinsynchronizedstartdistinctuntilchangedresultqueue)
- [`rx.fetchAll`](#typedrequestrxfetchallinsynchronizedstartdistinctuntilchangedresultqueue)


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

If you set `synchronizedStart` to true (the default value), the first element is emitted synchronously upon subscription.

All elements are emitted on the database writer dispatch queue, serialized with all database updates. See [GRDB Concurrency Guide] for more information.


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


---

#### `Request.rx.fetchCount(in:synchronizedStart:resultQueue:)`

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

If you set `synchronizedStart` to true (the default value), the first element is emitted synchronously upon subscription. Other elements are asynchronously emitted on `resultQueue`.

To guarantee that results are emitted in the chronological order of transactions, this observable must be subscribed on `resultQueue`. It is `DispatchQueue.main` by default.

**This observable may emit identical consecutive values**, because RxGRDB tracks [potential](#what-is-database-observation) changes. Use the [`distinctUntilChanged`](http://reactivex.io/documentation/operators/distinct.html) operator in order to avoid duplicates:

```swift
request.rx.fetchCount(in: dbQueue).distinctUntilChanged()...
```


---

#### `TypedRequest.rx.fetchOne(in:synchronizedStart:distinctUntilChanged:resultQueue:)`

Emits a value after each [impactful](#what-is-database-observation) database transaction:

```swift
let request = Player.filter(Column("name") == "Arthur")
request.rx.fetchOne(in: dbQueue) // or dbPool
    .subscribe(onNext: { player: Player? in
        print(player?.name ?? "nil")
    })

try dbQueue.inDatabase { db in
    try Player.deleteAll(db)
    // Eventually prints "nil"
    
    try Player(name: "Arthur").insert(db)
    // Eventually prints "Arthur"
}
```

If you set `synchronizedStart` to true (the default value), the first element is emitted synchronously upon subscription. Other elements are asynchronously emitted on `resultQueue`.

To guarantee that results are emitted in the chronological order of transactions, this observable must be subscribed on `resultQueue`. It is `DispatchQueue.main` by default.

**You can also track SQL requests, and choose the fetched type** (database [row](https://github.com/groue/GRDB.swift/blob/master/README.md#row-queries), plain [value](https://github.com/groue/GRDB.swift/blob/master/README.md#values), custom [record](https://github.com/groue/GRDB.swift/blob/master/README.md#records)). The sample code below tracks an `Int` value fetched from a custom SQL request:

```swift
let request = SQLRequest("SELECT MAX(score) FROM rounds").asRequest(of: Int.self)
request.rx.fetchOne(in: dbQueue)
    .subscribe(onNext: { maxScore: Int? in
        print(maxScore)
    })
```

When tracking a *value*, you get nil in two cases: either the request yielded no database row, or one row with a NULL value.


**This observable may emit identical consecutive values**, because RxGRDB tracks [potential](#what-is-database-observation) changes. Use the `distinctUntilChanged` parameter in order to avoid duplicates:

```swift
request.rx.fetchOne(in: dbQueue, distinctUntilChanged: true)...
```

The `distinctUntilChanged` parameter does not involve the fetched type, and simply performs comparisons of raw database values.


---

#### `TypedRequest.rx.fetchAll(in:synchronizedStart:distinctUntilChanged:resultQueue:)`

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

If you set `synchronizedStart` to true (the default value), the first element is emitted synchronously upon subscription. Other elements are asynchronously emitted on `resultQueue`.

To guarantee that results are emitted in the chronological order of transactions, this observable must be subscribed on `resultQueue`. It is `DispatchQueue.main` by default.

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
- [`DatabaseWriter.rx.changeTokens`](#databasewriterrxchangeTokensinsynchronizedstart)
- [`Observable.mapFetch`](#observablemapfetchresultqueue)


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

If you set `synchronizedStart` to true (the default value), the first element is emitted synchronously upon subscription.

All elements are emitted on the database writer dispatch queue, serialized with all database updates. See [GRDB Concurrency Guide] for more information.

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



---

### Change Tokens

**Generally speaking, *change tokens* let you turn notifications of database changes into fetched values. But the requests you observe don't have to be the same as the requests you fetch from.**

To introduce them, let's start with a simple request observable:

```swift
let request = Player.all()
request.rx.fetchAll(in: dbQueue) // Observable<[Player]>
```

After each modification of the players database table, the observable above emits a fresh array of players on the main queue (see [rx.fetchAll](#typedrequestrxfetchallinsynchronizedstartdistinctuntilchangedresultqueue) for more options).

It can be decomposed into two steps:

1. observe database modifications
2. fetch fresh results

The observable above is exactly equivalent to the following sequence:

```swift
// The same Observable<[Player]>
dbQueue.rx
    .changeTokens(in: [request])
    .mapFetch { (db: Database) in
        return try request.fetchAll(db)
    }
```

`changeTokens(in:)` emits *change tokens* for all database transactions that modifies some requests. Those change tokens are opaque values that are turned into the fetched results of your choice by the `mapFetch` operator.

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
        print("Best players out of \(count): \(players)")
    })
```

- [`DatabaseWriter.rx.changeTokens`](#databasewriterrxchangetokensinsynchronizedstart)
- [`Observable.mapFetch`](#observablemapfetchresultqueue)


---

#### `DatabaseWriter.rx.changeTokens(in:synchronizedStart:)`

Given a database writer ([database queue] or [database pool]), emits a [change token](#change-tokens) after each database transaction that has an [impact](#what-is-database-observation) on any of the tracked requests:

```swift
let players = Player.all()
let teams = Team.all()

// Observable<ChangeToken>
let changeTokens = dbQueue.rx.changeTokens(in: [players, teams]) // or dbPool
```

A sequence of change tokens is designed to be consumed by the [mapFetch](#observablemapfetchresultqueue) operator.


---

#### `Observable.mapFetch(resultQueue:_:)`

The `mapFetch` operator transforms a sequence of [change tokens](#change-tokens) into fetched values.

```swift
let changeTokens = ... // Observable<ChangeToken>
    
// Observable<[Player]>
let players = changeTokens.mapFetch { (db: Database) in
    try Player.fetchAll(db)
}
```

If the source sequence of change tokens has been produced with the `synchronizedStart` option (the default value), the first element is emitted synchronously upon subscription. Other elements are asynchronously emitted on `resultQueue`.

To guarantee that results are emitted in the chronological order of transactions, this observable must be subscribed on `resultQueue`. It is `DispatchQueue.main` by default.

**The closure provided to `mapFetch` is guaranteed an immutable view of the last committed state of the database.** This means that you can perform subsequent fetches without fearing eventual concurrent writes to mess with your application logic:

```swift
// When the players table is changed, fetch the ten best ones, as well as the
// total number of players:
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

RxGRDB ships with one diff algorithm which computes the inserted, updated, and deleted elements between two record arrays. This algorithm is well suited for collections whose order does not matter, such as annotations in a map view. See [`rx.primaryKeySortedDiff`](#typedrequestrxprimarykeysorteddiffininitialelements).

For other diff algorithms, we advise you to have a look to [Differ](https://github.com/tonyarnold/Differ), [Dwifft](https://github.com/jflinter/Dwifft), or your favorite diffing library. RxGRDB ships with a [demo application](Documentation/RxGRDBDemo) that uses Differ in order to animate the content of a table view.

---

#### `TypedRequest.rx.primaryKeySortedDiff(in:initialElements:)`

This observable emits values of type PrimaryKeySortedDiff after each database transaction that has  [impacted](#what-is-database-observation) the results of a request.

```swift
struct PrimaryKeySortedDiff<Element> {
    let inserted: [Element]
    let updated: [Element]
    let deleted: [Element]
}
```

To perform reliably, this observable has a few preconditions:

- The request must be sorted by primary key.
- The eventual initialElements argument array must be sorted by primary key.
- The fetched values must be records that adopt the RowConvertible, MutablePersistable, and Diffable protocols.

> :point_up: **Note**: if the primary key contains string column(s), then they must be sorted according to the default [BINARY collation](https://www.sqlite.org/datatype3.html#collation) of SQLite (which lexicographically sorts the UTF8 representation of strings).

Those preconditions gives this algorithm a low complexity of `O(max(N,M))`, where `N` and `M` are the sizes of two consecutive request results.

RowConvertible and MutablePersistable are [GRDB record protocols](https://github.com/groue/GRDB.swift/blob/master/README.md#records).

Diffable is the following protocol:

```swift
protocol Diffable {
    /// Returns a record updated with the given row.
    func updated(with row: Row) -> Self
}
```

The Diffable protocol has a default implementation of the `updated(with:)` method which returns a newly created record from the given row. When the record type is a class, and you want records to be *reused* as the request results change, you'll provide a custom implementation that returns the same instance, updated from the given row.

Check the [demo application](Documentation/RxGRDBDemo) for an example app that uses `primaryKeySortedDiff` to synchronize the content of a map view with the content of the database.

[database connection]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections
[database pool]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-pools
[database queue]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-queues
[GRDB Concurrency Guide]: https://github.com/groue/GRDB.swift/blob/master/README.md#concurrency
[query interface]: https://github.com/groue/GRDB.swift/blob/master/README.md#requests
[TransactionObserver]: https://github.com/groue/GRDB.swift/blob/master/README.md#transactionobserver-protocol