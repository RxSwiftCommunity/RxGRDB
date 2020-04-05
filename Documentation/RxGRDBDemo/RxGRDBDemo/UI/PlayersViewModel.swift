import Action
import Foundation
import GRDB
import RxCocoa
import RxGRDB
import RxSwift

/// An MVVM ViewModel for PlayersViewController
class PlayersViewModel {
    // MARK: - Values Displayed on Screen
    
    var orderingButtonTitle: Observable<String?>
    var players: Observable<[Player]>
    
    // MARK: - Actions
    
    var toggleOrdering: CocoaAction
    var deleteAll: CocoaAction
    var deleteOne: CompletableAction<Player>
    var refresh: CocoaAction
    var stressTest: CocoaAction
    
    // MARK: - Implementation
    
    private enum Ordering: Equatable {
        case byScore
        case byName
    }
    private var ordering = BehaviorRelay<Ordering>(value: .byScore)
    
    init() {
        // The root of everything
        let ordering = BehaviorRelay<Ordering>(value: .byScore)
        
        // Values Displayed on Screen
        players = ordering
            .distinctUntilChanged()
            .map { ordering -> Request<Player> in
                switch ordering {
                case .byScore:
                    return Player.all().orderByScore()
                case .byName:
                    return Player.all().orderByName()
                }
            }
            .flatMapLatest { request -> Observable<[Player]> in
                Current.players().observeAll(request)
            }
            .share(replay: 1)
        
        orderingButtonTitle = Observable
            .combineLatest(players, ordering)
            .map { players, ordering -> String? in
                if players.isEmpty {
                    return nil
                }
                switch ordering {
                case .byScore:
                    return NSLocalizedString("Score ⬇︎", comment: "")
                case .byName:
                    return NSLocalizedString("Name ⬆︎", comment: "")
                }
        }
        
        // Actions
        deleteAll = CocoaAction {
            Current.players().deleteAll()
        }
        
        deleteOne = CompletableAction { player in
            Current.players().deleteOne(player)
        }
        
        refresh = CocoaAction {
            Current.players().refresh()
        }
        
        stressTest = CocoaAction {
            Current.players().stressTest()
        }
        
        toggleOrdering = CocoaAction { _ -> Completable in
            switch ordering.value {
            case .byName:
                ordering.accept(.byScore)
            case .byScore:
                ordering.accept(.byName)
            }
            return .empty()
        }
    }
}
