import XCTest
@testable import Shirox

/// The blob's numbers: when the pull is whole, how far the circle hangs, when the spinner
/// lands. Ported with them from the reference project, and named in `MorphingRefreshGeometry`
/// so they can be checked the way the circle's are. The pull is deliberately long — the gooey
/// arrives slowly and stretches progressively — and the drawn progress is the pull smoothed.
final class MorphingRefreshTests: XCTestCase {
    private typealias Geometry = MorphingRefreshGeometry

    func testThePullIsAllOfItByAHundredAndTenPoints() {
        XCTAssertEqual(Geometry.progress(offsetWithInset: 0), 0)
        XCTAssertEqual(Geometry.progress(offsetWithInset: -30), 30.0 / 110.0, accuracy: 0.001)
        XCTAssertEqual(Geometry.progress(offsetWithInset: -110), 1)
        XCTAssertEqual(Geometry.progress(offsetWithInset: -220), 1, "Past the threshold it stays whole")
        XCTAssertEqual(Geometry.progress(offsetWithInset: 20), 0, "Scrolling down pulls nothing")
    }

    func testTheStretchIsSlowAtBothEndsAndHonestInTheMiddle() {
        XCTAssertEqual(Geometry.stretch(0), 0)
        XCTAssertEqual(Geometry.stretch(1), 1)
        XCTAssertEqual(Geometry.stretch(0.5), 0.5, accuracy: 0.001)
        // Slow to start: a fifth of the pull moves the gooey less than a tenth.
        XCTAssertLessThan(Geometry.stretch(0.2), 0.1)
        // And gathering pace through the middle: three fifths moves it more than the pull.
        XCTAssertGreaterThan(Geometry.stretch(0.8), 0.9)
        // Monotonic all the way.
        for step in stride(from: 0.0, to: 1.0, by: 0.05) {
            XCTAssertLessThanOrEqual(Geometry.stretch(CGFloat(step)), Geometry.stretch(CGFloat(step + 0.05)))
        }
    }

    func testTheCircleHangsFurtherAsThePullGrows() {
        let rest = Geometry.circleOffset(safeAreaTop: 62, progress: 0)
        let half = Geometry.circleOffset(safeAreaTop: 62, progress: 0.5)
        let full = Geometry.circleOffset(safeAreaTop: 62, progress: 1)
        XCTAssertEqual(rest, 0)
        XCTAssertLessThan(half, full)
        // On an island phone the blob hangs the height of the island's own inset.
        XCTAssertEqual(full, 62, accuracy: 0.01)
        // Without an island the blob starts higher up, so the circle drops further.
        XCTAssertGreaterThan(Geometry.circleOffset(safeAreaTop: 20, progress: 1), full)
    }

    func testTheCircleGrowsOverTheFirstFourFifths() {
        XCTAssertEqual(Geometry.circleSize(progress: 0), 30)
        XCTAssertEqual(Geometry.circleSize(progress: 0.2), 30, accuracy: 0.01)
        XCTAssertEqual(Geometry.circleSize(progress: 0.6), 35, accuracy: 0.01)
        XCTAssertEqual(Geometry.circleSize(progress: 1), 40, accuracy: 0.01)
    }

    func testTheSpinnerLandsOverTheLastFifth() {
        XCTAssertEqual(Geometry.spinnerOpacity(progress: 0.8), 0, accuracy: 0.001)
        XCTAssertEqual(Geometry.spinnerOpacity(progress: 0.9), 0.5, accuracy: 0.001)
        XCTAssertEqual(Geometry.spinnerOpacity(progress: 1), 1, accuracy: 0.001)
        XCTAssertEqual(Geometry.spinnerSize(progress: 0), 30)
        XCTAssertEqual(Geometry.spinnerSize(progress: 1), 40)
    }

    func testTheShapesSitCrispOnceThePullIsWhole() {
        XCTAssertEqual(Geometry.blurRadius(progress: 0), 25)
        XCTAssertEqual(Geometry.blurRadius(progress: 1), 0)
    }
}
