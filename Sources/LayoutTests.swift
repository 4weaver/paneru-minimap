import Foundation

@main
struct LayoutTests {
  static func main() {
    let windows = [
      Win(
        frame: WinFrame(x: -500, y: 0, width: 400, height: 100),
        windowID: 1,
        bundleID: "left",
        appName: "Left",
        focused: false,
        floating: false
      ),
      Win(
        frame: WinFrame(x: 100, y: 0, width: 400, height: 100),
        windowID: 2,
        bundleID: "focused",
        appName: "Focused",
        focused: true,
        floating: false
      ),
      Win(
        frame: WinFrame(x: 100, y: 0, width: 200, height: 100),
        windowID: 3,
        bundleID: "other",
        appName: "Other",
        focused: false,
        floating: false
      ),
      Win(
        frame: WinFrame(x: 1200, y: 0, width: 400, height: 100),
        windowID: 4,
        bundleID: "right",
        appName: "Right",
        focused: false,
        floating: false
      ),
      Win(
        frame: WinFrame(x: 0, y: 0, width: 50, height: 50),
        windowID: 5,
        bundleID: "float",
        appName: "Float",
        focused: false,
        floating: true
      ),
    ]
    let columns = stripColumns(windows)
    expect(columns.count == 4, "four columns")
    expect(columns.map(\.index) == [1, 2, 3, 4], "indices 1, 2, 3, 4")
    expect(columns.map(\.appName) == ["Left", "Focused", "Other", "Right"], "columns keep paneru order")
    expect(columns.map(\.windowID) == [1, 2, 3, 4], "one column per tiled window")
    expect(columns.map(\.focused) == [false, true, false, false], "focus stays on its own window")
    expect(columns[1].width == 400, "the focused window's own width")
    expect(columns[2].width == 200, "an equal position does not widen the other column")
    expect(Set(columns.map(\.windowID)) == Set([1, 2, 3, 4]), "prune keeps every tiled window")

    let display = DisplaySpan(minX: 0, width: 1000)
    expect(
      !onDisplay(
        StripColumn(
          index: 4,
          windowID: 4,
          x: 1200,
          width: 400,
          bundleID: "right",
          appName: "Right",
          focused: false
        ),
        display: display
      ),
      "off-display column is not on the display"
    )
    expect(
      onDisplay(
        StripColumn(
          index: 3,
          windowID: 3,
          x: 900,
          width: 400,
          bundleID: "right",
          appName: "Right",
          focused: false
        ),
        display: display
      ),
      "column straddling the right edge is on the display"
    )
    let shared = stripColumns([
      Win(
        frame: WinFrame(x: 500, y: 0, width: 120, height: 100),
        windowID: 10,
        bundleID: "zeta",
        appName: "Zeta",
        focused: true,
        floating: false
      ),
      Win(
        frame: WinFrame(x: 0, y: 0, width: 100, height: 100),
        windowID: 11,
        bundleID: "alpha",
        appName: "Alpha",
        focused: false,
        floating: false
      ),
      Win(
        frame: WinFrame(x: 0, y: 0, width: 90, height: 100),
        windowID: 12,
        bundleID: "beta",
        appName: "Beta",
        focused: false,
        floating: false
      ),
    ])
    expect(shared.count == 3, "a parked position does not swallow its windows")
    expect(shared.map(\.windowID) == [10, 11, 12], "paneru order wins over position order")
    expect(shared.map(\.focused) == [true, false, false], "focus stays on its own window")

    let scale = barScale(
      total: 3000,
      displayWidth: display.width,
      barWidth: 300,
      displayFraction: 0.3
    )
    expect(near(scale, 0.09), "display takes 30% of the bar")
    expect(near(1000 * scale, 90), "display span in the bar")

    let wide = barScale(total: 5000, displayWidth: 1000, barWidth: 300, displayFraction: 0.3)
    expect(near(wide, 0.06), "wide strip shrinks under the fraction")
    expect(near(5000 * wide, 300), "wide strip fits the bar")

    let narrow = barScale(total: 800, displayWidth: 1000, barWidth: 300, displayFraction: 0.3)
    expect(near(narrow, 0.09), "narrow strip keeps the fraction")

    expect(barScale(total: 0, displayWidth: 1000, barWidth: 300, displayFraction: 0.3) == 0, "no columns")
    expect(
      near(barScale(total: 1000, displayWidth: 0, barWidth: 300, displayFraction: 0.3), 0.3),
      "unknown display width falls back to fit"
    )
  }

  static func near(_ got: Double, _ want: Double) -> Bool {
    abs(got - want) < 0.001
  }

  static func expect(_ ok: Bool, _ name: String) {
    if !ok {
      fputs("FAIL \(name)\n", stderr)
      exit(1)
    }
  }
}
