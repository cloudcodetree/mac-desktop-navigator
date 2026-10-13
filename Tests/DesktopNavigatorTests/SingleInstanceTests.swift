import XCTest
@testable import DesktopNavigator

final class SingleInstanceTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000)
    private let t1 = Date(timeIntervalSince1970: 2_000)

    private func instance(pid: pid_t, launchedAt date: Date?) -> SingleInstance.Instance {
        SingleInstance.Instance(pid: pid, launchDate: date)
    }

    func testOlderInstanceIsTerminated() {
        let me = instance(pid: 200, launchedAt: t1)
        let older = instance(pid: 100, launchedAt: t0)
        XCTAssertEqual(SingleInstance.instancesToTerminate(me: me, others: [older]), [older])
    }

    func testNewerInstanceIsLeftAlone() {
        let me = instance(pid: 100, launchedAt: t0)
        let newer = instance(pid: 200, launchedAt: t1)
        XCTAssertEqual(SingleInstance.instancesToTerminate(me: me, others: [newer]), [])
    }

    func testSameLaunchDateLowerPidLoses() {
        let low = instance(pid: 100, launchedAt: t0)
        let high = instance(pid: 200, launchedAt: t0)
        XCTAssertEqual(SingleInstance.instancesToTerminate(me: high, others: [low]), [low])
        XCTAssertEqual(SingleInstance.instancesToTerminate(me: low, others: [high]), [])
    }

    func testUnknownLaunchDateCountsAsOldest() {
        let me = instance(pid: 200, launchedAt: t0)
        let unknown = instance(pid: 300, launchedAt: nil)
        XCTAssertEqual(SingleInstance.instancesToTerminate(me: me, others: [unknown]), [unknown])
    }

    func testNoOtherInstancesTerminatesNothing() {
        let me = instance(pid: 200, launchedAt: t0)
        XCTAssertEqual(SingleInstance.instancesToTerminate(me: me, others: []), [])
    }
}

final class SingleInstanceStartDateTests: XCTestCase {
    func testOwnProcessHasAStartDateInThePast() throws {
        let start = try XCTUnwrap(SingleInstance.startDate(pid: getpid()))
        XCTAssertLessThanOrEqual(start, Date())
        XCTAssertGreaterThan(start, Date().addingTimeInterval(-3600), "test process should have started within the hour")
    }

    func testNonexistentProcessHasNoStartDate() {
        XCTAssertNil(SingleInstance.startDate(pid: 2_000_000_000))
    }
}
