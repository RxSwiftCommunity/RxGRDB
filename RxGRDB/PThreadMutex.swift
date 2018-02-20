final public class PThreadMutex {
    private var mutex = pthread_mutex_t()
    
    public init() {
        let result = pthread_mutex_init(&mutex, nil)
        precondition(result == 0, "Failed to create pthread mutex")
    }
    
    deinit {
        let result = pthread_mutex_destroy(&mutex)
        precondition(result == 0, "Failed to destroy mutex")
    }
    
    fileprivate func lock() {
        let result = pthread_mutex_lock(&mutex)
        precondition(result == 0, "Failed to lock mutex")
    }
    
    fileprivate func unlock() {
        let result = pthread_mutex_unlock(&mutex)
        precondition(result == 0, "Failed to unlock mutex")
    }
    
    public func lock<T>(block: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        let value = try block()
        return value
    }
}
