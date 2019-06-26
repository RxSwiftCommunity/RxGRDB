RxGRDBDemo
==========

<img align="right" src="https://raw.githubusercontent.com/groue/RxGRDB/dev/demo-app/Documentation/RxGRDBDemo/Documentation/Demo1.png" width="50%">

This demo application uses [Action], [RxDataSources], [RxGRDB], and [RxSwift] to synchronize its view with the content of the database.

To play with it:

1. Download the RxGRDB repository
2. Run `pod install`
3. Open `RxGRDB.xcworkspace` at the root of the repository
4. Run the RxGRDBDemo application.

The rows of the players table view animate as you change the players ordering, delete all players, or refresh them (refreshing applies random transformations to the database)

## Models

- [AppDatabase.swift](RxGRDBDemo/AppDatabase.swift)
    
    AppDatabase defines the database for the whole application. It uses [DatabaseMigrator](https://github.com/groue/GRDB.swift/blob/master/README.md#migrations) in order to setup the database schema.

- [Player.swift](RxGRDBDemo/Models/Player.swift)
    
    Player is a [Record](https://github.com/groue/GRDB.swift/blob/master/README.md#records) type, able to read and write in the database. It conforms to the standard Codable protocol in order to gain all advantages of [Codable Records](https://github.com/groue/GRDB.swift/blob/master/README.md#codable-records).
    
    ```swift
    struct Player: Codable, Equatable {
        var id: Int64?
        var name: String
        var score: Int
    }
    ```

- [Players.swift](RxGRDBDemo/Models/Players.swift)
    
    Players defines read and write operations on the players database.


## User Interface

- [PlayersViewModel.swift](RxGRDBDemo/UI/PlayersViewModel.swift)
    
    PlayersViewModel defines the content displayed on screen, and a bunch of available actions of players.

- [PlayersViewController.swift](RxGRDBDemo/UI/PlayersViewController.swift)
    
    PlayersViewController feeds from PlayersViewModel and displays it on screen.


[Action]: https://github.com/RxSwiftCommunity/Action
[RxDataSources]: https://github.com/RxSwiftCommunity/RxDataSources
[RxGRDB]: http://github.com/RxSwiftCommunity/RxGRDB
[RxSwift]: https://github.com/ReactiveX/RxSwift
