import UIKit
import RxSwift
import RxGRDB
import GRDB
import Differ

class PlayersViewController: UITableViewController {
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
    private var ordering: Variable<Ordering> = Variable(.byScore)
    
    // The players that feed the table view.
    // They depend on the current ordering.
    private var players: [Player] = []
    
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
        ordering.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] ordering in
                guard let strongSelf = self else { return }
                
                let action: Selector
                switch ordering {
                case .byScore: action = #selector(strongSelf.sortByName)
                case .byName: action = #selector(strongSelf.sortByScore)
                }
                
                strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(title: ordering.localizedName, style: .plain, target: self, action: action)
                
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
        ordering.value = .byName
    }
    
    @IBAction func sortByScore() {
        ordering.value = .byScore
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
        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            self.refresh()
        }
    }
}

extension PlayersViewController {
    
    // MARK: - Table View
    
    private func setupTableView() {
        let diffScanner = ExtendedDiffScanner(rows: [], extendedDiff: nil)
        
        // Track player ordering
        ordering.asObservable()
            
            // Each ordering has a database request: observe its changes
            .flatMapLatest { ordering -> Observable<[Row]> in
                // Turn player requests into row requests so that we can compute
                // diffs based on Row's implementation of Equatable protocol.
                let rowRequest = ordering.request.asRequest(of: Row.self)
                
                // Emits a new row array each time the database changes
                return rowRequest.rx.fetchAll(in: dbPool)
            }
            
            // Compute diff between fetched rows
            .scan(diffScanner) { (diffScanner, rows) in diffScanner.diffed(from: rows) }
            
            // Apply diff to the table view
            .subscribe(onNext: { [weak self] scanner in
                guard let strongSelf = self else { return }
                strongSelf.players = scanner.rows.map { Player(row: $0) }
                strongSelf.tableView.apply(
                    scanner.extendedDiff!,
                    deletionAnimation: .fade,
                    insertionAnimation: .fade)
            })
            .disposed(by: disposeBag)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return players.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Player", for: indexPath)
        configure(cell, at: indexPath)
        return cell
    }
    
    private func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let player = players[indexPath.row]
        cell.textLabel?.text = player.name
        cell.detailTextLabel?.text = "\(player.score)"
    }
}

struct ExtendedDiffScanner {
    var rows: [Row]
    var extendedDiff: ExtendedDiff?
    
    func diffed(from newRows: [Row]) -> ExtendedDiffScanner {
        return ExtendedDiffScanner(
            rows: newRows,
            extendedDiff: rows.extendedDiff(newRows))
    }
}

