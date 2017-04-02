ReactiveGRDB
============

----

<p align="center">
<strong>THIS IS AN EXPERIMENTAL REPOSITORY</strong>
</p>

----

A set of reactive extensions for GRDB.swift.

```swift
let dbQueue = try DatabaseQueue(...) // or DatabasePool

// Emits an optional record immediately on subscription, and after each
// committed database transaction that has modified the tables and columns
// fetched by the Request.
Person.filter(Column("id") == 1).rx
    .fetchOne(in: dbQueue)
    .subscribe(onNext: { person: Person? in
        // On the main queue
    })

// Emits an array of records immediately on subscription, and after each
// committed database transaction that has modified the tables and columns
// fetched by the Request.
Person.order(Column("name")).rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { persons: [Person] in
        // On the main queue
    })

// Emits an array of records and an "event" immediately on subscription, and
// after each committed database transaction that has modified the tables and
// columns fetched by the Request.
Person.order(Column("name")).rx
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
