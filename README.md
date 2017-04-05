RxGRDB [![Swift](https://img.shields.io/badge/swift-3-orange.svg?style=flat)](https://developer.apple.com/swift/) [![Platforms](https://img.shields.io/cocoapods/p/RxGRDB.svg)](https://developer.apple.com/swift/) [![License](https://img.shields.io/github/license/groue/RxGRDB.svg?maxAge=2592000)](/LICENSE)
======

### A set of reactive extensions for [GRDB.swift](http://github.com/groue/GRDB.swift)

----

<p align="center">
<strong>THIS IS AN EXPERIMENTAL REPOSITORY</strong>
</p>

----


RxGRDB produces observables from [GRDB's requests](https://github.com/groue/GRDB.swift#requests).

As a reminder, those requests are usually built from the [query interface](https://github.com/groue/GRDB.swift#the-query-interface):

```swift
let request = Person.all()
```

Requests offer four fetching methods that load values from the database:

```swift
let dbQueue = try DatabaseQueue(...) // or DatabasePool
try dbQueue.inDatabase { db in
    let request = Person.all()
    try request.fetchCount(db)  // Int
    try request.fetchOne(db)    // Person?
    try request.fetchAll(db)    // [Person]
    try request.fetchCursor(db) // DatabaseCursor<Person>
}
```


### Observing Requests

##### `Request.rx.changes(in:synchronizedStart:)`

Emits a database connection after each transaction that has updated the table and columns fetched by the request:

```swift
let request = Person.all()
request.rx
    .changes(in: dbQueue)
    .subscribe(onNext: { db: Database in
        print("Persons table has changed.")
    })
```

If you set `synchronizedStart` to true (the default value), the first element is emitted synchronously upon subscription.

All elements are emitted on the database writer dispatch queue, serialized with all database updates.

A variant, with SQL:

```swift
let request = SQLRequest("SELECT * FROM persons")
request.rx
    .changes(in: dbQueue)
    .subscribe(onNext: { db: Database in
        print("Persons table has changed.")
    })
```


##### `Request.rx.fetchCount(in:synchronizedStart:resultQueue:)`

Emits a count after each transaction that has updated the table and columns fetched by the request:

```swift
let request = Person.all()
request.rx
    .fetchCount(in: dbQueue)
    .subscribe(onNext: { count: Int in
        print("Number of persons: \(count)")
    })
```

If you set `synchronizedStart` to true (the default value), the first element is emitted synchronously upon subscription.

Other elements are emitted on `resultQueue`, which defaults to `DispatchQueue.main`.


##### `TypedRequest.rx.fetchOne(in:synchronizedStart:resultQueue:)`

Emits a value after each transaction that has updated the table and columns fetched by the request:

```swift
let request = Person.filter(Column("email") == "arthur@example.com")
request.rx
    .fetchOne(in: dbQueue)
    .subscribe(onNext: { person: Person? in
        print(person)
    })
```

A variant, with SQL and an alternative fetched type:

```swift
let request = SQLRequest("SELECT MAX(score) FROM rounds").bound(to: Int.self)
request.rx
    .fetchOne(in: dbQueue)
    .subscribe(onNext: { maxScore: Int? in
        print(maxScore)
    })
```


##### `TypedRequest.rx.fetchAll(in:synchronizedStart:resultQueue:)`

Emits an array of values after each transaction that has updated the table and columns fetched by the request:

```swift
let request = Person.all()
request.rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { persons: [Person] in
        print(persons)
    })
```

A variant, with SQL and an alternative fetched type:

```swift
let request = SQLRequest("SELECT urls FROM links").bound(to: URL.self)
request.rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { urls: [URL] in
        print(urls)
    })
```
