Release Notes
=============

## v0.3.0

Released May 22, 2017

**New**

- The new `distinctUntilChanged` parameter has RxGRDB avoid notifying consecutive identical values.

    ```swift
    request.rx.fetchAll(in: dbQueue, distinctUntilChanged: true)...
    ```

- Tracking of requests that fetch an array of optional values:
    
    ```swift
    // Email column may be NULL:
    let request = Person.select(email).bound(to: Optional<String>.self)
    request.rx.fetchAll(in: dbQueue)
        .subscribe(onNext: { emails: [String?] in
            ...
        })
    ```


## v0.2.0

Released May 17, 2017

**New**

- Support for SQLCipher.


## v0.1.2

Released April 6, 2017

**Fixed**

- RxGRDB observables now support the `retry` operator, and no longer crash when disposed on a database queue.


## v0.1.1

Released April 5, 2017

**New**

- `synchronizedStart` option
- `Request.rx.fetchCount(in:synchronizedStart)`


## v0.1.0

Released April 5, 2017

Initial release
