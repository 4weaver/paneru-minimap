import Foundation

@main
struct LayoutTests {
  static func main() {
    let windows = [
      Win(
        frame: WinFrame(x: -500, y: 0, width: 400, height: 100),
        bundleID: "left",
        appName: "Left",
        focused: false,
        floating: false
      ),
      Win(
        frame: WinFrame(x: 100, y: 0, width: 400, height: 100),
        bundleID: "focused",
        appName: "Focused",
        focused: true,
        floating: false
      ),
      Win(
        frame: WinFrame(x: 100, y: 0, width: 200, height: 100),
        bundleID: "other",
        appName: "Other",
        focused: false,
        floating: false
      ),
      Win(
        frame: WinFrame(x: 1200, y: 0, width: 400, height: 100),
        bundleID: "right",
        appName: "Right",
        focused: false,
        floating: false
      ),
      Win(
        frame: WinFrame(x: 0, y: 0, width: 50, height: 50),
        bundleID: "float",
        appName: "Float",
        focused: false,
        floating: true
      ),
    ]
    let columns = stripColumns(windows)
    expect(columns.count == 3, "three columns")
    expect(columns.map(\.index) == [1, 2, 3], "indices 1, 2, 3")
    expect(columns[1].focused, "column 2 focused")
    expect(columns[1].width == 400, "column 2 width 400")
    expect(columns[1].appName == "Focused", "column 2 app name Focused")

    let display = DisplaySpan(minX: 0, width: 1000)
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
