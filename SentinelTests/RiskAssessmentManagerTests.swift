import XCTest
@testable import Sentinel

class RiskAssessmentManagerTests: XCTestCase {
    
    var manager: RiskAssessmentManager!
    
    override func setUp() {
        super.setUp()
        manager = RiskAssessmentManager()
    }
    
    func testEmptyHistory() async {
        let result = await manager.getCurrentRiskTier(checkIns: [])
        XCTAssertEqual(result, .low)
    }
    
    func testRiskExtractionFromString() async {
        let record = CheckInRecord(timestamp: Date())
        record.determinedRiskTier = "red"

        let result = await manager.getCurrentRiskTier(checkIns: [record])
        XCTAssertEqual(result, .crisis)
    }

    func testRiskExtractionFromIntString() async {
        let record = CheckInRecord(timestamp: Date())
        record.determinedRiskTier = "2" // Orange (highMonitoring) rawValue

        let result = await manager.getCurrentRiskTier(checkIns: [record])
        XCTAssertEqual(result, .highMonitoring)
    }

    func testMostRecentDominates() async {
        let oldRecord = CheckInRecord(timestamp: Date().addingTimeInterval(-86400))
        oldRecord.determinedRiskTier = "red"

        let newRecord = CheckInRecord(timestamp: Date())
        newRecord.determinedRiskTier = "green"

        let result = await manager.getCurrentRiskTier(checkIns: [oldRecord, newRecord])
        XCTAssertEqual(result, .low)
    }
}
