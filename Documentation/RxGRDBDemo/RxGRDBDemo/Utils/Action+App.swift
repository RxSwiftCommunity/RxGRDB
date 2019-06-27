import Action
import RxSwift

extension CocoaAction {
    /// Support for CocoaAction: creates an Action from a Completable factory.
    convenience init(
        enabledIf: Observable<Bool> = Observable.just(true),
        workFactory: @escaping (Input) -> Completable)
    {
        self.init(enabledIf: enabledIf) { input -> Observable<Void> in
            workFactory(input).andThen(.just(()))
        }
    }
}
