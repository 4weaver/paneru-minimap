import Foundation

struct WinFrame: Equatable {
  var x, y, width, height: Int
}

struct Win: Equatable {
  var frame: WinFrame
  var windowID: Int
  var bundleID: String
  var appName: String
  var focused: Bool
  var floating: Bool
}

struct StripColumn: Equatable {
  var index: Int
  var windowID: Int
  var x: Int
  var width: Int
  var bundleID: String
  var appName: String
  var focused: Bool
}

struct DisplaySpan: Equatable {
  var minX: Double
  var width: Double
}

func stripColumns(_ windows: [Win]) -> [StripColumn] {
  windows.filter { !$0.floating }.enumerated().map { offset, window in
    StripColumn(
      index: offset + 1,
      windowID: window.windowID,
      x: window.frame.x,
      width: window.frame.width,
      bundleID: window.bundleID,
      appName: window.appName,
      focused: window.focused
    )
  }
}

func onDisplay(_ column: StripColumn, display: DisplaySpan) -> Bool {
  Double(column.x) < display.minX + display.width && Double(column.x + column.width) > display.minX
}

func barScale(total: Double, displayWidth: Double, barWidth: Double, displayFraction: Double) -> Double {
  guard barWidth > 0, total > 0 else { return 0 }
  let fit = barWidth / total
  guard displayWidth > 0, displayFraction > 0 else { return fit }
  return min(fit, barWidth * displayFraction / displayWidth)
}
