import UIKit
import RxDataSources
import RxSwift

/// An MVVM ViewController that displays PlayersViewModel
class PlayersViewController: UIViewController {
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var emptyView: UIView!
    private let viewModel = PlayersViewModel()
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationItem()
        setupToolbar()
        setupTableView()
        setupEmptyView()
    }
    
    private func setupNavigationItem() {
        viewModel
            .orderingButtonTitle
            .subscribe(onNext: updateRightBarButtonItem)
            .disposed(by: disposeBag)
    }
    
    private func updateRightBarButtonItem(title: String?) {
        guard let title = title else {
            navigationItem.rightBarButtonItem = nil
            return
        }
        
        let barButtonItem = UIBarButtonItem(title: title, style: .plain, target: nil, action: nil)
        barButtonItem.rx.action = viewModel.toggleOrdering
        navigationItem.rightBarButtonItem = barButtonItem
    }
    
    private func setupToolbar() {
        let deleteAllButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: nil, action: nil)
        deleteAllButtonItem.rx.action = viewModel.deleteAll
        
        let refreshButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: nil, action: nil)
        refreshButtonItem.rx.action = viewModel.refresh
        
        let stressTestButtonItem = UIBarButtonItem(title: "💣", style: .plain, target: nil, action: nil)
        stressTestButtonItem.rx.action = viewModel.stressTest
        
        toolbarItems = [
            deleteAllButtonItem,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            refreshButtonItem,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            stressTestButtonItem,
        ]
    }
    
    private func setupTableView() {
        let dataSource = RxTableViewSectionedAnimatedDataSource<Section>(configureCell: { (dataSource, tableView, indexPath, _) in
            let section = dataSource.sectionModels[indexPath.section]
            let player = section.items[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "Player", for: indexPath)
            cell.textLabel?.text = player.name
            cell.detailTextLabel?.text = "\(player.score)"
            return cell
        })
        
        dataSource.animationConfiguration = AnimationConfiguration(
            insertAnimation: .fade,
            reloadAnimation: .fade,
            deleteAnimation: .fade)
        
        dataSource.canEditRowAtIndexPath = { _, _ in true }
        
        viewModel
            .players
            .asDriver(onErrorJustReturn: [])
            .map { [Section(items: $0)] }
            .drive(tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
        
        tableView.rx
            .itemDeleted
            .subscribe(onNext: { indexPath in
                let player = dataSource[indexPath]
                self.viewModel.deleteOne.execute(player)
            })
            .disposed(by: disposeBag)
    }
    
    private func setupEmptyView() {
        viewModel
            .players
            .map { !$0.isEmpty }
            .asDriver(onErrorJustReturn: false)
            .drive(emptyView.rx.isHidden)
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
