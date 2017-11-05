- [ ] Test observation of several requests at the same time
- [ ] Use schedulers with mapFetch, and force the same scheduler on both subscription and observation.
- [ ] Allow one to pause values observation, and restart with fresh values
- [ ] Single record observation

    GRDB.SelectStatement.SelectionInfo only knows tables and columns. When one tracks a single row identified by its primary key, RxGRDB has to perform a database fetch for changes performed on other rows:
    
    ```swift
    // Access the database even when other rows are modified.
    Player.filter(id == 1).rx
      .fetchOne(in: dbQueue, distinctUntilChanged: true)
    ```
    
    This could be enhanced. It's a valid RxGRDB use case to track one record. Or even several records at the same time, for the same reason that one may track several requests at the same time: in order to guarantee data consistency.
    
    We could introduce a RxGRDB type for "observed database area" (`DatabaseSelection` ?), which could be defined as:
    - the selectionInfo of a statement (multiple tables & columns, as we have today)
    - a record (table + columns + primary key)
    
    The `DatabaseWriter.rx.changes(in requests: [Request], synchronizedStart: Bool)` method, which is at the origin of all observations, would then change to `DatabaseWriter.rx.changes(in selections: [DatabaseSelectionConvertible], synchronizedStart: Bool)`.
    
    We could then write:
    
    ```swift
    let player: Player = ...
    let country: Country = ...
    dbQueue.rx.changes(in: [player]) // Observable<Database>
    dbQueue.rx.changes(in: [player, country]) // Observable<Database>
    player.rx.changes(in: dbQueue) // Observable<Database>
    player.rx.fetchOne(in: dbQueue) // Observable<Player?>
    ```
    
    Could be improved: `player.rx.fetchOne` which is not quite pleasant to the eye.
    
    Could be improved: the way to observe N records, and fetch them back:
    
    ```swift
    let playerId = player.id
    let countryCode = country.code
    dbQueue.rx
        .changeTokens(in: [player, country])
        .mapFetch { db in
            let player = Player.fetchOne(db, key: playerId)
            let country = Country.fetchOne(db, key: countryCode)
            return (player, country)
        }
        .subscribe(onNext: { (player, country) in
            ...
        })
    ```
    
