import XCTest
@testable import Sentinel

@MainActor
final class CrisisViewModelTests: XCTestCase {
    var viewModel: CrisisViewModel!

    override func setUp() {
        super.setUp()
        viewModel = CrisisViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testEnterCrisis() {
        viewModel.enterCrisis()
        XCTAssertEqual(viewModel.status, .active)
        XCTAssertFalse(viewModel.has988BeenCalled)
    }

    func testHandleRecheckStable() async {
        viewModel.enterCrisis()

        // Simulate recheck logic
        viewModel.handleRecheck(response: .stable)

        // Allow async task to complete (resolveCrisis is async)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        XCTAssertEqual(viewModel.status, .resolved)
    }

    func testHandleRecheckSame() {
        viewModel.enterCrisis()
        viewModel.showRecheckOptions = true

        viewModel.handleRecheck(response: .same)

        XCTAssertEqual(viewModel.status, .stabilizing)
        XCTAssertFalse(viewModel.showRecheckOptions)
        // Timer should restart, but we can't easily verify that without waiting 10 mins
    }

    func testHandleRecheckWorse() {
        viewModel.enterCrisis()

        viewModel.handleRecheck(response: .worse)

        XCTAssertTrue(viewModel.has988BeenCalled)
    }
}
