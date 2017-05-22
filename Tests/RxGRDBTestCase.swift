import XCTest
import RxSwift

class RxGRDBTestCase: XCTestCase {
    var disposeBag: DisposeBag! = nil
    
    override func setUp() {
        disposeBag = DisposeBag()
    }
    
    override func tearDown() {
        disposeBag = nil
    }
}
