RxGRDB
======

### A set of reactive extensions for [GRDB.swift](http://github.com/groue/GRDB.swift)

----

<p align="center">
<strong>THIS IS AN EXPERIMENTAL REPOSITORY</strong>
</p>

----

Open a database connection first:

```swift
let dbQueue = try DatabaseQueue(...) // or DatabasePool
```

- [Observe Transactions that Impact a Request](#observe-transactions-that-impact-a-request):
    
    ```swift
    request.rx.changes(in:)     // Observable<Database>
    ```
    
- [Observe the Results of a Request](#observe-the-results-of-a-request)
    
    ```swift
    request.rx.fetchOne(in:)    // Observable<T>
    request.rx.fetchAll(in:)    // Observable<T>
    request.rx.fetchCount(in:)  // Observable<Int>
    ```


### Observe Transactions that Impact a Request

Given a request, you can observe all transactions that have an impact on the tables and columns queried by the request:

```swift
let request = SQLRequest("SELECT * FROM persons") // Using SQL
let request = Person.all()                        // Using the query interface

// A database connection is immediately emitted on subscription, and later
// after each committed database transaction that has modified the tables and
// columns fetched by the request:
request.rx
    .changes(in: dbQueue)
    .subscribe(onNext: { db: Database in
        let count = try! request.fetchCount(db)
        print("Number of persons: \(count)")
    })
// Prints "Number of persons: 0"

try dbQueue.inDatabase { db in
    try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
    // Prints "Number of persons: 1"
    try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Barbara"])
    // Prints "Number of persons: 2"
}

try dbQueue.inTransaction { db in
    try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Craig"])
    try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["David"])
    return .commit
}
// Prints "Number of persons: 4"
```


### Observe the Results of a Request

Given a request, you can fetch a record, or register for all changes to the fetched record:

```swift
let request = Person.filter(Column("email") == "arthur@example.com")

// Non reactive:
let arthur = try dbQueue.inDatabase { try request.fetchOne($0) }

// Reactive: an optional record is immediately emitted on subscription, and
// after each committed database transaction that has modified the tables and
// columns fetched by the request:
request.rx
    .fetchOne(in: dbQueue)
    .subscribe(onNext: { person: Person? in
        // On the main queue
    })
```

Given a request, you can fetch an array of records, or register for all changes to the fetched records:

```swift
let request = Person.order(Column("name"))

// Non reactive:
let persons = try dbQueue.inDatabase { try request.fetchAll($0) }

// Reactive: an array of records is immediately emitted on subscription, and
// after each committed database transaction that has modified the tables and
// columns fetched by the request.
request.rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { persons: [Person] in
        // On the main queue
    })
```

Given a request, you can count its results, or register for all changes to that count:

```swift
let request = Person.all()

// Non reactive:
let count = try dbQueue.inDatabase { try request.fetchCount($0) }

// Reactive: the count is immediately emitted on subscription, and
// after each committed database transaction that has modified the tables and
// columns fetched by the request.
request.rx
    .fetchCount(in: dbQueue)
    .subscribe(onNext: { count: Int in
        // On the main queue
    })
```
