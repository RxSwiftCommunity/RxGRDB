import Action
import RxSwift

extension CocoaAction {
    /// Creates a CocoaAction from a Completable factory
    convenience init(workFactory: @escaping () -> Completable) {
        self.init { workFactory().andThen(.just(())) }
    }
}
