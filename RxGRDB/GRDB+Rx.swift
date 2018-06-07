#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

// TypedRequest
extension AdaptedFetchRequest : ReactiveCompatible, DatabaseRegionConvertible { }
extension AnyFetchRequest : ReactiveCompatible, DatabaseRegionConvertible { }
extension QueryInterfaceRequest : ReactiveCompatible, DatabaseRegionConvertible { }
extension SQLRequest : ReactiveCompatible, DatabaseRegionConvertible { }

// DatabaseWriter
extension DatabasePool : ReactiveCompatible { }
extension DatabaseQueue : ReactiveCompatible { }
extension AnyDatabaseWriter : ReactiveCompatible { }
