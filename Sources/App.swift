import AppKit
import CoreGraphics
import Foundation

private let palette: [(CGFloat, CGFloat, CGFloat)] = [
  (0.35, 0.55, 0.85),
  (0.45, 0.72, 0.48),
  (0.85, 0.55, 0.35),
  (0.72, 0.45, 0.75),
  (0.85, 0.75, 0.35),
  (0.45, 0.70, 0.72),
]

private let barHeight: CGFloat = 64

final class BarView: NSView {
  var columns: [StripColumn] = []
  var display = DisplaySpan(minX: 0, width: 1)
  var shots: [Int: CGImage] = [:]

  override var isFlipped: Bool { true }

  func slots() -> [(index: Int, rect: CGRect, onScreen: Bool)] {
    let total = columns.reduce(0) { $0 + $1.width }
    let scale = total > 0 ? bounds.width / CGFloat(total) : 0
    var x: CGFloat = 0
    return columns.map { column in
      let width = max(CGFloat(column.width) * scale, 1)
      let onScreen = Double(column.x) < display.minX + display.width
        && Double(column.x + column.width) > display.minX
      let slot = (
        index: column.index,
        rect: CGRect(x: x, y: 0, width: width, height: bounds.height),
        onScreen: onScreen
      )
      x += width
      return slot
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.white.withAlphaComponent(0.12).setFill()
    bounds.fill()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    let placed = slots()
    for slot in placed {
      let rect = slot.rect
      let focused = columns.first { $0.index == slot.index }?.focused == true
      if let shot = shots[slot.index], shot.width > 1, shot.height > 1 {
        drawMinimapBlocks(
          contentSlice(shot, slotAspect: rect.width / max(rect.height, 1)),
          in: rect,
          dimmed: !focused
        )
        if !focused {
          NSColor.black.withAlphaComponent(0.18).setFill()
          rect.fill()
        }
      } else if let column = columns.first(where: { $0.index == slot.index }) {
        let bucket = column.bundleID.utf8.reduce(0) { $0 + Int($1) } % palette.count
        let color = palette[bucket]
        NSColor(calibratedRed: color.0, green: color.1, blue: color.2, alpha: 1).setFill()
        rect.fill()
      }
    }
    if let frame = displayFrame(placed) {
      NSColor.white.setStroke()
      let span = NSBezierPath(rect: frame)
      span.lineWidth = 2
      span.stroke()
    }
  }

  func displayFrame(_ placed: [(index: Int, rect: CGRect, onScreen: Bool)]) -> CGRect? {
    let d0 = display.minX
    let d1 = display.minX + display.width
    var segments: [CGRect] = []
    for pair in zip(columns, placed) {
      let column = pair.0
      let slot = pair.1.rect
      let c0 = Double(column.x)
      let c1 = Double(column.x + column.width)
      let span = c1 - c0
      if span <= 0 { continue }
      let o0 = max(c0, d0)
      let o1 = min(c1, d1)
      if o1 - o0 < 40 { continue }
      let x0 = slot.minX + CGFloat((o0 - c0) / span) * slot.width
      let x1 = slot.minX + CGFloat((o1 - c0) / span) * slot.width
      let piece = CGRect(x: x0, y: 1, width: max(x1 - x0, 1), height: bounds.height - 2)
      if var last = segments.last, piece.minX <= last.maxX + 1 {
        last.size.width = max(last.maxX, piece.maxX) - last.minX
        segments[segments.count - 1] = last
      } else {
        segments.append(piece)
      }
    }
    return segments.max { $0.width < $1.width }
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    guard let index = slots().first(where: { $0.rect.contains(point) })?.index else { return }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["paneru", "send-cmd", "window", "focus", String(index)]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
  }
}

final class App: NSObject, NSApplicationDelegate {
  let panel = NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: 320, height: barHeight),
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
  )
  let bar = BarView()
  var subscribe: Process?
  var subscribeGen = 0
  var subscribeBuffer = Data()
  var subscribeRestartPending = false
  var queryRunning = false
  var queryDirty = false
  var captureGen = 0

  func applicationDidFinishLaunching(_ notification: Notification) {
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.hidesOnDeactivate = false
    panel.sharingType = .none
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.title = "paneru-preview"
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    panel.isMovable = false
    bar.autoresizingMask = [.width, .height]
    panel.contentView = bar
    place(on: NSScreen.main)
    panel.orderFrontRegardless()
    startSubscribe()
    requestQuery()
  }

  func place(on screen: NSScreen?) {
    guard let screen else { return }
    let frame = screen.frame
    let target = NSRect(x: frame.minX + 8, y: frame.minY + 8, width: frame.width - 16, height: barHeight)
    let current = panel.frame
    if abs(current.minX - target.minX) < 1, abs(current.minY - target.minY) < 1,
      abs(current.width - target.width) < 1
    {
      return
    }
    panel.setFrame(target, display: false)
  }

  func screen(for displayID: CGDirectDisplayID?) -> NSScreen? {
    if let displayID {
      let match = NSScreen.screens.first { screen in
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
          == displayID
      }
      if let match { return match }
    }
    return NSScreen.main
  }

  func startSubscribe() {
    subscribeGen += 1
    let gen = subscribeGen
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["paneru", "subscribe", "--json"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      DispatchQueue.main.async {
        guard let self, self.subscribeGen == gen else { return }
        if data.isEmpty {
          handle.readabilityHandler = nil
          self.scheduleSubscribeRestart()
          return
        }
        self.subscribeBuffer.append(data)
        self.drainLines()
      }
    }
    process.terminationHandler = { [weak self] _ in
      DispatchQueue.main.async {
        guard let self, self.subscribeGen == gen else { return }
        self.scheduleSubscribeRestart()
      }
    }
    do {
      try process.run()
      subscribe = process
    } catch {
      scheduleSubscribeRestart()
    }
  }

  func scheduleSubscribeRestart() {
    if subscribeRestartPending { return }
    subscribeRestartPending = true
    let gen = subscribeGen
    subscribe = nil
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      guard let self, self.subscribeGen == gen else { return }
      self.subscribeRestartPending = false
      self.startSubscribe()
    }
  }

  func drainLines() {
    while let newline = subscribeBuffer.firstIndex(of: 0x0A) {
      subscribeBuffer.removeSubrange(...newline)
      requestQuery()
    }
  }

  func requestQuery() {
    if queryRunning {
      queryDirty = true
      return
    }
    queryRunning = true
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["paneru", "query", "state", "--json"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    process.terminationHandler = { [weak self] proc in
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      DispatchQueue.main.async {
        guard let self else { return }
        if proc.terminationStatus == 0, let parsed = parseState(data) {
          self.apply(parsed)
        }
        self.queryRunning = false
        if self.queryDirty {
          self.queryDirty = false
          self.requestQuery()
        }
      }
    }
    do {
      try process.run()
    } catch {
      queryRunning = false
      if queryDirty {
        queryDirty = false
        requestQuery()
      }
    }
  }

  func apply(_ parsed: ParsedState) {
    captureGen += 1
    let gen = captureGen
    bar.columns = parsed.columns
    bar.display = parsed.display
    let live = Set(parsed.columns.map(\.index))
    bar.shots = bar.shots.filter { live.contains($0.key) }
    place(on: screen(for: parsed.displayID))
    bar.needsDisplay = true
    let requests = parsed.shots
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      let shots = captureShots(requests)
      DispatchQueue.main.async {
        guard let self, self.captureGen == gen else { return }
        var merged = self.bar.shots
        for (key, image) in shots {
          merged[key] = image
        }
        self.bar.shots = merged
        self.bar.needsDisplay = true
      }
    }
  }
}

struct ParsedState {
  var columns: [StripColumn]
  var display: DisplaySpan
  var displayID: CGDirectDisplayID?
  var windows: [Win]
  var shots: [ShotRequest]
}

struct ShotRequest {
  var id: CGWindowID
  var x: Int
  var focused: Bool
  var area: Int
}

func parseState(_ data: Data) -> ParsedState? {
  guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
  guard intValue(obj["version"]) == 1 else { return nil }
  guard let active = obj["active"] as? [String: Any] else { return nil }
  guard let native = intValue(active["native_workspace_id"]),
    let number = intValue(active["virtual_workspace_number"])
  else { return nil }
  let workspaces = obj["virtual_workspaces"] as? [[String: Any]] ?? []
  let match = workspaces.first {
    intValue($0["native_workspace_id"]) == native && intValue($0["number"]) == number
  }
  let rawWindows = match?["windows"] as? [[String: Any]] ?? []
  var windows: [Win] = []
  var shots: [ShotRequest] = []
  for raw in rawWindows {
    guard let frame = raw["frame"] as? [String: Any],
      let x = intValue(frame["x"]),
      let y = intValue(frame["y"]),
      let width = intValue(frame["width"]),
      let height = intValue(frame["height"])
    else { continue }
    let floating = raw["floating"] as? Bool ?? false
    let focused = raw["focused"] as? Bool ?? false
    windows.append(
      Win(
        frame: WinFrame(x: x, y: y, width: width, height: height),
        bundleID: raw["bundle_id"] as? String ?? "",
        appName: raw["app_name"] as? String ?? "",
        focused: focused,
        floating: floating
      )
    )
    if !floating, let id = intValue(raw["window_id"]), id >= 0 {
      shots.append(ShotRequest(id: CGWindowID(id), x: x, focused: focused, area: width * height))
    }
  }
  return ParsedState(
    columns: stripColumns(windows),
    display: displaySpan(active),
    displayID: displayID(active),
    windows: windows,
    shots: shots
  )
}

func displayID(_ active: [String: Any]) -> CGDirectDisplayID? {
  guard let id = intValue(active["display_id"]), id >= 0 else { return nil }
  return CGDirectDisplayID(id)
}

func displaySpan(_ active: [String: Any]) -> DisplaySpan {
  let bounds: CGRect
  if let id = displayID(active) {
    bounds = CGDisplayBounds(id)
  } else {
    bounds = CGDisplayBounds(CGMainDisplayID())
  }
  if bounds.width <= 0 {
    let main = CGDisplayBounds(CGMainDisplayID())
    return DisplaySpan(minX: main.origin.x, width: main.width)
  }
  return DisplaySpan(minX: bounds.origin.x, width: bounds.width)
}

func intValue(_ value: Any?) -> Int? {
  switch value {
  case let number as Int:
    return number
  case let number as NSNumber:
    return number.intValue
  default:
    return nil
  }
}

func captureShots(_ requests: [ShotRequest]) -> [Int: CGImage] {
  let grouped = Dictionary(grouping: requests, by: \.x)
  var shots: [Int: CGImage] = [:]
  for (offset, x) in grouped.keys.sorted().enumerated() {
    let members = grouped[x] ?? []
    let chosen = members.first(where: \.focused) ?? members.max(by: { $0.area < $1.area })
    guard let chosen else { continue }
    guard let image = CGWindowListCreateImage(
      .null,
      .optionIncludingWindow,
      chosen.id,
      [.boundsIgnoreFraming, .nominalResolution]
    ), image.width > 1, image.height > 1 else { continue }
    shots[offset + 1] = image
  }
  return shots
}

func drawMinimapBlocks(_ image: CGImage, in rect: CGRect, dimmed: Bool) {
  let cellW: CGFloat = 9
  let cellH: CGFloat = 6
  let cols = max(1, Int(rect.width / cellW))
  let rows = max(1, Int(rect.height / cellH))
  var pixels = [UInt8](repeating: 0, count: cols * rows * 4)
  let cs = CGColorSpaceCreateDeviceRGB()
  let ok = pixels.withUnsafeMutableBytes { raw -> Bool in
    guard let ctx = CGContext(
      data: raw.baseAddress,
      width: cols,
      height: rows,
      bitsPerComponent: 8,
      bytesPerRow: cols * 4,
      space: cs,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return false }
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: cols, height: rows))
    return true
  }
  guard ok else { return }
  let cw = rect.width / CGFloat(cols)
  let ch = rect.height / CGFloat(rows)
  let shade: CGFloat = dimmed ? 0.72 : 1
  for y in 0..<rows {
    for x in 0..<cols {
      let i = ((rows - 1 - y) * cols + x) * 4
      let r0 = CGFloat(pixels[i]) / 255
      let g0 = CGFloat(pixels[i + 1]) / 255
      let b0 = CGFloat(pixels[i + 2]) / 255
      let l = 0.3 * r0 + 0.59 * g0 + 0.11 * b0
      if l < 0.08 { continue }
      NSColor(calibratedRed: r0 * shade, green: g0 * shade, blue: b0 * shade, alpha: 1).setFill()
      NSRect(
        x: rect.minX + CGFloat(x) * cw + 0.5,
        y: rect.minY + CGFloat(y) * ch + 0.5,
        width: max(cw - 1, 1),
        height: max(ch - 1, 1)
      ).fill()
    }
  }
}

func contentSlice(_ image: CGImage, slotAspect: CGFloat) -> CGImage {
  let aspect = max(slotAspect, 0.2)
  let cropH = min(image.height, max(1, Int((CGFloat(image.width) / aspect).rounded())))
  if cropH >= image.height { return image }
  let y = 0
  return image.cropping(to: CGRect(x: 0, y: y, width: image.width, height: cropH)) ?? image
}

func posterize(_ image: CGImage, levels: Int) -> CGImage {
  let steps = max(levels, 2)
  let width = image.width
  let height = image.height
  var pixels = [UInt8](repeating: 0, count: width * height * 4)
  let cs = CGColorSpaceCreateDeviceRGB()
  let ok = pixels.withUnsafeMutableBytes { raw -> Bool in
    guard let ctx = CGContext(
      data: raw.baseAddress,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: cs,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return false }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return true
  }
  guard ok else { return image }
  let q = 255 / (steps - 1)
  for i in stride(from: 0, to: pixels.count, by: 4) {
    for c in 0..<3 {
      let v = Int(pixels[i + c])
      pixels[i + c] = UInt8(((v * (steps - 1) + 127) / 255) * q)
    }
  }
  return pixels.withUnsafeMutableBytes { raw -> CGImage in
    guard let ctx = CGContext(
      data: raw.baseAddress,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: cs,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let out = ctx.makeImage() else { return image }
    return out
  }
}

func busiestBandY(_ image: CGImage, cropH: Int) -> Int {
  let sampleW = 32
  let sampleH = 24
  var pixels = [UInt8](repeating: 0, count: sampleW * sampleH * 4)
  let drew = pixels.withUnsafeMutableBytes { raw -> Bool in
    guard let ctx = CGContext(
      data: raw.baseAddress,
      width: sampleW,
      height: sampleH,
      bitsPerComponent: 8,
      bytesPerRow: sampleW * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return false }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: sampleW, height: sampleH))
    return true
  }
  guard drew else { return max(0, (image.height - cropH) / 5) }
  var rowVar = [Double](repeating: 0, count: sampleH)
  for y in 0..<sampleH {
    var sum = 0.0
    var sum2 = 0.0
    for x in 0..<sampleW {
      let i = (y * sampleW + x) * 4
      let l = 0.3 * Double(pixels[i]) + 0.59 * Double(pixels[i + 1]) + 0.11 * Double(pixels[i + 2])
      sum += l
      sum2 += l * l
    }
    let n = Double(sampleW)
    let mean = sum / n
    rowVar[y] = sum2 / n - mean * mean
  }
  let band = min(sampleH, max(1, Int((Double(cropH) / Double(image.height) * Double(sampleH)).rounded())))
  var bestStart = 0
  var best = -1.0
  if band < sampleH {
    for start in 0...(sampleH - band) {
      let score = rowVar[start..<(start + band)].reduce(0, +)
      if score > best {
        best = score
        bestStart = start
      }
    }
  }
  let y = Int((Double(bestStart) / Double(sampleH) * Double(image.height)).rounded())
  return min(max(0, y), image.height - cropH)
}

@main
enum Main {
  static func main() {
    let app = NSApplication.shared
    let delegate = App()
    app.setActivationPolicy(.accessory)
    app.delegate = delegate
    app.run()
  }
}
