import XCTest
@testable import Shirox

/// A few pull-to-refreshes a minute, counted across the app.
@MainActor
final class RefreshLimiterTests: XCTestCase {
    private var messages: [String] = []

    private func limiter(limit: Int = 3) -> RefreshLimiter {
        RefreshLimiter(limit: limit, window: 60) { [weak self] in self?.messages.append($0) }
    }

    func testThreeAMinuteThenRefused() {
        let limiter = limiter()
        let start = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(limiter.attempt(now: start), .allowed)
        XCTAssertEqual(limiter.attempt(now: start.addingTimeInterval(5)), .allowed)
        XCTAssertEqual(limiter.attempt(now: start.addingTimeInterval(10)), .allowed)
        XCTAssertEqual(limiter.attempt(now: start.addingTimeInterval(18)), .limited(retryIn: 42),
                       "Free again when the first is a minute old")
    }

    func testRoomAgainOnceTheOldestIsAMinuteOld() {
        let limiter = limiter()
        let start = Date(timeIntervalSince1970: 1_000_000)
        for offset in [0.0, 5, 10] { _ = limiter.attempt(now: start.addingTimeInterval(offset)) }
        XCTAssertEqual(limiter.attempt(now: start.addingTimeInterval(60)), .allowed)
        XCTAssertEqual(limiter.attempt(now: start.addingTimeInterval(61)), .limited(retryIn: 4))
    }

    func testARefusedPullDoesNotCount() {
        let limiter = limiter(limit: 1)
        let start = Date(timeIntervalSince1970: 1_000_000)
        _ = limiter.attempt(now: start)
        for offset in [10.0, 20, 30] { _ = limiter.attempt(now: start.addingTimeInterval(offset)) }
        XCTAssertEqual(limiter.attempt(now: start.addingTimeInterval(60)), .allowed,
                       "Pulls while refused don't push the wait back")
    }

    func testARefusalSaysHowLongToWait() {
        let limiter = limiter(limit: 1)
        let start = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(limiter.allow(now: start))
        XCTAssertTrue(messages.isEmpty)
        XCTAssertFalse(limiter.allow(now: start.addingTimeInterval(18.6)))
        XCTAssertEqual(messages, ["Rate limited — try again in 42 s"])
    }

    func testTheWaitRoundsUpToAWholeSecond() {
        XCTAssertEqual(RefreshLimiter.message(retryIn: 41.2), "Rate limited — try again in 42 s")
        XCTAssertEqual(RefreshLimiter.message(retryIn: 0.2), "Rate limited — try again in 1 s")
    }

    func testALimitedActionOnlyRunsWhenAllowed() async {
        let limiter = limiter(limit: 1)
        let runs = Counter()
        let refresh = limiter.limiting { await runs.bump() }
        await refresh()
        await refresh()
        XCTAssertEqual(runs.value, 1)
        XCTAssertEqual(messages.count, 1)
    }
}

@MainActor
private final class Counter {
    private(set) var value = 0
    func bump() { value += 1 }
}
