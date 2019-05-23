import UIKit
import GRDB
import RxSwift
import RxGRDB

class ViewController: UIViewController {
    
    @IBOutlet weak var maxScoreLabel: UILabel!
    let maxScore = Player.select(max(Column("score")), as: Int.self)
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        maxScore.rx
            .fetchOne(in: dbQueue)
            .subscribe(onNext: { [weak self] score in self?.maxScoreDidChange(score) })
            .disposed(by: disposeBag)
    }
    
    @IBAction func reset() {
        try! dbQueue.inDatabase { db in
            _ = try Player.deleteAll(db)
        }
    }
    
    @IBAction func addPlayer() {
        try! dbQueue.inDatabase { db in
            var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
            try player.insert(db)
        }
    }
    
    private func maxScoreDidChange(_ score: Int?) {
        if let score = score {
            maxScoreLabel.text = String(describing: score)
        } else {
            maxScoreLabel.text = "None"
        }
    }
}
