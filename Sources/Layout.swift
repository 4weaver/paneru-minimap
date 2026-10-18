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

struct BarMap: Equatable {
  var domainMinX: Double
  var domainWidth: Double
  var viewportBarX: Double
  var viewportBarWidth: Double
  var barWidth: Double
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

func barMap(columns: [StripColumn], display: DisplaySpan, barWidth: Double) -> BarMap {
  if barWidth <= 0 {
    return BarMap(
      domainMinX: 0,
      domainWidth: 0,
      viewportBarX: 0,
      viewportBarWidth: 0,
      barWidth: 0
    )
  }
  let domainMinX = min(display.minX, columns.map { Double($0.x) }.min() ?? display.minX)
  let columnMax = columns.map { Double($0.x + $0.width) }.max() ?? (display.minX + display.width)
  let domainMax = max(display.minX + display.width, columnMax)
  let domainWidth = max(domainMax - domainMinX, 1)
  let scale = barWidth / domainWidth
  return BarMap(
    domainMinX: domainMinX,
    domainWidth: domainWidth,
    viewportBarX: (display.minX - domainMinX) * scale,
    viewportBarWidth: display.width * scale,
    barWidth: barWidth
  )
}

func hitColumn(_ barX: Double, map: BarMap, columns: [StripColumn]) -> Int? {
  if columns.isEmpty {
    return nil
  }
  if barX < 0 || barX > map.barWidth {
    return nil
  }
  if map.barWidth <= 0 || map.domainWidth <= 0 {
    return nil
  }
  let globalX = map.domainMinX + barX / map.barWidth * map.domainWidth
  let containing = columns.filter {
    Double($0.x) <= globalX && globalX < Double($0.x + $0.width)
  }
  if let leftmost = containing.min(by: { $0.index < $1.index }) {
    return leftmost.index
  }
  return columns.min(by: { a, b in
    let da = abs(Double(a.x) + Double(a.width) / 2 - globalX)
    let db = abs(Double(b.x) + Double(b.width) / 2 - globalX)
    if da == db {
      return a.index < b.index
    }
    return da < db
  })?.index
}
