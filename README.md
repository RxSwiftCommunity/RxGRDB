RxGRDB [![Swift](https://img.shields.io/badge/swift-4.1-orange.svg?style=flat)](https://developer.apple.com/swift/) [![Platforms](https://img.shields.io/cocoapods/p/RxGRDB.svg)](https://developer.apple.com/swift/) [![License](https://img.shields.io/github/license/RxSwiftCommunity/RxGRDB.svg?maxAge=2592000)](/LICENSE) [![Build Status](https://travis-ci.org/RxSwiftCommunity/RxGRDB.svg?branch=master)](https://travis-ci.org/RxSwiftCommunity/RxGRDB)
======

### A set of reactive extensions for SQLite and [GRDB.swift](http://github.com/groue/GRDB.swift)

**Latest release**: November 2, 2018 &bull; version 0.13.0 &bull; [Release Notes](CHANGELOG.md)

**Requirements**: iOS 8.0+ / OSX 10.9+ / watchOS 2.0+ &bull; Swift 4.1+ / Xcode 9.3+

| Swift version | RxGRDB version                                                    |
| ------------- | ----------------------------------------------------------------- |
| **Swift 4.2** | **v0.13.0**                                                       |
| Swift 4.1     | [v0.11.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.11.0) |
| Swift 4       | [v0.10.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.10.0) |
| Swift 3.2     | [v0.6.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.6.0)   |
| Swift 3.1     | [v0.6.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.6.0)   |
| Swift 3       | [v0.3.0](http://github.com/RxSwiftCommunity/RxGRDB/tree/v0.3.0)   |


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
- [Scheduling](#scheduling)
    - [Scheduling Guarantees](#scheduling-guarantees)
    - [Changes Observables vs. Values Observables](#changes-observables-vs-values-observables)
    - [Changes Observables](#changes-observables)
    - [Values Observables](#values-observables)
    - [Common Use Cases of Values Observables](#common-use-cases-of-values-observables)


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

To function correctly, RxGRDB requires that a unique [database connection] is kept open during the whole duration of the observation.

> :point_up: **Note**: some special changes are not notified: changes to SQLite system tables (such as `sqlite_master`), and changes to [`WITHOUT ROWID`](https://www.sqlite.org/withoutrowid.html) tables. See [Data Change Notification Callbacks](https://www.sqlite.org/c3ref/update_hook.html) for more information.

**To define which part of the database should be observed, you provide database requests.** Requests can be expressed with GRDB's [query interface], as in `Player.all()`, or with SQL, as in `SELECT * FROM player`. Both would observe the full "player" database table. Observed requests can involve several database tables, and generally be as complex as you need them to be.

**RxGRDB observables are based on GRDB's [ValueObservation] and [TransactionObserver].** If your application needs change notifications that are not built in RxGRDB, those versatile tools will probably provide a solution.


# Observing Individual Requests

**When your application observes a request, it gets notified each time a change in the results of the request has been committed in the database.**

If you are only interested in the *values* fetched by the request, then RxGRDB can fetch them for you after each database modification, and emit them in order, ready for consumption. See the [rx.fetchCount](#requestrxfetchcountinstartimmediatelyscheduler), [rx.fetchOne](#typedrequestrxfetchoneinstartimmediatelyscheduler), and [rx.fetchAll](#typedrequestrxfetchallinstartimmediatelyscheduler) methods, depending on whether you want to track the number of results, the first one, or all of them:

```swift
let request = Player.all()
request.rx.fetchCount(in: dbQueue) // Observable<Int>
request.rx.fetchOne(in: dbQueue)   // Observable<Player?>
request.rx.fetchAll(in: dbQueue)   // Observable<[Player]>
```

Some applications need to be synchronously notified right after any impactful transaction has been committed, and before any further database modification. This feature is provided by the [rx.changes](#requestrxchangesinstartimmediately) method:

```swift
let request = Player.all()
request.rx.changes(in: dbQueue)    // Observable<Database>
```

- [`rx.changes`](#requestrxchangesinstartimmediately)
- [`rx.fetchCount`](#requestrxfetchcountinstartimmediatelyscheduler)
- [`rx.fetchOne`](#typedrequestrxfetchoneinstartimmediatelyscheduler)
- [`rx.fetchAll`](#typedrequestrxfetchallinstartimmediatelyscheduler)


---

#### `Request.rx.changes(in:startImmediately:)`

This [database changes observable](#changes-observables) emits a database connection right after a database transaction has modified the tracked tables and columns by inserting, updating, or deleting a database row:

```swift
let request = Player.all()
request.rx.changes(in: dbQueue)
    .subscribe(onNext: { db: Database in
        print("Players have changed.")
    })

try dbQueue.write { db in
    try Player.deleteAll(db)
}
// Prints "Players have changed."

try dbQueue.write { db in
    try Player(name: "Arthur").insert(db)
    try Player(name: "Barbara").insert(db)
} 
// Prints "Players have changed."
```

All elements are emitted in a protected database dispatch queue, serialized with all database updates. If you set `startImmediately` to true (the default value), the first element is emitted synchronously, right upon subscription. See [GRDB Concurrency Guide] for more information.

**You can also track SQL requests:**

```swift
let request = SQLRequest<Row>("SELECT * FROM player")
request.rx.changes(in: dbQueue)
    .subscribe(onNext: { db: Database in
        print("Players have changed.")
    })

try dbQueue.write { db in
    try db.execute("DELETE FROM player")
}
// Prints "Players have changed."
```

> :point_up: **Note**: see [GRDB requests] for more information about requests in general, and SQLRequest in particular.


---

#### `Request.rx.fetchCount(in:startImmediately:scheduler:)`

This [database values observable](#values-observables) emits the number of results of the request after each database transaction that changes it:

```swift
let request = Player.all()
request.rx.fetchCount(in: dbQueue)
    .subscribe(onNext: { count: Int in
        print("Number of players: \(count)")
    })

try dbQueue.write { db in
    try Player.deleteAll(db)
    try Player(name: "Arthur").insert(db)
}
// Eventually prints "Number of players: 1"
```

All elements are emitted on the main queue, unless you provide a specific `scheduler`. If you set `startImmediately` to true (the default value), the first element is emitted right upon subscription.

This observable filters out identical consecutive values.


---

#### `TypedRequest.rx.fetchOne(in:startImmediately:scheduler:)`

This [database values observable](#values-observables) emits a value after each database transaction which has modified the result of the request:

```swift
let playerId = 42
let request = Player.filter(key: playerId)
request.rx.fetchOne(in: dbQueue)
    .subscribe(onNext: { player: Player? in
        print("Player has changed")
    })

try dbQueue.write { db in
    guard let player = Player.fetchOne(key: playerId) else { return }
    player.score += 100
    try player.update(db)
}
// Eventually prints "Player has changed"
```

All elements are emitted on the main queue, unless you provide a specific `scheduler`. If you set `startImmediately` to true (the default value), the first element is emitted right upon subscription.

**You can also track SQL requests, and choose the fetched type** (database [row](https://github.com/groue/GRDB.swift/blob/master/README.md#row-queries), plain [value](https://github.com/groue/GRDB.swift/blob/master/README.md#values), custom [record](https://github.com/groue/GRDB.swift/blob/master/README.md#records)). The sample code below tracks an `Int` value fetched from a custom SQL request:

```swift
let request = SQLRequest<Int>("SELECT MAX(score) FROM round")
request.rx.fetchOne(in: dbQueue)
    .subscribe(onNext: { maxScore: Int? in
        print(maxScore)
    })
```

When tracking a *value*, you get nil in two cases: either the request yielded no database row, or one row with a NULL value.

> :point_up: **Note**: see [GRDB requests] for more information about requests in general, and SQLRequest in particular.

This observable filters out identical consecutive values by comparing raw database values.


---

#### `TypedRequest.rx.fetchAll(in:startImmediately:scheduler:)`

This [database values observable](#values-observables) emits an array of values  after each database transaction which has modified the result of the request:

```swift
let request = Player.order(Column("name"))
request.rx.fetchAll(in: dbQueue)
    .subscribe(onNext: { players: [Player] in
        print(players.map { $0.name })
    })

try dbQueue.write { db in
    try Player.deleteAll(db)
    try Player(name: "Arthur").insert(db)
    try Player(name: "Barbara").insert(db)
}
// Eventually prints "[Arthur, Barbara]"
```

All elements are emitted on the main queue, unless you provide a specific `scheduler`. If you set `startImmediately` to true (the default value), the first element is emitted right upon subscription.

**You can also track SQL requests, and choose the fetched type** (database [row](https://github.com/groue/GRDB.swift/blob/master/README.md#row-queries), plain [value](https://github.com/groue/GRDB.swift/blob/master/README.md#values), custom [record](https://github.com/groue/GRDB.swift/blob/master/README.md#records)). The sample code below tracks an array of `URL` values fetched from a custom SQL request:

```swift
let request = SQLRequest<URL>("SELECT url FROM link")
request.rx.fetchAll(in: dbQueue)
    .subscribe(onNext: { urls: [URL] in
        print(urls)
    })
```

When tracking *values*, make sure to ask for optionals when database may contain NULL:

```swift
let request = SQLRequest<String?>("SELECT email FROM player")
request.rx.fetchAll(in: dbQueue)
    .subscribe(onNext: { emails: [String?] in
        print(emails)
    })
```

> :point_up: **Note**: see [GRDB requests] for more information about requests in general, and SQLRequest in particular.

This observable filters out identical consecutive values by comparing raw database values.


# Observing Multiple Requests

We have seen above how to [observe individual requests](#observing-individual-requests):

```swift
let request = Player.all()
request.rx.changes(in: dbQueue)    // Observable<Database>
request.rx.fetchCount(in: dbQueue) // Observable<Int>
request.rx.fetchOne(in: dbQueue)   // Observable<Player?>
request.rx.fetchAll(in: dbQueue)   // Observable<[Player]>
```

:warning: **DO NOT compose those observables together with [RxSwift operators](https://github.com/ReactiveX/RxSwift)**: you would lose all guarantees of [data consistency](https://en.wikipedia.org/wiki/Consistency_(database_systems)).

Instead, to be notified of each transaction that impacts any of several requests, use [DatabaseWriter.rx.changes](#databasewriterrxchangesinstartimmediately).

And when you need to fetch database values from several requests, use [ValueObservation.rx.fetch](#valueobservationrxfetchinstartimmediatelyscheduler).


---

#### `DatabaseWriter.rx.changes(in:startImmediately:)`

This [database changes observable](#changes-observables) emits a database connection right after a database transaction has modified the tracked tables and columns by inserting, updating, or deleting a database row:

```swift
let playersRequest = Player.all()
let teamsRequest = Team.all()
dbQueue.rx.changes(in: [playersRequest, teamsRequest])
    .subscribe(onNext: { db: Database in
        print("Players or teams have changed.")
    })

try dbQueue.write { db in
    try Player.deleteAll(db)
}
// Prints "Players or teams have changed."

try dbQueue.write { db in
    var team = Team(name: "Blue")
    try team.insert(db)
    try Player(name: "Arthur", teamId: team.id).insert(db)
}
// Prints "Players or teams have changed."
```

All elements are emitted in a protected database dispatch queue, serialized with all database updates. If you set `startImmediately` to true (the default value), the first element is emitted synchronously, right upon subscription. See [GRDB Concurrency Guide] for more information.

**You can also track SQL requests:**

```swift
let players = SQLRequest<Row>("SELECT * FROM player")
let teams = SQLRequest<Row>("SELECT * FROM team")
dbQueue.rx.changes(in: [players, teams])
    .subscribe(onNext: { db: Database in
        print("Players or teams have changed.")
    })

try dbQueue.write { db in
    try db.execute("DELETE FROM player")
}
// Prints "Players or teams have changed."
```

> :point_up: **Note**: see [GRDB requests] for more information about requests in general, and SQLRequest in particular.


---

#### `ValueObservation.rx.fetch(in:startImmediately:scheduler:)`

This [database values observable](#values-observables) emits the same values as a [ValueObservation].

For example:

```swift
// When the players' table is changed, fetch the ten best ones,
// and the total number of players:
let observation = ValueObservation.tracking(Player.all(), fetch: { db -> ([Player], Int) in
    let players = try Player
        .order(scoreColumn.desc)
        .limit(10)
        .fetchAll(db)
    let count = try Player.fetchCount(db)
    return (players, count)
})
observation.rx
    .fetch(in: dbQueue)
    .subscribe(onNext: { (players, count) in
        print("Best ten players out of \(count): \(players)")
    })
```

All elements are emitted on the main queue, unless you provide a specific `scheduler`. If you set `startImmediately` to true (the default value), the first element is emitted right upon subscription.


# Diffs

Since RxGRDB is able to track database changes, it is a natural desire to compute diffs between two consecutive request results.

**There are several diff algorithms**: you'll have to pick the one that suits your needs.

RxGRDB ships with one diff algorithm which computes the inserted, updated, and deleted elements between two record arrays. This algorithm is well suited for collections whose order does not matter, such as annotations in a map view. See [`PrimaryKeyDiffScanner`](#primarykeydiffscanner).

For other diff algorithms, we advise you to have a look to [Differ](https://github.com/tonyarnold/Differ), [Dwifft](https://github.com/jflinter/Dwifft), or your favorite diffing library. RxGRDB ships with a [demo application](Documentation/RxGRDBDemo) that uses Differ in order to animate the content of a table view.


## PrimaryKeyDiffScanner

**PrimaryKeyDiffScanner computes diffs between collections whose order does not matter.** It uses an algorithm that has a low, linear, complexity.

It is well suited, for example, for synchronizing annotations in a map view with the contents of the database.

Conversely, PrimaryKeyDiffScanner is not suited at all for updating table views. Those are better serviced by [FetchedRecordsController](https://github.com/groue/GRDB.swift#fetchedrecordscontroller), or by using RxGRDB with a well-chosen diff algorithm (see the [demo application](Documentation/RxGRDBDemo)).

In a glance:

```swift
struct PrimaryKeyDiffScanner<Record: FetchableRecord & MutablePersistableRecord> {
    let diff: PrimaryKeyDiff<Record>
    func diffed(from rows: [Row]) -> PrimaryKeyDiffScanner
}

struct PrimaryKeyDiff<Record> {
    let inserted: [Record]
    let updated: [Record]
    let deleted: [Record]
}
```

Everything starts from a GRDB [record type](https://github.com/groue/GRDB.swift/blob/master/README.md#records), and a request ordered by primary key, whose results are used to compute diffs after each database transaction which has modified the results of the request:

```swift
let request = Place.orderByPrimaryKey()
```

> :point_up: **Note**: PrimaryKeyDiffScanner expects string columns of the primary key to be sorted according to the default [BINARY collation](https://www.sqlite.org/datatype3.html#collation) of SQLite. When this is not the case, restore the binary ordering in the diffed request:
>
> ```swift
> try db.create(table: "place") { t in
>     t.column("uuid", .text).primaryKey().collate(.nocase)
>     ...
> }
>
> // Restore binary ordering
> let request = Place.order(Column("uuid").collating(.binary))
> ```

You then create the PrimaryKeyDiffScanner, with a database connection and an eventual initial array of records which is used to compute the first diff:

```swift
let scanner = try dbQueue.read { db in
    try PrimaryKeyDiffScanner(
        database: db,       // extracts primary key information
        request: request,   // the diffed request
        initialRecords: []) // initial records, if any, must be sorted by primary key
}
```

> :point_up: **Note**: the PrimaryKeyDiffScanner initializer accepts a fourth argument, `updateRecord`, which allows you to customize the processing of elements that are updated between two impactful transactions. The [demo application](Documentation/RxGRDBDemo) uses this extra argument in order to reuse MKAnnotation instances, a recommended practice when updating MKMapView annotations. See [RxGRDBDemo/PlacesViewController.swift](Documentation/RxGRDBDemo/RxGRDBDemo/PlacesViewController.swift) for the code.

Now the scanner is defined: it is time to compute diffs.

Diffs are computed from raw database rows: we need to turn the request of records into a request of raw rows before feeding the scanner, and let the built-in RxSwift `scan` operator grab diffs for us:

```swift
request
    .asRequest(of: Row.self)
    .rx
    .fetchAll(in: dbQueue)
    .scan(scanner) { (scanner, rows) in scanner.diffed(from: rows) }
    .subscribe(onNext: { scanner in
        let insertedPlaces = scanner.diff.inserted // [Place]
        let updatedPlaces = scanner.diff.updated   // [Place]
        let deletedPlaces = scanner.diff.deleted   // [Place]
    })
```

Check the [demo application](Documentation/RxGRDBDemo) for an example app that uses `PrimaryKeyDiffScanner` to synchronize the content of a map view with the content of the database.


# Scheduling

GRDB and RxGRDB go a long way in order to smooth out subtleties of multi-threaded SQLite. You're unlikely to use those libraries in a *very* wrong way.

Some applications are demanding: this chapter attempts at making RxGRDB scheduling as clear as possible. Please have a look at [GRDB Concurrency Guide](https://github.com/groue/GRDB.swift/blob/master/README.md#concurrency) first.

- [Scheduling Guarantees](#scheduling-guarantees)
- [Changes Observables vs. Values Observables](#changes-observables-vs-values-observables)
- [Changes Observables](#changes-observables)
- [Values Observables](#values-observables)
- [Common Use Cases of Values Observables](#common-use-cases-of-values-observables)


## Scheduling Guarantees

RxGRDB inherits from [GRDB guarantees](https://github.com/groue/GRDB.swift/blob/master/README.md#guarantees-and-rules), and adds two more:

- :bowtie: **RxGRDB Guarantee 1: all observables can be created and subscribed from any thread.**
    
    Not all can be observed on any thread, though: see [Changes Observables vs. Values Observables](#changes-observables-vs-values-observables)

- :bowtie: **RxGRDB Guarantee 2: all observables emit their values in the same chronological order as transactions.**


## Changes Observables vs. Values Observables

**RxGRDB provides two sets of observables: changes observables, and values observables.** Changes observables emit database connections, and values observables emit values (records, rows, ints, etc.):

```swift
// A changes observable:
Player.all().rx
    .changes(in: dbQueue)
    .subscribe(onNext: { db: Database in
        print("Players have changed.")
    })

// A values observable:
Player.all().rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { players: [Player] in
        print("Players have changed: \(players)")
    })
```

Since changes and values observables don't have the same behavior, we'd like you to understand the differences.


## Changes Observables

**Changes Observable are all about being synchronously notified of any database transaction that has modified the tracked tables and columns by inserting, updating, or deleting a database row.** Those observables can be created and subscribed from any thread. They all emit database connections in a "protected dispatch queue", serialized with all database updates:

```swift
// On any thread
Player.all().rx
    .changes(in: dbQueue)
    .subscribe(onNext: { db: Database in
        // On the database protected dispatch queue
        print("Players have changed.")
    })
```

**Changes observables must be observed on a database protected dispatch queue.** If you change the observation queue, you get a "Database was not used on the correct thread" fatal error:

```swift
Player.all().rx
    .changes(in: dbQueue)
    .observeOn(SerialDispatchQueueScheduler(qos: .userInitiated))
    .subscribe(onNext: { db: Database in
        // fatal error
        let players = try Player.fetchAll(db)
        ...
    })
```

**A changes observable blocks all threads that are writing in the database, or attempting to write in the database:**

```swift
// Wait 1 second on every change to the players' table
Player.all().rx
    .changes(in: dbQueue)
    .subscribe(onNext: { db: Database in
        sleep(1)
    })

print(Date())
// Trigger the observable, and waits 1 second
try dbQueue.write { db in
    try Player(name: "Arthur").insert(db)
}
print(Date()) // 1+ second later
```

When one uses a [database queue], all reads are blocked as well. A [database pool] allows concurrent reads.

**Because all writes are blocked, a changes observable guarantees access to the latest state of the database, exactly as it is written on disk.**

*This is a very strong guarantee, that most applications don't need*. This may sound surprising, so please bear with me, and consider an application that displays the database content on screen:

This application needs to update its UI, on the main thread, from the freshest database values. As the application is setting up its views from those values, background threads can write in the database, and make those values obsolete even before screen pixels have been refreshed.

Is it a problem if the app draws stale database content? RxGRDB's answer is *no*, as long as the application is eventually notified with refreshed values. And this is the job of [values observables](#values-observables).

**There are very few use cases for changes observables.** For example:

- One needs to write in the database after an impactful transaction.

- One needs to synchronize the content of the database file with some external resources, like other files, or system sensors like CLRegion monitoring.

- On iOS, one needs to process a database transaction before the operating system had any opportunity to put the application in the suspended state.

- One want to build a [database snapshot](https://github.com/groue/GRDB.swift/blob/master/README.md#database-snapshots) with a guaranteed snapshot content.

Outside of those use cases, it is much likely *wrong* to use a changes observables. Please [open an issue] and come discuss if you have any question.


## Values Observables

**Values Observables are all about getting fresh database values**.

They all emit in the RxSwift scheduler of your choice, or, by default, on the main queue:

```swift
// On any thread
Player.all().rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { players: [Player] in
        // On the main queue
        print("Players have changed.")
    })
```

When a values observable is subscribed from the main queue, and doesn't specify any specific scheduler, you are guaranteed that the initial values are synchronously fetched:

```swift
// On the main queue
Player.all().rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { players: [Player] in
        print("Players have changed.")
    })
// <- Here "Players have changed" is guaranteed to be printed.
```

This guarantee is lifted whenever you provide a specific scheduler (including `MainScheduler.instance`), or when the observable is not subscribed from the main queue:

```swift
Player.all().rx
    .fetchAll(in: dbQueue, scheduler: MainScheduler.instance)
    .subscribe(onNext: { players: [Player] in
        print("Players have changed.")
    })
// <- Here "Players have changed" may not be printed yet.
```

Unlike initial values, all changes notifications are always emitted asynchronously:

```swift
try dbQueue.write { db in
    try Player(name: "Arthur").insert(db)
}
// <- Here "Players have changed" may not be printed yet.
```

Depending on whether you use a [database queue], or a [database pool], the values emitted by such an observable are exactly the same. But the concurrent behavior changes.

- [Values Observables in a Database Queue](#values-observables-in-a-database-queue)
- [Values Observables in a Database Pool](#values-observables-in-a-database-pool)


### Values Observables in a Database Queue

In a [database queue], values observables fetch fresh values immediately after a database transaction has modified the tracked tables and columns

 transaction has completed.

**They block all threads that are accessing the database, or attempting to access in the database, until fresh values are fetched:**

```swift
Player.all().rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { players: [Player] in
        // On the main queue
        print("Players have changed.")
    })
    
// Insert, and wait until fresh players have been fetched
try dbQueue.write { db in
    try Player(name: "Arthur").insert(db)
}
```

Fortunately, fetching values is usually [quite fast](https://github.com/groue/GRDB.swift/wiki/Performance).

Yet some complex queries take a long time, and you may experience undesired blocking. In this case, consider replacing the database queue with a database pool, because that's what database pools are for: *efficient multi-threading*.


### Values Observables in a Database Pool

In a [database pool], values observables *eventually* fetch fresh values after a database transaction has modified the tracked tables and columns.

**They block all threads that are writing in the database, or attempting to write in the database, until [snapshot isolation](https://sqlite.org/isolation.html) has been established,** and fresh values can be safely fetched:

```swift
Player.all().rx
    .fetchAll(in: dbPool)
    .subscribe(onNext: { players: [Player] in
        // On the main queue
        print("Players have changed.")
    })

// Insert, and wait for snapshot isolation establishment
try dbPool.write { db in
    try Player(name: "Arthur").insert(db)
}
```

Acquiring snapshot isolation is very fast. The only limiting resource is the maximum number of concurrent reads (see [database pool configuration]).

Only after snapshot isolation has been established, the values observable fetches fresh values. During this fetch, other threads can freely read and write in the database.


## Common Use Cases of Values Observables

### Consuming fetched values on the main thread

```swift
// On any thread
Player.all().rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { players: [Player] in
        // On the main queue
        print("Players have changed.")
    })
```

### Consuming fetched values off the main thread

The first example is OK, even if the main thread is still involved as a relay. The second example doesn't use the main thread at all:

```swift
let scheduler = SerialDispatchQueueScheduler(qos: .default)

// On any thread
Player.all().rx
    .fetchAll(in: dbQueue)
    .observeOn(scheduler) // hops from main thread to global dispatch queue
    .subscribe(onNext: { db: Database in
        // Off the main thread, in the global dispatch queue
        print("Players have changed.")
    })

// On any thread
Player.all().rx
    .fetchAll(in: dbQueue, scheduler: scheduler)
    .subscribe(onNext: { db: Database in
        // Off the main thread, in the global dispatch queue
        print("Players have changed.")
    })
```


[contact]: http://twitter.com/groue
[database connection]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections
[database pool]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-pools
[database pool configuration]: https://github.com/groue/GRDB.swift/blob/master/README.md#databasepool-configuration
[database queue]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-queues
[GRDB Concurrency Guide]: https://github.com/groue/GRDB.swift/blob/master/README.md#concurrency
[Isolation In SQLite]: https://sqlite.org/isolation.html
[query interface]: https://github.com/groue/GRDB.swift/blob/master/README.md#requests
[GRDB requests]: https://github.com/groue/GRDB.swift/blob/master/README.md#requests
[open an issue]: https://github.com/RxSwiftCommunity/RxGRDB/issues
[TransactionObserver]: https://github.com/groue/GRDB.swift/blob/master/README.md#transactionobserver-protocol
[DatabaseRegion]: https://github.com/groue/GRDB.swift/blob/master/README.md#databaseregion
[ValueObservation]: https://github.com/groue/GRDB.swift/blob/master/README.md#valueobservation
