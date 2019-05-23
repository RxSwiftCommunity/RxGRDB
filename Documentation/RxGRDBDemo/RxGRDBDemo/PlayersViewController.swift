import UIKit
import GRDB
import RxDataSources
import RxGRDB
import RxCocoa
import RxSwift

class PlayersViewController: UIViewController {
    @IBOutlet private weak var tableView: UITableView!
    private let disposeBag = DisposeBag()
    
    // An enum that describes a players ordering
    enum Ordering: Equatable {
        case byScore
        case byName
        
        var request: QueryInterfaceRequest<Player> {
            switch self {
            case .byScore: return Player.order(Player.Columns.score.desc)
            case .byName: return Player.order(Player.Columns.name)
            }
        }
        
        var localizedName: String {
            switch self {
            case .byScore: return "Score ⬇︎"
            case .byName: return "Name ⬆︎"
            }
        }
    }
    
    // The user can change the players ordering
    private var ordering = BehaviorRelay<Ordering>(value: .byScore)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationItem()
        setupToolbar()
        setupTableView()
    }
}

extension PlayersViewController {
    
    // MARK: - Actions
    
    private func setupNavigationItem() {
        // Navigation item depends on the ordering
        ordering
            .subscribe(onNext: { [weak self] ordering in
                guard let self = self else { return }
                
                let action: Selector
                switch ordering {
                case .byScore: action = #selector(self.sortByName)
                case .byName: action = #selector(self.sortByScore)
                }
                
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(
                    title: ordering.localizedName,
                    style: .plain,
                    target: self,
                    action: action)
            })
            .disposed(by: disposeBag)
    }
    
    private func setupToolbar() {
        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deletePlayers)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "💣", style: .plain, target: self, action: #selector(stressTest)),
        ]
    }
    
    @IBAction func sortByName() {
        ordering.accept(.byName)
    }
    
    @IBAction func sortByScore() {
        ordering.accept(.byScore)
    }
    
    @IBAction func deletePlayers() {
        try! dbPool.writeInTransaction { db in
            try Player.deleteAll(db)
            return .commit
        }
    }
    
    @IBAction func refresh() {
        try! dbPool.writeInTransaction { db in
            if try Player.fetchCount(db) == 0 {
                // Insert players
                for _ in 0..<8 {
                    var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                    try player.insert(db)
                }
            } else {
                // Insert a player
                if arc4random_uniform(2) == 0 {
                    var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                    try player.insert(db)
                }
                // Delete a random player
                if arc4random_uniform(2) == 0 {
                    try Player.order(sql: "RANDOM()").limit(1).deleteAll(db)
                }
                // Update some players
                for player in try Player.fetchAll(db) where arc4random_uniform(2) == 0 {
                    var player = player
                    player.score = Player.randomScore()
                    try player.update(db)
                }
            }
            return .commit
        }
    }
    
    @IBAction func stressTest() {
        for _ in 0..<50 {
            DispatchQueue.global().async {
                self.refresh()
            }
        }
    }
}

extension PlayersViewController {
    
    // MARK: - Table View
    
    private func setupTableView() {
        let dataSource = RxTableViewSectionedAnimatedDataSource<Section>(
            animationConfiguration: AnimationConfiguration(
                insertAnimation: .fade,
                reloadAnimation: .fade,
                deleteAnimation: .fade),
            configureCell: { (dataSource, tableView, indexPath, _) -> UITableViewCell in
                let section = dataSource.sectionModels[indexPath.section]
                let player = section.items[indexPath.row]
                let cell = tableView.dequeueReusableCell(withIdentifier: "Player", for: indexPath)
                cell.textLabel?.text = player.name
                cell.detailTextLabel?.text = "\(player.score)"
                return cell
        })
        
        ordering
            .distinctUntilChanged()
            .flatMapLatest { $0.request.rx.fetchAll(in: dbPool) }
            .map { [Section(items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
    }
}

private struct Section {
    var items: [Player]
}

extension Section: AnimatableSectionModelType {
    var identity: Int { return 1 }
    init(original: Section, items: [Player]) {
        self.items = items
    }
}

extension Player: IdentifiableType {
    var identity: Int64 { return id! }
}
