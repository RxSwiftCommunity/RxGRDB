RxGRDB [![Swift 5.7](https://img.shields.io/badge/swift-5.7-orange.svg?style=flat)](https://developer.apple.com/swift/) [![Platforms](https://img.shields.io/cocoapods/p/RxGRDB.svg)](https://developer.apple.com/swift/) [![License](https://img.shields.io/github/license/RxSwiftCommunity/RxGRDB.svg?maxAge=2592000)](/LICENSE) [![Build Status](https://travis-ci.org/RxSwiftCommunity/RxGRDB.svg?branch=master)](https://travis-ci.org/RxSwiftCommunity/RxGRDB)
======

### A set of extensions for [SQLite], [GRDB.swift], and [RxSwift]

**Latest release**: September 9, 2022 • [version 3.0.0](https://github.com/RxSwiftCommunity/RxGRDB/tree/v3.0.0) • [Release Notes]

**Requirements**: iOS 11.0+ / macOS 10.13+ / tvOS 11.0+ / watchOS 4.0+ • Swift 5.7+ / Xcode 14+

| Swift version  | RxGRDB version                                                    |
| -------------- | ----------------------------------------------------------------- |
| **Swift 5.7**  | **[v3.0.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v3.0.0)** |
| Swift 5.3      | [v2.1.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v2.1.0)   |
| Swift 5.2      | [v2.0.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v2.0.0)   |
| Swift 5.1      | [v0.18.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.18.0) |
| Swift 5.0      | [v0.18.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.18.0) |
| Swift 4.2      | [v0.13.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.13.0) |
| Swift 4.1      | [v0.11.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.11.0) |
| Swift 4        | [v0.10.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.10.0) |
| Swift 3.2      | [v0.6.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.6.0)   |
| Swift 3.1      | [v0.6.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.6.0)   |
| Swift 3        | [v0.3.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.3.0)   |

---

## Usage

To connect to the database, please refer to [GRDB](https://github.com/groue/GRDB.swift), the database library that supports RxGRDB.

<details>
  <summary><strong>Asynchronously read from the database</strong></summary>

This observable reads a single value and delivers it.

```swift
// Single<[Player]>
let players = dbQueue.rx.read { db in
    try Player.fetchAll(db)
}

players.subscribe(
    onSuccess: { (players: [Player]) in
        print("Players: \(players)")
    },
    onError: { error in ... })
```

</details>

<details>
  <summary><strong>Asynchronously write in the database</strong></summary>

This observable completes after the database has been updated.

```swift
// Single<Void>
let write = dbQueue.rx.write { db in 
    try Player(...).insert(db)
}

write.subscribe(
    onSuccess: { _ in
        print("Updates completed")
    },
    onError: { error in ... })

// Single<Int>
let newPlayerCount = dbQueue.rx.write { db -> Int in
    try Player(...).insert(db)
    return try Player.fetchCount(db)
}

newPlayerCount.subscribe(
    onSuccess: { (playerCount: Int) in
        print("New players count: \(playerCount)")
    },
    onError: { error in ... })
```

</details>

<details>
  <summary><strong>Observe changes in database values</strong></summary>

This observable delivers fresh values whenever the database changes:

```swift
// Observable<[Player]>
let observable = ValueObservation
    .tracking { db in try Player.fetchAll(db) }
    .rx.observe(in: dbQueue)

observable.subscribe(
    onNext: { (players: [Player]) in
        print("Fresh players: \(players)")
    },
    onError: { error in ... })

// Observable<Int?>
let observable = ValueObservation
    .tracking { db in try Int.fetchOne(db, sql: "SELECT MAX(score) FROM player") }
    .rx.observe(in: dbQueue)

observable.subscribe(
    onNext: { (maxScore: Int?) in
        print("Fresh maximum score: \(maxScore)")
    },
    onError: { error in ... })
```

</details>

<details>
  <summary><strong>Observe database transactions</strong></summary>

This observable delivers database connections whenever a database transaction has impacted an observed region:

```swift
// Observable<Database>
let observable = DatabaseRegionObservation
    .tracking(Player.all())
    .rx.changes(in: dbQueue)

observable.subscribe(
    onNext: { (db: Database) in
        print("Exclusive write access to the database after players have been impacted")
    },
    onError: { error in ... })

// Observable<Database>
let observable = DatabaseRegionObservation
    .tracking(SQLRequest<Int>(sql: "SELECT MAX(score) FROM player"))
    .rx.changes(in: dbQueue)

observable.subscribe(
    onNext: { (db: Database) in
        print("Exclusive write access to the database after maximum score has been impacted")
    },
    onError: { error in ... })
```

</details>

Documentation
=============

- [Installation]
- [Demo Application]
- [Asynchronous Database Access]
- [Database Observation]

## Installation

To use RxGRDB with the [Swift Package Manager], add a dependency to your `Package.swift` file:

```swift
let package = Package(
    dependencies: [
        .package(url: "https://github.com/RxSwiftCommunity/RxGRDB.git", ...)
    ]
)
```

To use RxGRDB with [CocoaPods](http://cocoapods.org/), specify in your `Podfile`:

```ruby
# Pick only one
pod 'RxGRDB'
pod 'RxGRDB/SQLCipher'
```


# Asynchronous Database Access

RxGRDB provide observables that perform asynchronous database accesses.

- [`rx.read(observeOn:value:)`]
- [`rx.write(observeOn:updates:)`]
- [`rx.write(observeOn:updates:thenRead:)`]


#### `DatabaseReader.rx.read(observeOn:value:)`

This methods returns a [Single] that completes after database values have been asynchronously fetched.

```swift
// Single<[Player]>
let players = dbQueue.rx.read { db in
    try Player.fetchAll(db)
}
```

Any attempt at modifying the database completes subscriptions with an error.

When you use a [database queue] or a [database snapshot], the read has to wait for any eventual concurrent database access performed by this queue or snapshot to complete.

When you use a [database pool], reads are generally non-blocking, unless the maximum number of concurrent reads has been reached. In this case, a read has to wait for another read to complete. That maximum number can be [configured].

This observable can be subscribed from any thread. A new database access starts on every subscription.

The fetched value is published on the main queue, unless you provide a specific scheduler to the `observeOn` argument.


#### `DatabaseWriter.rx.write(observeOn:updates:)`

This method returns a [Single] that completes after database updates have been successfully executed inside a database transaction.

```swift
// Single<Void>
let write = dbQueue.rx.write { db in
    try Player(...).insert(db)
}

// Single<Int>
let newPlayerCount = dbQueue.rx.write { db -> Int in
    try Player(...).insert(db)
    return try Player.fetchCount(db)
}
```

This observable can be subscribed from any thread. A new database access starts on every subscription.

It completes on the main queue, unless you provide a specific [scheduler] to the `observeOn` argument.

You can ignore its value and turn it into a [Completable] with the `asCompletable` operator:

```swift
// Completable
let write = dbQueue.rx
    .write { db in try Player(...).insert(db) }
    .asCompletable()
```

When you use a [database pool], and your app executes some database updates followed by some slow fetches, you may profit from optimized scheduling with [`rx.write(observeOn:updates:thenRead:)`]. See below.


#### `DatabaseWriter.rx.write(observeOn:updates:thenRead:)`

This method returns a [Single] that completes after database updates have been successfully executed inside a database transaction, and values have been subsequently fetched:

```swift
// Single<Int>
let newPlayerCount = dbQueue.rx.write(
    updates: { db in try Player(...).insert(db) }
    thenRead: { db, _ in try Player.fetchCount(db) })
}
```

It publishes exactly the same values as [`rx.write(observeOn:updates:)`]:

```swift
// Single<Int>
let newPlayerCount = dbQueue.rx.write { db -> Int in
    try Player(...).insert(db)
    return try Player.fetchCount(db)
}
```

The difference is that the last fetches are performed in the `thenRead` function. This function accepts two arguments: a readonly database connection, and the result of the `updates` function. This allows you to pass information from a function to the other (it is ignored in the sample code above).

When you use a [database pool], this method applies a scheduling optimization: the `thenRead` function sees the database in the state left by the `updates` function, and yet does not block any concurrent writes. This can reduce database write contention. See [Advanced DatabasePool](https://github.com/groue/GRDB.swift/blob/master/README.md#advanced-databasepool) for more information.

When you use a [database queue], the results are guaranteed to be identical, but no scheduling optimization is applied.

This observable can be subscribed from any thread. A new database access starts on every subscription.

It completes on the main queue, unless you provide a specific [scheduler] to the `observeOn` argument.


# Database Observation

Database Observation observables are based on GRDB's [ValueObservation] and [DatabaseRegionObservation]. Please refer to their documentation for more information. If your application needs change notifications that are not built in RxGRDB, check the general [Database Changes Observation] chapter.

- [`ValueObservation.rx.observe(in:scheduling:)`]
- [`DatabaseRegionObservation.rx.changes(in:)`]


#### `ValueObservation.rx.observe(in:scheduling:)`

GRDB's [ValueObservation] tracks changes in database values. You can turn it into an RxSwift observable:

```swift
let observation = ValueObservation.tracking { db in
    try Player.fetchAll(db)
}

// Observable<[Player]>
let observable = observation.rx.observe(in: dbQueue)
```

This observable has the same behavior as ValueObservation:

- It notifies an initial value before the eventual changes.
- It may coalesce subsequent changes into a single notification.
- It may notify consecutive identical values. You can filter out the undesired duplicates with the `distinctUntilChanged()` RxSwift operator, but we suggest you have a look at the [removeDuplicates()](https://github.com/groue/GRDB.swift/blob/master/README.md#valueobservationremoveduplicates) GRDB operator also.
- It stops emitting any value after the database connection is closed. But it never completes.
- By default, it notifies the initial value, as well as eventual changes and errors, on the main thread, asynchronously.
    
    This can be configured with the `scheduling` argument. It does not accept an RxSwift scheduler, but a [GRDB scheduler](https://github.com/groue/GRDB.swift/blob/master/README.md#valueobservation-scheduling).
    
    For example, the `.immediate` scheduler makes sure the initial value is notified immediately when the observable is subscribed. It can help your application update the user interface without having to wait for any asynchronous notifications:
    
    ```swift
    // Immediate notification of the initial value
    let disposable = observation.rx
        .observe(
            in: dbQueue,
            scheduling: .immediate) // <-
        .subscribe(
            onNext: { players: [Player] in print("fresh players: \(players)") },
            onError: { error in ... })
    // <- here "fresh players" is already printed.
    ```
    
    Note that the `.immediate` scheduler requires that the observable is subscribed from the main thread. It raises a fatal error otherwise.

See [ValueObservation Scheduling](https://github.com/groue/GRDB.swift/blob/master/README.md#valueobservation-scheduling) for more information.

:warning: **ValueObservation and Data Consistency**

When you compose ValueObservation observables together with the [combineLatest](http://reactivex.io/documentation/operators/combinelatest.html) operator, you lose all guarantees of [data consistency](https://en.wikipedia.org/wiki/Consistency_(database_systems)).

Instead, compose requests together into **one single** ValueObservation, as below:

```swift
// DATA CONSISTENCY GUARANTEED
let hallOfFameObservable = ValueObservation
    .tracking { db -> HallOfFame in
        let playerCount = try Player.fetchCount(db)
        let bestPlayers = try Player.limit(10).orderedByScore().fetchAll(db)
        return HallOfFame(playerCount:playerCount, bestPlayers:bestPlayers)
    }
    .rx.observe(in: dbQueue)
```

See [ValueObservation] for more information.


#### `DatabaseRegionObservation.rx.changes(in:)`

GRDB's [DatabaseRegionObservation] notifies all transactions that impact a tracked database region. You can turn it into an RxSwift observable:

```swift
let request = Player.all()
let observation = DatabaseRegionObservation.tracking(request)

// Observable<Database>
let observable = observation.rx.changes(in: dbQueue)
```

This observable can be created and subscribed from any thread. It delivers database connections in a "protected dispatch queue", serialized with all database updates. It only completes when a database error happens.

```swift
let request = Player.all()
let disposable = DatabaseRegionObservation
    .tracking(request)
    .rx.changes(in: dbQueue)
    .subscribe(
        onNext: { (db: Database) in
            print("Players have changed.")
        },
        onError: { error in ... })

try dbQueue.write { db in
    try Player(name: "Arthur").insert(db)
    try Player(name: "Barbara").insert(db)
} 
// Prints "Players have changed."

try dbQueue.write { db in
    try Player.deleteAll(db)
}
// Prints "Players have changed."
```

See [DatabaseRegionObservation] for more information.


[Asynchronous Database Access]: #asynchronous-database-access
[RxSwift]: https://github.com/ReactiveX/RxSwift
[Database Changes Observation]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-changes-observation
[Database Observation]: #database-observation
[DatabaseRegionObservation]: https://github.com/groue/GRDB.swift/blob/master/README.md#databaseregionobservation
[Demo Application]: Documentation/RxGRDBDemo/README.md
[GRDB.swift]: https://github.com/groue/GRDB.swift
[Installation]: #installation
[Release Notes]: CHANGELOG.md
[SQLite]: http://sqlite.org
[Swift Package Manager]: https://swift.org/package-manager/
[ValueObservation]: https://github.com/groue/GRDB.swift/blob/master/README.md#valueobservation
[`DatabaseRegionObservation.rx.changes(in:)`]: #databaseregionobservationrxchangesin
[`ValueObservation.rx.observe(in:scheduling:)`]: #valueobservationrxobserveinscheduling
[`rx.read(observeOn:value:)`]: #databasereaderrxreadobserveonvalue
[`rx.write(observeOn:updates:)`]: #databasewriterrxwriteobserveonupdates
[`rx.write(observeOn:updates:thenRead:)`]: #databasewriterrxwriteobserveonupdatesthenread
[configured]: https://github.com/groue/GRDB.swift/blob/master/README.md#databasepool-configuration
[database pool]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-pools
[database queue]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-queues
[database snapshot]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-snapshots
[scheduler]: https://github.com/ReactiveX/RxSwift/blob/master/Documentation/Schedulers.md
[Single]: https://github.com/ReactiveX/RxSwift/blob/master/Documentation/Traits.md#single
[Completable]: https://github.com/ReactiveX/RxSwift/blob/master/Documentation/Traits.md#completable
