import XCTest
@testable import Sentinel

class CheckInViewModelTests: XCTestCase {
    
    var viewModel: CheckInViewModel!
    
    @MainActor
    override func setUp() {
        super.setUp()
        viewModel = CheckInViewModel()
        // Mock data logic is handled internally or via injections if needed
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    @MainActor
    func testInitialState() {
        XCTAssertEqual(viewModel.currentStep, .multimodal)
        XCTAssertEqual(viewModel.currentQuestionIndex, 0)
        XCTAssertNil(viewModel.checkInRecord)
    }
    
    @MainActor
    func testSkipMultimodal() {
        viewModel.skipMultimodal()
        
        XCTAssertNotNil(viewModel.checkInRecord)
        // CheckInStep enum equality might need Equatable conformance or manual checking
        if case .cssrs(let index) = viewModel.currentStep {
            XCTAssertEqual(index, 0)
        } else {
            XCTFail("Step should be cssrs(0)")
        }
    }

    @MainActor
    func testCSSRSFlow_NoRisk() {
        // Start flow (skip multimodal for speed)
        viewModel.skipMultimodal()
        
        // Q1: Wish to be dead? -> No
        viewModel.answerCurrentQuestion(false)
        XCTAssertEqual(viewModel.currentQuestionIndex, 1) // Go to Q2
        
        // Q2: Suicidal Thoughts? -> No
        viewModel.answerCurrentQuestion(false)
        XCTAssertEqual(viewModel.currentQuestionIndex, 5) // Skip to Q6
        
        // Q6: Recent Attempt? -> No
        viewModel.answerCurrentQuestion(false)
        
        // Should be complete or submitting
        // check completion logic (async submit might need handling)
    }
    
    @MainActor
    func testCSSRSFlow_HighRisk() {
        viewModel.skipMultimodal()
        
        // Q1: Yes
        viewModel.answerCurrentQuestion(true)
        XCTAssertEqual(viewModel.currentQuestionIndex, 1) // Next
        
        // Q2: Yes (triggers Q3,4,5)
        viewModel.answerCurrentQuestion(true)
        XCTAssertEqual(viewModel.currentQuestionIndex, 2)
        
        // Q3: Method? -> Yes
        viewModel.answerCurrentQuestion(true)
        XCTAssertEqual(viewModel.currentQuestionIndex, 3)
        
        // Q4: Intent? -> Yes (Crisis Trigger)
        viewModel.answerCurrentQuestion(true)
        
        // Should trigger immediate crisis completion logic
        XCTAssertEqual(viewModel.resultRiskTier, .crisis)
        XCTAssertEqual(viewModel.currentStep, .complete)
    }
}
