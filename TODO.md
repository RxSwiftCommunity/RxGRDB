- [ ] RxGRDB/Documentation/RxGRDBDemo/RxGRDBDemo/Models/Players.swift

    TODO GRDB: If we define the `database` property as AnyDatabaseWriter
and erase the type in the initializer, we have a crash when the
database changes and observations are triggered. Workaround: perform
late type erasing.

    TODO RxRGDB: We could avoid this churn by exposing observables
without the `rx` joiner, directly on DatabaseWriter and
DatabaseReader protocols, as in GRDBCombine.

- [ ] Expose a new observation mode that doesn't guarantee the notification of all changes, but can start immediately when one uses a DatabasePool. See https://github.com/groue/GRDB.swift/issues/601#issuecomment-524545056

- [ ] Optimization: cancel the initial fetch of a value observation, and its registration as a database observer, if the wrapping Observable has been cancelled. See https://github.com/groue/GRDB.swift/issues/601#issuecomment-524648244
