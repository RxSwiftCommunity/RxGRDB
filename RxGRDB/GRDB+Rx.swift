#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

// TypedRequest
extension AdaptedFetchRequest : ReactiveCompatible { }
extension AnyFetchRequest : ReactiveCompatible { }
extension QueryInterfaceRequest : ReactiveCompatible { }
extension SQLRequest : ReactiveCompatible { }

// DatabaseWriter
extension DatabasePool : ReactiveCompatible { }
extension DatabaseQueue : ReactiveCompatible { }
extension AnyDatabaseWriter : ReactiveCompatible { }
