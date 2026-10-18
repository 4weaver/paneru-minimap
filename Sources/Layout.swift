import Foundation

struct WinFrame: Equatable {
  var x, y, width, height: Int
}

struct Win: Equatable {
  var frame: WinFrame
  var bundleID: String
  var appName: String
  var focused: Bool
  var floating: Bool
}

struct StripColumn: Equatable {
  var index: Int
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
  let tiled = windows.filter { !$0.floating }
  let grouped = Dictionary(grouping: tiled, by: { $0.frame.x })
  return grouped.keys.sorted().enumerated().map { offset, x in
    let members = grouped[x] ?? []
    let chosen = members.first(where: { $0.focused })
      ?? members.sorted(by: { $0.appName < $1.appName }).first
    return StripColumn(
      index: offset + 1,
      x: x,
      width: members.map(\.frame.width).max() ?? 0,
      bundleID: chosen?.bundleID ?? "",
      appName: chosen?.appName ?? "",
      focused: members.contains(where: { $0.focused })
    )
  }
}

func barScale(total: Double, displayWidth: Double, barWidth: Double, displayFraction: Double) -> Double {
  guard barWidth > 0, total > 0 else { return 0 }
  let fit = barWidth / total
  guard displayWidth > 0, displayFraction > 0 else { return fit }
  return min(fit, barWidth * displayFraction / displayWidth)
}
