import UIKit
import RxSwift
import RxGRDB
import GRDB
import Differ

private let playersByScore = Player.order(Player.Columns.score.desc)
private let playersByName = Player.order(Player.Columns.name)

class PlayersViewController: UITableViewController {
    private let disposeBag = DisposeBag()
    
    // A variable of player requests, that the user changes in order to sort
    // players by score or name.
    private var playerRequest: Variable<QueryInterfaceRequest<Player>> = Variable(playersByScore)
    
    // A variable of player arrays, which feeds the table view. Its content
    // depends on playerRequest.
    private var players: Variable<[Player]> = Variable([])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupToolbar()
        setupTableView()
    }
}

extension PlayersViewController {
    
    // MARK: - Toolbar
    
    private func setupToolbar() {
        toolbarItems = [
            UIBarButtonItem(title: "Name ⬆︎", style: .plain, target: self, action: #selector(sortByName)),
            UIBarButtonItem(title: "Score ⬇︎", style: .plain, target: self, action: #selector(sortByScore)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deletePlayers)),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh)),
            UIBarButtonItem(title: "💣", style: .plain, target: self, action: #selector(stressTest)),
        ]
    }
    
    @IBAction func sortByName() {
        playerRequest.value = playersByName
    }
    
    @IBAction func sortByScore() {
        playerRequest.value = playersByScore
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
        // We'll compute diffs in a background thread
        let diffQueue = DispatchQueue(label: "diff")
        
        // Start tracking player requests
        playerRequest.asObservable()
            
            // Observe database changes
            .flatMapLatest { request -> Observable<[Row]> in
                // Turn player requests into row requests so that we can compute
                // diffs based on Row's implementation of Equatable protocol.
                let rowRequest = request.asRequest(of: Row.self)
                
                // Emits a new row array each time the database changes
                return rowRequest.rx.fetchAll(in: dbPool, resultQueue: diffQueue)
            }
            
            // Compute diff
            .extendedDiff()
            
            // Apply diff to the table view
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (playerRows, diff) in
                guard let strongSelf = self else { return }
                strongSelf.players.value = playerRows.map { Player(row: $0) }
                if let diff = diff {
                    strongSelf.tableView.apply(
                        diff,
                        deletionAnimation: .fade,
                        insertionAnimation: .fade)
                } else {
                    strongSelf.tableView.reloadData()
                }
            })
            .disposed(by: disposeBag)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return players.value.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Player", for: indexPath)
        configure(cell, at: indexPath)
        return cell
    }
    
    private func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let player = players.value[indexPath.row]
        cell.textLabel?.text = player.name
        cell.detailTextLabel?.text = "\(player.score)"
    }
}

