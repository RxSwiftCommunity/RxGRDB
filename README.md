ReactiveGRDB
============

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

Given a request, you can drive a UITableView or a UICollectionView:

```swift
let request = Person.order(Column("name"))

// Reactive: an array of records and an "event" are immediately emitted on
// subscription, and after each committed database transaction that has modified
// the tables and columns fetched by the request:
request.rx
    .diff(in: dbQueue)
    .subscribe(onNext: { (persons, event) in
        // On the main queue
        self.persons = persons
        switch event {
        case .snapshot:
            self.tableView.reloadData()
        case .diff(let changes):
            self.tableView.beginUpdates()
            for change in changes {
                switch change.kind {
                case .insertion(let indexPath):
                    self.tableView.insertRows(at: [indexPath], with: .fade)
                    
                case .deletion(let indexPath):
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                    
                case .update(let indexPath, _):
                    if let cell = self.tableView.cellForRow(at: indexPath) {
                        self.configure(cell, at: indexPath)
                    }
                    
                case .move(let indexPath, let newIndexPath, _):
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                    self.tableView.insertRows(at: [newIndexPath], with: .fade)
                }
                
            }
            self.tableView.endUpdates()
        }
    })
```
