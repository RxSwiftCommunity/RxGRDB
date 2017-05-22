import UIKit
import GRDB
import RxSwift
import RxGRDB

class ViewController: UIViewController {
    
    @IBOutlet weak var maxScoreLabel: UILabel!
//    let maxScore = SQLRequest("SELECT max(score) FROM persons").bound(to: Int.self)
    let maxScore = Person.select(max(Column("score"))).asRequest(of: Int.self)
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        maxScore.rx
            .fetchOne(in: dbQueue)
            .subscribe(onNext: { [weak self] score in self?.maxScoreDidChange(score) })
            .addDisposableTo(disposeBag)
    }
    
    @IBAction func reset() {
        try! dbQueue.inDatabase { db in
            _ = try Person.deleteAll(db)
        }
    }
    
    @IBAction func addPerson() {
        try! dbQueue.inDatabase { db in
            try Person(name: Person.randomName(), score: Person.randomScore()).insert(db)
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
