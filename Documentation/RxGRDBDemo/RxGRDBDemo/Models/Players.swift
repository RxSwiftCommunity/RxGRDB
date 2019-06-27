import GRDB
import RxGRDB
import RxSwift

/// Players is responsible for high-level operations on the players database.
struct Players {
    private let database: DatabaseWriter
    
    init(database: DatabaseWriter) {
        self.database = database
    }
    
    // MARK: - Modify Players
    
    /// Creates random players if needed, and returns whether the database
    /// was empty.
    @discardableResult
    func populateIfEmpty() throws -> Bool {
        return try database.write(_populateIfEmpty)
    }
    
    func deleteAll() -> Completable {
        return database.rx.write(updates: _deleteAll)
    }
    
    func deleteOne(_ player: Player) -> Completable {
        return database.rx.write(updates: { db in
            try self._deleteOne(db, player: player)
        })
    }
    
    func refresh() -> Completable {
        return database.rx.write(updates: _refresh)
    }
    
    func stressTest() -> Completable {
        return Completable.zip(repeatElement(refresh(), count: 50))
    }
    
    // MARK: - Access Players
    
    /// An observable that tracks changes in any request of players
    func observeAll(_ request: QueryInterfaceRequest<Player>) -> Observable<[Player]> {
        return request.rx.observeAll(in: database)
    }
    
    // MARK: - Implementation
    //
    // ⭐️ Good practice: when we want to update the database, we define methods
    // that accept a Database connection, because they can easily be composed.
    
    /// Creates random players if needed, and returns whether the database
    /// was empty.
    private func _populateIfEmpty(_ db: Database) throws -> Bool {
        if try Player.fetchCount(db) > 0 {
            return false
        }
        
        // Insert new random players
        for _ in 0..<8 {
            var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
            try player.insert(db)
        }
        return true
    }
    
    private func _deleteAll(_ db: Database) throws {
        try Player.deleteAll(db)
    }
    
    private func _deleteOne(_ db: Database, player: Player) throws {
        try player.delete(db)
    }
    
    private func _refresh(_ db: Database) throws {
        if try _populateIfEmpty(db) {
            return
        }
        
        // Insert a player
        if Bool.random() {
            var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
            try player.insert(db)
        }
        // Delete a random player
        if Bool.random() {
            try Player.order(sql: "RANDOM()").limit(1).deleteAll(db)
        }
        // Update some players
        for var player in try Player.fetchAll(db) where Bool.random() {
            try player.updateChanges(db) {
                $0.score = Player.randomScore()
            }
        }
    }
}
