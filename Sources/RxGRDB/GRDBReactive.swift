// Workaround https://github.com/ReactiveX/RxSwift/issues/2270
/// :nodoc:
public struct GRDBReactive<Base> {
    /// Base object to extend.
    let base: Base
    
    /// Creates extensions with base object.
    ///
    /// - parameter base: Base object.
    init(_ base: Base) {
        self.base = base
    }
}
