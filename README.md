RxGRDB [![Swift](https://img.shields.io/badge/swift-3-orange.svg?style=flat)](https://developer.apple.com/swift/) [![Platforms](https://img.shields.io/cocoapods/p/RxGRDB.svg)](https://developer.apple.com/swift/) [![License](https://img.shields.io/github/license/groue/RxGRDB.svg?maxAge=2592000)](/LICENSE)
======

### A set of reactive extensions for [GRDB.swift](http://github.com/groue/GRDB.swift)

----

<p align="center">
<strong>THIS IS AN EXPERIMENTAL REPOSITORY</strong>
</p>

----


RxGRDB produces observables from [GRDB's requests](https://github.com/groue/GRDB.swift#requests).

Requests can be written as SQL, or with the query interface:

```swift
let request = SQLRequest("SELECT * FROM persons")
let request = Person.all()
```

Some requests are bound to a fetched type, these are "typed requests":

```swift
// Person request
let persons = Person.all()
```


##### `Request.rx.changes(in:synchronizedStart:)`

Emits a database connection after each transaction that has updated the table and columns fetched by the request:

```swift
let dbQueue = try DatabaseQueue(...) // or DatabasePool
let request = Person.all()
request.rx
    .changes(in: dbQueue)
    .subscribe(onNext: { db: Database in
        print("Persons table has changed.")
    })
```

If you set `synchronizedStart` to true (the default value), the first element will be emitted synchronously.


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

If you set `synchronizedStart` to true (the default value), the first element will be emitted synchronously.

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


##### `TypedRequest.rx.fetchAll(in:synchronizedStart:resultQueue:)`

Emits a array of values after each transaction that has updated the table and columns fetched by the request:

```swift
let request = Person.all()
request.rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { person: Person? in
        print(person)
    })
```
