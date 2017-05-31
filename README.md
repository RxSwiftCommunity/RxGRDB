RxGRDB [![Swift](https://img.shields.io/badge/swift-3.1-orange.svg?style=flat)](https://developer.apple.com/swift/) [![Platforms](https://img.shields.io/cocoapods/p/RxGRDB.svg)](https://developer.apple.com/swift/) [![License](https://img.shields.io/github/license/RxSwiftCommunity/RxGRDB.svg?maxAge=2592000)](/LICENSE)
======

### A set of reactive extensions for SQLite and [GRDB.swift](http://github.com/groue/GRDB.swift)

**Latest release**: May 22, 2017 &bull; version 0.3.0 &bull; [Release Notes](CHANGELOG.md)

**Requirements**: iOS 8.0+ / OSX 10.10+ / watchOS 2.0+ • Xcode 8.3+ • Swift 3.1

---

## Usage

**RxGRDB produces RxSwift observables from GRDB requests.**

GRDB requests are built with the [query interface](https://github.com/groue/GRDB.swift#the-query-interface) or raw SQL. For example:

```swift
// Query Interface request
let request = Person.filter(emailColumn != nil).order(nameColumn)

// SQL request
let request = SQLRequest(
    "SELECT * FROM persons WHERE email IS NOT NULL ORDER BY name")
    .asRequest(of: Person.self)
```

You can fetch values from those requests, or track them in a reactive way with RxGRDB:

```swift
// Non-reactive
try dbQueue.inDatabase { db in
    let persons = try request.fetchAll(db) // [Person]
}

// Reactive:
request.rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { persons: [Person] in
        print("Persons have changed")
    })
```


## Documentation

- [Installation](#installation)
- [Observing Requests](#observing-requests)


### Installation

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


### Observing Requests

**When your application observes a request, it gets notified each time a change in the results of the request has been committed in the database.**

If you are only interested in the *values* fetched by the request, then RxGRDB can fetch them for you after each database modification, and emit them in order, ready for consumption. See the [rx.fetchCount](#requestrxfetchcountinsynchronizedstartresultqueue), [rx.fetchOne](#typedrequestrxfetchoneinsynchronizedstartresultqueue), and [rx.fetchAll](#typedrequestrxfetchallinsynchronizedstartresultqueue) methods, depending on whether you want to track the number of results, the first one, or all of them.

Some applications need to be synchronously notified right after any impactful transaction has been committed, and before any further database modification. This feature is provided by the [rx.changes](#requestrxchangesinsynchronizedstart) method.


- [What is a Request Change?](#what-is-a-request-change)
- [rx.changes](#requestrxchangesinsynchronizedstart)
- [rx.fetchCount](#requestrxfetchcountinsynchronizedstartresultqueue)
- [rx.fetchOne](#typedrequestrxfetchoneinsynchronizedstartdistinctuntilchangedresultqueue)
- [rx.fetchAll](#typedrequestrxfetchallinsynchronizedstartdistinctuntilchangedresultqueue)


### What is a Request Change?

What are the "request changes" tracked by RxGRDB? Is there an opportunity for missed changes? Can change notifications happen even when the request results are the same?

**First things first: RxGRDB requires a unique instance of GRDB [database queue](https://github.com/groue/GRDB.swift#database-queues) or [database pool](https://github.com/groue/GRDB.swift#database-pools) connected to the database file.** This is the 1st rule of [GRBD concurrency](https://github.com/groue/GRDB.swift#concurrency), and now it is bloody serious. Open one connection to the database, and keep this connection alive.

**All transactions that impact a tracked request are notified.** No insertion, update, or deletion in a tracked table is missed. This includes changes to requests that involve several tables, and indirect changes triggered by [foreign keys](https://www.sqlite.org/foreignkeys.html#fk_actions) or [triggers](https://www.sqlite.org/lang_createtrigger.html).

> :point_up: **Note**: some changes are not notified: changes to internal system tables (such as `sqlite_master`), and changes to [`WITHOUT ROWID`](https://www.sqlite.org/withoutrowid.html) tables. See [Data Change Notification Callbacks](https://www.sqlite.org/c3ref/update_hook.html) for more information.

**Some change notifications may happen even though the request results are the same.** By default, RxGRDB notifies of *potential changes*, not of *actual changes*. A transaction triggers a change notification if and only if a statement has actually modified the tracked tables and columns by inserting, updating, or deleting a row.

For example, if you track `Player.select(max(score))`, then you'll get a notification for all changes performed on the `score` column of the `players` table (updates, insertions and deletions), even if they do not modify the value of the maximum score. However, you will not get any notification for changes performed on other database tables, or updates to other columns of the `players` table.

**It is possible to avoid notifications of identical consecutive values**. For example you can use the [`distinctUntilChanged`](http://reactivex.io/documentation/operators/distinct.html) operator of RxSwift. You can also let RxGRDB perform efficient deduplication at the database level: see the documentation of each reactive method for more information.


---

#### `Request.rx.changes(in:synchronizedStart:)`

Emits a database connection after each [impactful](#what-is-a-request-change) database transaction:

```swift
let request = Person.all()
request.rx.changes(in: dbQueue)
    .subscribe(onNext: { db: Database in
        print("Persons table has changed.")
    })

try dbQueue.inDatabase { db in
    try Person.deleteAll(db)
    // Prints "Persons table has changed."
}

try dbQueue.inTransaction { db in
    try Person(name: "Arthur").insert(db)
    try Person(name: "Barbara").insert(db)
    return .commit
    // Prints "Persons table has changed."
}
```

If you set `synchronizedStart` to true (the default value), the first element is emitted synchronously upon subscription.

Other elements are emitted on the database writer dispatch queue, serialized with all database updates.


**You can also track SQL requests:**

```swift
let request = SQLRequest("SELECT * FROM persons")
request.rx.changes(in: dbQueue)
    .subscribe(onNext: { db: Database in
        print("Persons table has changed.")
    })

try dbQueue.inDatabase { db in
    try db.execute("DELETE FROM persons")
    // Prints "Persons table has changed."
}
```


---

#### `Request.rx.fetchCount(in:synchronizedStart:resultQueue:)`

Emits a count after each [impactful](#what-is-a-request-change) database transaction:

```swift
let request = Person.all()
request.rx.fetchCount(in: dbQueue)
    .subscribe(onNext: { count: Int in
        print("Number of persons: \(count)")
    })

try dbQueue.inTransaction { db in
    try Person.deleteAll(db)
    try Person(name: "Arthur").insert(db)
    return .commit
    // Eventually prints "Number of persons: 1"
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
let request = Person.filter(Column("email") == "arthur@example.com")
request.rx.fetchOne(in: dbQueue)
    .subscribe(onNext: { person: Person? in
        print(person?.name ?? "nil")
    })

try dbQueue.inDatabase { db in
    try Person.deleteAll(db)
    // Eventually prints "nil"
    
    try Person(name: "Arthur", email: "arthur@example.com").insert(db)
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
let request = Person.order(Column("name"))
request.rx.fetchAll(in: dbQueue)
    .subscribe(onNext: { persons: [Person] in
        print(persons.map { $0.name })
    })

try dbQueue.inTransaction { db in
    try Person.deleteAll(db)
    try Person(name: "Arthur").insert(db)
    try Person(name: "Barbara").insert(db)
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
let request = SQLRequest("SELECT email FROM persons").asRequest(of: Optional<String>.self)
request.rx.fetchAll(in: dbQueue)
    .subscribe(onNext: { emails: [String?] in
        print(urls)
    })
```


**This observable may emit identical consecutive values**, because RxGRDB tracks [potential](#what-is-a-request-change) changes. Use the `distinctUntilChanged` parameter in order to avoid duplicates:

```swift
request.rx.fetchAll(in: dbQueue, distinctUntilChanged: true)...
```

The `distinctUntilChanged` parameter does not involve the fetched type, and simply performs comparisons of raw database values.
