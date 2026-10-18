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
    let map = barMap(columns: columns, display: display, barWidth: 210)
    expect(map.domainMinX == -500, "domainMinX")
    expect(map.domainWidth == 2100, "domainWidth")
    expect(near(map.viewportBarX, 50), "viewport bar x")
    expect(near(map.viewportBarWidth, 100), "viewport bar width")
    expect(hitColumn(20, map: map, columns: columns) == 1, "hit 20")
    expect(hitColumn(70, map: map, columns: columns) == 2, "hit 70")
    expect(hitColumn(-1, map: map, columns: columns) == nil, "hit -1")
    expect(hitColumn(10, map: map, columns: []) == nil, "empty columns")
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
