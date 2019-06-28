import GRDB

// A player
struct Player: Codable, Equatable {
    var id: Int64?
    var name: String
    var score: Int
}

// Adopt FetchableRecord so that we can fetch players from the database.
// Implementation is automatically derived from Codable.
extension Player: FetchableRecord { }

// Adopt MutablePersistable so that we can create/update/delete players in the
// database. Implementation is partially derived from Codable.
extension Player: MutablePersistableRecord {
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

// Define columns that we can use for our database requests.
// They are derived from the CodingKeys enum for extra safety.
extension Player {
    fileprivate enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }
}

// Define requests of players in a constrained extension to the
// DerivableRequest protocol.
extension DerivableRequest where RowDecoder == Player {
    func orderByScore() -> Self {
        return order(Player.Columns.score.desc, Player.Columns.name)
    }
    
    func orderByName() -> Self {
        return order(Player.Columns.name, Player.Columns.score.desc)
    }
}

// Player randomization
extension Player {
    private static let names = [
        "Arthur", "Anita", "Barbara", "Bernard", "Clément", "Chiara", "David",
        "Dean", "Éric", "Elena", "Fatima", "Frederik", "Gilbert", "Georgette",
        "Henriette", "Hassan", "Ignacio", "Irene", "Julie", "Jack", "Karl",
        "Kristel", "Louis", "Liz", "Masashi", "Mary", "Noam", "Nolwenn",
        "Ophelie", "Oleg", "Pascal", "Patricia", "Quentin", "Quinn", "Raoul",
        "Rachel", "Stephan", "Susie", "Tristan", "Tatiana", "Ursule", "Urbain",
        "Victor", "Violette", "Wilfried", "Wilhelmina", "Yvon", "Yann",
        "Zazie", "Zoé"]
    
    static func randomName() -> String {
        return names.randomElement()!
    }
    
    static func randomScore() -> Int {
        return 10 * Int.random(in: 0...100)
    }
}
