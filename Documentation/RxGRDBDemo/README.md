RxGRDBDemo
==========

This demo application uses [RxSwift], [RxGRDB], and [Differ](https://github.com/tonyarnold/Differ) to synchronize its view with the content of the database.

To play with it:

1. Download the RxGRDB repository
2. Run `pod install`
3. Open `RxGRDB.xcworkspace` at the root of the repository
4. Run the RxGRDBDemo application.

The rows of the players table view animate as you change the players ordering, delete all players, or refresh them (refreshing applies random transformations to the database)

The annotations of the map view move, appear, and disappear as you refresh the map view content.

In both screens, the bomb icon spawns 50 dispatch items that concurrently perform random database transformations.

| [PlayersViewController](RxGRDBDemo/PlayersViewController.swift) | [PlacesViewController](RxGRDBDemo/PlacesViewController.swift) |
| :-----: | :-----: |
| ![Screen shot 1](Documentation/Screen1.png) | ![Screen shot 2](Documentation/Screen2.png) |

[Differ]: https://github.com/tonyarnold/Differ
[RxGRDB]: http://github.com/RxSwiftCommunity/RxGRDB
[RxSwift]: https://github.com/ReactiveX/RxSwift
