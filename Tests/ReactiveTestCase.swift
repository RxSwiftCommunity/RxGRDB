import XCTest
import RxSwift

class ReactiveTestCase: XCTestCase {
    var disposeBag: DisposeBag! = nil
    
    override func setUp() {
        disposeBag = DisposeBag()
    }
    
    override func tearDown() {
        disposeBag = nil
    }
}
