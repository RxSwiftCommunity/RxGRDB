RxGRDB [![Swift](https://img.shields.io/badge/swift-3.1-orange.svg?style=flat)](https://developer.apple.com/swift/) [![Platforms](https://img.shields.io/cocoapods/p/RxGRDB.svg)](https://developer.apple.com/swift/) [![License](https://img.shields.io/github/license/RxSwiftCommunity/RxGRDB.svg?maxAge=2592000)](/LICENSE)
======

### A set of reactive extensions for SQLite and [GRDB.swift](http://github.com/groue/GRDB.swift)

**Latest release**: April 6, 2017 &bull; version 0.1.2 &bull; [Release Notes](CHANGELOG.md)

**Requirements**: iOS 8.0+ / OSX 10.10+ / watchOS 2.0+ • Xcode 8.3+ • Swift 3.1

---

## Usage

**RxGRDB produces RxSwift observables from GRDB requests.**

GRDB requests are built with the [query interface](https://github.com/groue/GRDB.swift#the-query-interface). For example:

```swift
let request = Person.filter(emailColumn != nil).order(nameColumn)
```

You can fetch values from those requests, or track them in a reactive way with RxGRDB:

```swift
// Non-reactive
try dbQueue.inDatabase { db in
    let persons = try request.fetchAll(db) // [Person]
}

// Reactive:
let persons = request.rx.fetchAll(in: dbQueue)
persons.subscribe(onNext: { persons: [Person] in
    ...
})
```


## Documentation

- [Installation](#installation)
- [Observing Requests](#observing-requests)
- [What Exactly is a Request Change?](#what-exactly-is-a-request-change)


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

RxGRBD can track all database transactions that have [modified](#what-exactly-is-a-request-change) the database tables and columns fetched by a request. Modifications on other tables or columns are ignored.

If you are only interested in the *values* fetched by the request, then RxGRDB can fetch them for you after each database modification, and emit them in order, ready for consumption. See the [`rx.fetchCount`](#requestrxfetchcountinsynchronizedstartresultqueue), [`rx.fetchOne`](#typedrequestrxfetchoneinsynchronizedstartresultqueue), and [`rx.fetchAll`](#typedrequestrxfetchallinsynchronizedstartresultqueue) methods, depending on whether you want to track the number of results, the first one, or all of them.

Some applications need to be synchronously notified right after any impactful transaction has been committed, and before any other thread has the opportunity to further modify the database. This feature is provided by the [`rx.changes`](#requestrxchangesinsynchronizedstart) method.


##### `Request.rx.changes(in:synchronizedStart:)`

Emits a database connection after each impactful database transaction:

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

A variant, with SQL:

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


##### `Request.rx.fetchCount(in:synchronizedStart:resultQueue:)`

Emits a count after each impactful database transaction:

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

Other elements are emitted on `resultQueue`, which defaults to `DispatchQueue.main`.


##### `TypedRequest.rx.fetchOne(in:synchronizedStart:resultQueue:)`

Emits a value after each impactful database transaction:

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

Other elements are emitted on `resultQueue`, which defaults to `DispatchQueue.main`.

A variant, with SQL and an alternative fetched type:

```swift
let request = SQLRequest("SELECT MAX(score) FROM rounds").bound(to: Int.self)
request.rx.fetchOne(in: dbQueue)
    .subscribe(onNext: { maxScore: Int? in
        print(maxScore)
    })
```


##### `TypedRequest.rx.fetchAll(in:synchronizedStart:resultQueue:)`

Emits an array of values after each impactful database transaction:

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

Other elements are emitted on `resultQueue`, which defaults to `DispatchQueue.main`.

A variant, with SQL and an alternative fetched type:

```swift
let request = SQLRequest("SELECT urls FROM links").bound(to: URL.self)
request.rx.fetchAll(in: dbQueue)
    .subscribe(onNext: { urls: [URL] in
        print(urls)
    })
```

### What Exactly is a Request Change?

What exactly are the "request changes" tracked by RxGRDB? Is there an opportunity for missed changes? Can change notifications happen even when the request results are the same?

**First things first**: to perform reliably, RxGRDB requires a unique instance of GRDB [database queue](https://github.com/groue/GRDB.swift#database-queues) or [database pool](https://github.com/groue/GRDB.swift#database-pools) connected to the database file. This is the 1st rule of [GRBD concurrency](https://github.com/groue/GRDB.swift#concurrency).

**No change should ever be missed, ever.** No matter how complex is the tracked request, or if the change is performed via a direct modification, a foreign key cascade, or even an SQL trigger. That is because RxGRDB is based on fast and reliable SQLite APIs such as [Compile-Time Authorization Callbacks](https://sqlite.org/c3ref/set_authorizer.html), [Commit And Rollback Notification Callbacks](https://www.sqlite.org/c3ref/commit_hook.html), and [Data Change Notification Callbacks](https://www.sqlite.org/c3ref/update_hook.html). If you notice a change that is not notified, then this is a bug: please open an [issue](https://github.com/RxSwiftCommunity/RxGRDB/issues).

**Some change notifications happen even though the request results are the same.** RxGRDB notifies of *potential changes*, not of *actual changes*. A transaction triggers a change notification if and only if a statement that modifies the tracked tables and columns has been executed, has actually inserted, updated, or deleted a row, and has not been rollbacked along with the transaction or a savepoint.

For example, if you track `Player.select(max(score))` (SQL: `SELECT MAX(score) FROM players`), then you'll get a notification for all the changes below, even if they do not modify the value of the maximum score:

- insertions in the `players` table.
- deletions in the `players` table.
- updates to the `score` column of the `players` table.
- other changes that indirectly touch the `score` column of the `players` table, through foreign key cascades or SQL triggers.

However, you will not get any notification:

- for changes performed on other database tables.
- for updates to the columns of the `players` table which are not `score`.

