import UIKit
import RxDataSources
import RxSwift

/// An MVVM ViewController that displays PlayersViewModel
class PlayersViewController: UIViewController {
    @IBOutlet private weak var tableView: UITableView!
    private let viewModel = PlayersViewModel()
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationItem()
        setupToolbar()
        setupTableView()
    }
    
    private func setupNavigationItem() {
        // Navigation item invokes viewModel actions
        
        viewModel
            .orderingButtonTitle
            .subscribe(onNext: { [weak self] orderingButtonTitle in
                guard let self = self else { return }
                var barButtonItem = UIBarButtonItem(title: orderingButtonTitle, style: .plain, target: nil, action: nil)
                barButtonItem.rx.action = self.viewModel.toggleOrdering
                self.navigationItem.rightBarButtonItem = barButtonItem
            })
            .disposed(by: disposeBag)
    }
    
    private func setupToolbar() {
        // Toolbar invokes viewModel actions
        
        var deleteAllButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: nil, action: nil)
        deleteAllButtonItem.rx.action = viewModel.deleteAll
        
        var refreshButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: nil, action: nil)
        refreshButtonItem.rx.action = viewModel.refresh
        
        var stressTestButtonItem = UIBarButtonItem(title: "💣", style: .plain, target: nil, action: nil)
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
        // TableView content depends on the viewModel
        
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
        
        viewModel
            .players
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
