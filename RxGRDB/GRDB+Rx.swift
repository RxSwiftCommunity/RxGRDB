#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

// DatabaseReader & DatabaseWriter
extension DatabasePool : ReactiveCompatible { }
extension DatabaseQueue : ReactiveCompatible { }
extension AnyDatabaseReader : ReactiveCompatible { }
extension AnyDatabaseWriter : ReactiveCompatible { }

// FetchRequest
extension AdaptedFetchRequest : ReactiveCompatible { }
extension AnyFetchRequest : ReactiveCompatible { }
extension QueryInterfaceRequest : ReactiveCompatible { }
extension SQLRequest : ReactiveCompatible { }

// ValueObservation
extension ValueObservation : ReactiveCompatible { }
