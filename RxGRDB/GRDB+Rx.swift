#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

// Request
extension AdaptedRequest : ReactiveCompatible { }
extension AnyRequest : ReactiveCompatible { }
extension SQLRequest : ReactiveCompatible { }

// TypedRequest
extension AdaptedTypedRequest : ReactiveCompatible { }
extension AnyTypedRequest : ReactiveCompatible { }
extension QueryInterfaceRequest : ReactiveCompatible { }

// DatabaseWriter
extension DatabasePool : ReactiveCompatible { }
extension DatabaseQueue : ReactiveCompatible { }
extension AnyDatabaseWriter : ReactiveCompatible { }
