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
            .flatMapLatest { ordering -> Observable<[Player]> in
                switch ordering {
                case .byScore:
                    return Current.players().playersOrderedByScore()
                case .byName:
                    return Current.players().playersOrderedByName()
                }
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
            Current.players().deleteOne(player).asCompletable()
        }
        
        refresh = CocoaAction {
            Current.players().refresh()
        }
        
        stressTest = CocoaAction {
            Current.players().stressTest()
        }
        
        toggleOrdering = CocoaAction {
            switch ordering.value {
            case .byName:
                ordering.accept(.byScore)
            case .byScore:
                ordering.accept(.byName)
            }
            return Observable.just(())
        }
    }
}
