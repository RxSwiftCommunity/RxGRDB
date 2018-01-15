Release Notes
=============

## Next Version

This version is focused on enhancing the scheduling of database notifications.


## Fixed

- RxGRDB observables used to require subscription and observation to happen on the same dispatch queue. It was easy to fail this precondition, and misuse the library. This has been fixed.
- The [demo application](https://github.com/RxSwiftCommunity/RxGRDB/tree/master/Documentation/RxGRDBDemo) used to misuse MKMapView by converting database changes into annotation coordinate updates on the wrong dispatch queue. This has been fixed.


### Breaking Changes

- Database observation scheduling used to be managed through raw dispatch queues. One now uses regular [RxSwift schedulers](https://github.com/ReactiveX/RxSwift/blob/master/Documentation/Schedulers.md). See the updated [documentation](https://github.com/RxSwiftCommunity/RxGRDB/blob/master/README.md#documentation) of RxGRDB reactive methods.
- The `Diffable` protocol was ill-advised, and has been removed.
- The `primaryKeySortedDiff` operator has been replaced by `PrimaryKeyDiffScanner` ([documentation](https://github.com/RxSwiftCommunity/RxGRDB/blob/master/README.md#primarykeydiffscanner))


### API diff

```diff
 extension Reactive where Base: Request {
-    func fetchCount(
-        in writer: DatabaseWriter,
-        synchronizedStart: Bool = true,
-        resultQueue: DispatchQueue = DispatchQueue.main)
-        -> Observable<Int>
+    func fetchCount(
+        in writer: DatabaseWriter,
+        synchronizedStart: Bool = true,
+        scheduler: SerialDispatchQueueScheduler = MainScheduler.instance)
+        -> Observable<Int>
 }

 extension Reactive where Base: TypedRequest {
-    func fetchAll(
-        in writer: DatabaseWriter,
-        synchronizedStart: Bool = true,
-        resultQueue: DispatchQueue = DispatchQueue.main,
-        distinctUntilChanged: Bool = false)
-        -> Observable<[Base.RowDecoder]>
+    func fetchAll(
+        in writer: DatabaseWriter,
+        synchronizedStart: Bool = true,
+        scheduler: SerialDispatchQueueScheduler = MainScheduler.instance,
+        distinctUntilChanged: Bool = false)
+        -> Observable<[Base.RowDecoder]>
-    func fetchOne(
-        in writer: DatabaseWriter,
-        synchronizedStart: Bool = true,
-        resultQueue: DispatchQueue = DispatchQueue.main,
-        distinctUntilChanged: Bool = false)
-        -> Observable<Base.RowDecoder?>
+    func fetchOne(
+        in writer: DatabaseWriter,
+        synchronizedStart: Bool = true,
+        scheduler: SerialDispatchQueueScheduler = MainScheduler.instance,
+        distinctUntilChanged: Bool = false)
+        -> Observable<Base.RowDecoder?>
 }

 extension ObservableType where E == ChangeToken {
-    func mapFetch<R>(
-        resultQueue: DispatchQueue = DispatchQueue.main,
-        _ fetch: @escaping (Database) throws -> R)
-        -> Observable<R>
+    func mapFetch<R>(_ fetch: @escaping (Database) throws -> R) -> Observable<R>
 }

 extension Reactive where Base: DatabaseWriter {
-    func changeTokens(
-        in requests: [Request],
-        synchronizedStart: Bool = true)
-        -> Observable<ChangeToken>
+    func changeTokens(
+        in requests: [Request],
+        synchronizedStart: Bool = true,
+        scheduler: SerialDispatchQueueScheduler = MainScheduler.instance)
+        -> Observable<ChangeToken>
 }

-protocol Diffable {
-    func updated(with row: Row) -> Self
-}
-extension Reactive where Base: TypedRequest, Base.RowDecoder: RowConvertible & MutablePersistable & Diffable {
-    func primaryKeySortedDiff(
-        in writer: DatabaseWriter,
-        initialElements: [Base.RowDecoder] = [])
-        -> Observable<PrimaryKeySortedDiff<Base.RowDecoder>>
-}
-struct PrimaryKeySortedDiff<Element> { ... }
+struct PrimaryKeyDiffScanner<Record: RowConvertible & MutablePersistable> {
+    let diff: PrimaryKeyDiff<Record>
+    init<Request>(
+            database: Database,
+            request: Request,
+            initialRecords: [Record],
+            updateRecord: ((Record, Row) -> Record)? = nil)
+            throws
+            where Request: TypedRequest, Request.RowDecoder == Record
+    func diffed(from rows: [Row]) -> PrimaryKeyDiffScanner
+}
+struct PrimaryKeyDiff<Record> {
+    let inserted: [Record]
+    let updated: [Record]
+    let deleted: [Record]
+    var isEmpty: Bool
+}
```

## 0.7.0

Released October 18, 2017 &bull; [diff](https://github.com/RxSwiftCommunity/RxGRDB/compare/v0.6.0...v0.7.0)

### New

- Support for Swift 4
- Support for various diff algorithms ([Documentation](https://github.com/RxSwiftCommunity/RxGRDB/blob/master/README.md#diffs))
- New [demo application](https://github.com/RxSwiftCommunity/RxGRDB/tree/master/Documentation/RxGRDBDemo) for various diff algorithms.

### Fixed

- Observables that emit fetched values used to emit their first element on the wrong dispatch queue when their `synchronizedStart` option is true. That first element is now correctly emitted on the subscription dispatch queue.

### Breaking Changes

- Requirements have changed: Xcode 9+, Swift 4, GRDB 2.0


## 0.6.0

Released July 13, 2017

- **Fixed**: Support for macOS, broken in v0.5.0
- **New**: GRDB dependency bumped to v1.2


## 0.5.0

Released July 8, 2017

### New

RxGRDB has learned how to observe multiple requests and fetch from other requests. [Documentation](https://github.com/RxSwiftCommunity/RxGRDB/blob/master/README.md#observing-multiple-requests)

To get a single notification when a transaction has modified several requests, use `DatabaseWriter.rx.changes`:

```swift
// Observable<Database>
dbQueue.rx.changes(in: [request, ...])
```

To turn a change notification into consistent results fetched from multiple requests, use `DatabaseWriter.rx.changeTokens` and the `mapFetch` operator:

```swift
dbQueue.rx
    .changeTokens(in: [request, ...])
    .mapFetch { (db: Database) in
        return ...
    }
```

### API diff

```diff
+extension Reactive where Base: DatabaseWriter {
+    func changes(in requests: [Request], synchronizedStart: Bool = true) -> Observable<Database>
+    func changeTokens(in requests: [Request], synchronizedStart: Bool = true) -> Observable<ChangeToken>
+}

+struct ChangeToken {
+    var database: Database { get }
+}

+extension ObservableType where E == ChangeToken {
+    func func mapFetch<R>(resultQueue: DispatchQueue = DispatchQueue.main, _ fetch: @escaping (Database) throws -> R) -> Observable<R>
+}
```


## 0.4.1

Released June 20, 2017

### Fixed

- Podspec requirement for RxSwift changed to `~> 3.3`
- Added missing support for new AdaptedRequest and AdaptedTypedRequest of GRDB 1.0


## 0.4.0

Released June 20, 2017

### Breaking Changes

- RxGRDB now requires GRDB v1.0


## 0.3.0

Released May 22, 2017

### New

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


## 0.2.0

Released May 17, 2017

### New

- Support for SQLCipher.


## 0.1.2

Released April 6, 2017

### Fixed

- RxGRDB observables now support the `retry` operator, and no longer crash when disposed on a database queue.


## 0.1.1

Released April 5, 2017

### New

- `synchronizedStart` option
- `Request.rx.fetchCount(in:synchronizedStart)`


## 0.1.0

Released April 5, 2017

Initial release
