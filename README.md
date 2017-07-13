RxGRDB [![Swift](https://img.shields.io/badge/swift-3.1-orange.svg?style=flat)](https://developer.apple.com/swift/) [![Platforms](https://img.shields.io/cocoapods/p/RxGRDB.svg)](https://developer.apple.com/swift/) [![License](https://img.shields.io/github/license/RxSwiftCommunity/RxGRDB.svg?maxAge=2592000)](/LICENSE)
======

### A set of reactive extensions for SQLite and [GRDB.swift](http://github.com/groue/GRDB.swift)

**Latest release**: July 13, 2017 &bull; version 0.6.0 &bull; [Release Notes](CHANGELOG.md)

**Requirements**: iOS 8.0+ / OSX 10.10+ / watchOS 2.0+ • Xcode 8.3+ • Swift 3.1

---

## Usage

**RxGRDB produces RxSwift observables from GRDB requests.**

GRDB requests are built with the [query interface](https://github.com/groue/GRDB.swift#the-query-interface) or raw SQL. For example:

```swift
// Query Interface request
let request = Player.order(scoreColumn.desc).limit(10)

// SQL request
let request = SQLRequest(
    "SELECT * FROM players ORDER BY score DESC LIMIT 10")
    .asRequest(of: Player.self)
```

You can fetch values from those requests, or track them in a reactive way with RxGRDB:

```swift
// Non-reactive
try dbQueue.inDatabase { db in
    let players = try request.fetchAll(db) // [Player]
}

// Reactive:
request.rx.fetchAll(in: dbQueue)
    .subscribe(onNext: { players: [Player] in
        print("Players have changed")
    })
```


Documentation
=============

- [Installation](#installation)
- [What is Request Observation?](#what-is-request-observation)
- [Observing Individual Requests](#observing-individual-requests)
- [Observing Multiple Requests](#observing-multiple-requests)


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


## What is Request Observation?

**RxGRBD lets your application observe database requests, and get notified each time a change in their results has been committed in the database.**

```swift
let request = Player.order(scoreColumn.desc).limit(10)
request.rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { players: [Player] in
        print("Players have changed: \(players)")
    })
```

To define requests and connect to the database, please refer to [GRDB](https://github.com/groue/GRDB.swift), the database library that supports RxGRDB.


### What is a Request Change?

What are the "changes" tracked by RxGRDB? Is there an opportunity for missed changes? Can change notifications happen even when the request results are the same?

**First things first: RxGRDB requires that a unique database [connection](https://github.com/groue/GRDB.swift#database-connections) is connected to a database file during the whole duration of the observation.** 

**A change is a committed transaction that has impacted a tracked request.** No insertion, update, or deletion in a tracked table is missed. This includes changes to requests that involve several tables. This also includes indirect changes triggered by [foreign keys](https://www.sqlite.org/foreignkeys.html#fk_actions) or [SQL triggers](https://www.sqlite.org/lang_createtrigger.html).

> :point_up: **Note**: some special changes are not notified: changes to SQLite system tables (such as `sqlite_master`), and changes to [`WITHOUT ROWID`](https://www.sqlite.org/withoutrowid.html) tables. See [Data Change Notification Callbacks](https://www.sqlite.org/c3ref/update_hook.html) for more information.

**Change notifications may happen even though the request results are the same.** By default, RxGRDB notifies of *potential changes*, not of *actual changes*. A transaction triggers a change notification if and only if a statement has actually modified the tracked tables and columns by inserting, updating, or deleting a row.

For example, if you track `Player.select(max(score))`, then you'll get a notification for all changes performed on the `score` column of the `players` table (updates, insertions and deletions), even if they do not modify the value of the maximum score. However, you will not get any notification for changes performed on other database tables, or updates to other columns of the `players` table.

**It is possible to avoid notifications of identical consecutive values**. For example you can use the [`distinctUntilChanged`](http://reactivex.io/documentation/operators/distinct.html) operator of RxSwift. You can also let RxGRDB perform efficient deduplication at the database level: see the documentation of each reactive method for more information.


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

Emits a database connection after each [impactful](#what-is-a-request-change) database transaction:

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

All elements are emitted on the database writer dispatch queue, serialized with all database updates. See [GRDB Concurrency](https://github.com/groue/GRDB.swift#concurrency) for more information.


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

Emits a count after each [impactful](#what-is-a-request-change) database transaction:

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

If you set `synchronizedStart` to true (the default value), the first element is emitted synchronously upon subscription.

Other elements are asynchronously emitted on `resultQueue`, in chronological order of transactions. The queue is `DispatchQueue.main` by default.

**This observable may emit identical consecutive values**, because RxGRDB tracks [potential](#what-is-a-request-change) changes. Use the [`distinctUntilChanged`](http://reactivex.io/documentation/operators/distinct.html) operator in order to avoid duplicates:

```swift
request.rx.fetchCount(in: dbQueue).distinctUntilChanged()...
```


---

#### `TypedRequest.rx.fetchOne(in:synchronizedStart:distinctUntilChanged:resultQueue:)`

Emits a value after each [impactful](#what-is-a-request-change) database transaction:

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

If you set `synchronizedStart` to true (the default value), the first element is emitted synchronously upon subscription.

Other elements are asynchronously emitted on `resultQueue`, in chronological order of transactions. The queue is `DispatchQueue.main` by default.


**You can also track SQL requests, and choose the fetched type** (database [row](https://github.com/groue/GRDB.swift#row-queries), plain [value](https://github.com/groue/GRDB.swift#values), custom [record](https://github.com/groue/GRDB.swift#records)). The sample code below tracks an `Int` value fetched from a custom SQL request:

```swift
let request = SQLRequest("SELECT MAX(score) FROM rounds").asRequest(of: Int.self)
request.rx.fetchOne(in: dbQueue)
    .subscribe(onNext: { maxScore: Int? in
        print(maxScore)
    })
```

When tracking a *value*, you get nil in two cases: either the request yielded no database row, or one row with a NULL value.


**This observable may emit identical consecutive values**, because RxGRDB tracks [potential](#what-is-a-request-change) changes. Use the `distinctUntilChanged` parameter in order to avoid duplicates:

```swift
request.rx.fetchOne(in: dbQueue, distinctUntilChanged: true)...
```

The `distinctUntilChanged` parameter does not involve the fetched type, and simply performs comparisons of raw database values.


---

#### `TypedRequest.rx.fetchAll(in:synchronizedStart:distinctUntilChanged:resultQueue:)`

Emits an array of values after each [impactful](#what-is-a-request-change) database transaction:

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

If you set `synchronizedStart` to true (the default value), the first element is emitted synchronously upon subscription.

Other elements are asynchronously emitted on `resultQueue`, in chronological order of transactions. The queue is `DispatchQueue.main` by default.


**You can also track SQL requests, and choose the fetched type** (database [row](https://github.com/groue/GRDB.swift#row-queries), plain [value](https://github.com/groue/GRDB.swift#values), custom [record](https://github.com/groue/GRDB.swift#records)). The sample code below tracks an array of `URL` values fetched from a custom SQL request:

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


**This observable may emit identical consecutive values**, because RxGRDB tracks [potential](#what-is-a-request-change) changes. Use the `distinctUntilChanged` parameter in order to avoid duplicates:

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

Those observables can be composed together using [RxSwift operators](https://github.com/ReactiveX/RxSwift). However such composition won't provide some specific scheduling requirements:

To get a single notification when a transaction has modified several requests, use [DatabaseWriter.rx.changes](#databasewriterrxchangesinsynchronizedstart).

When some change happens, you can fetch from several requests with the guarantee of consistent results: see [Change Tokens](#change-tokens).

- [`DatabaseWriter.rx.changes`](#databasewriterrxchangesinsynchronizedstart)
- [Change Tokens](#change-tokens)
- [`DatabaseWriter.rx.changeTokens`](#databasewriterrxchangeTokensinsynchronizedstart)
- [`mapFetch` Operator](#observablefetchresultqueueelement)
- [Advanced: Differences between `changeTokens.mapFetch` and `changes.map.observeOn`](#advanced-differences-between-changetokensmapfetch-and-changesmapobserveon)


---

#### `DatabaseWriter.rx.changes(in:synchronizedStart:)`

Emits a database connection after each database transaction that has an [impact](#what-is-a-request-change) on any of the tracked requests:

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

All elements are emitted on the database writer dispatch queue, serialized with all database updates. See [GRDB Concurrency](https://github.com/groue/GRDB.swift#concurrency) for more information.


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

`changeTokens(in:)` emits *change tokens* for all database transactions that modifies some requests. Those change tokens are consumed by the `mapFetch` operator, which turns them into the fetched results of your choice.

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

- [`DatabaseWriter.rx.changeTokens`](#databasewriterrxchangeTokensinsynchronizedstart)
- [`mapFetch` Operator](#observablefetchresultqueueelement)
- [Advanced: Differences between `changeTokens.mapFetch` and `changes.map.observeOn`](#advanced-differences-between-changetokensmapfetch-and-changesmapobserveon)


---

#### `DatabaseWriter.rx.changeTokens(in:synchronizedStart:)`

Given a database writer ([database queue](https://github.com/groue/GRDB.swift#database-queues) or [database pool](https://github.com/groue/GRDB.swift#database-pools)), emits a [change token](#change-tokens) after each database transaction that has an [impact](#what-is-a-request-change) on any of the tracked requests:

```swift
let players = Player.all()
let teams = Team.all()

// Observable<ChangeToken>
let changeTokens = dbQueue.rx.changeTokens(in: [players, teams]) // or dbPool
```

If you set `synchronizedStart` to true (the default value), the first element is emitted synchronously upon subscription.

All elements are emitted on the database writer dispatch queue, serialized with all database updates. See [GRDB Concurrency](https://github.com/groue/GRDB.swift#concurrency) for more information.

A sequence of change tokens is designed to be consumed by the [mapFetch](#observablefetchresultqueueelement) operator.


---

#### `mapFetch` Operator

Transforms a sequence of [change tokens](#change-tokens) into fetched values.

```swift
let changeTokens = ... // Observable<ChangeToken>
    
// Observable<[Player]>
let players = changeTokens.mapFetch { (db: Database) in
    try Player.fetchAll(db)
}
```

If the source sequence of change tokens has been produced with the `synchronizedStart` option, the first fetched result is emitted synchronously upon subscription (see [`DatabaseWriter.rx.changeTokens`](#databasewriterrxchangeTokensinsynchronizedstart)).

Other elements are asynchronously emitted on the main dispatch queue by default. You can change the target queue:

```swift
changeTokens.mapFetch(resultQueue: ...) { ... }
```

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



---

### Advanced: Differences between `changeTokens.mapFetch` and `changes.map.observeOn`

The two observables below are very similar:

```swift
// changeTokens.mapFetch
dbQueue.rx
    .changeTokens(in: [...])
    .mapFetch { (db: Database) in
        return ...
    }

// changes.map.observeOn
dbQueue.rx
    .changes(in: [...])
    .map { (db: Database) in
        return ...
    }
    .observeOn(MainScheduler.instance)
```

They produce exactly the same results. Yet they don't have the same runtime behavior:

- `changes.map.observeOn` emits an initial value on subscription, which is *asynchronously* scheduled by the [MainScheduler](https://github.com/ReactiveX/RxSwift/blob/master/Documentation/Schedulers.md). The initial value of `changeTokens.mapFetch` is emitted *synchronously*, right on subscription.

- `changeTokens.mapFetch` is more efficient than `changes.map.observeOn`, when you use a [database pool](https://github.com/groue/GRDB.swift#database-pools) and leverage the enhanced multithreading of SQLite's [WAL mode](https://www.sqlite.org/wal.html):
    
    `changes.map.observeOn` locks the database for the whole duration of the fetch, when `changeTokens.mapFetch` is able to release the database before the fetch starts, while preserving the desired isolation guarantees. See [Advanced DatabasePool](https://github.com/groue/GRDB.swift#advanced-databasepool) for more information and context.
