import RxSwift

enum Result<Value> {
    case success(Value)
    case failure(Error)
    
    public init(value: () throws -> Value) {
        do {
            self = try .success(value())
        } catch {
            self = .failure(error)
        }
    }
    
    func map<T>(_ transform: (Value) -> T) -> Result<T> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
}

extension ObserverType {
    func onResult(_ result: Result<E>) {
        switch result {
        case .success(let element):
            onNext(element)
        case .failure(let error):
            onError(error)
        }
    }
}
