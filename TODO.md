- [ ] RxGRDB/Documentation/RxGRDBDemo/RxGRDBDemo/Models/Players.swift

    TODO GRDB: If we define the `database` property as AnyDatabaseWriter
and erase the type in the initializer, we have a crash when the
database changes and observations are triggered. Workaround: perform
late type erasing.

    TODO RxRGDB: We could avoid this churn by exposing observables
without the `rx` joiner, directly on DatabaseWriter and
DatabaseReader protocols, as in GRDBCombine.
