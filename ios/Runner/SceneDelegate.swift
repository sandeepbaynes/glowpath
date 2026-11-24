import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

}

/// The game remains a single Flutter view. A transparent, noninteractive UIKit
/// probe forwards the public layout regions that Flutter's iOS embedder does not
/// yet expose through MediaQuery.displayFeatures.
@objc(GlowpathViewController)
class GlowpathViewController: FlutterViewController {
  private var foldBridge: FoldGeometryBridge?
  private var foldProbe: FoldGeometryProbe?

  override func viewDidLoad() {
    super.viewDidLoad()
    let bridge = FoldGeometryBridge()
    let channel = FlutterEventChannel(
      name: "app.glowpath/fold_geometry",
      binaryMessenger: binaryMessenger
    )
    channel.setStreamHandler(bridge)
    bridge.channel = channel
    let capabilityChannel = FlutterMethodChannel(
      name: "app.glowpath/fold_geometry_support",
      binaryMessenger: binaryMessenger
    )
    capabilityChannel.setMethodCallHandler { call, result in
      guard call.method == "available" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if #available(iOS 27.1, *) {
        result(true)
      } else {
        result(false)
      }
    }
    bridge.capabilityChannel = capabilityChannel
    foldBridge = bridge

    let probe = FoldGeometryProbe(frame: view.bounds)
    probe.coordinateView = view
    probe.bridge = bridge
    probe.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    probe.backgroundColor = .clear
    probe.isUserInteractionEnabled = false
    probe.accessibilityElementsHidden = true
    view.addSubview(probe)
    foldProbe = probe
    probe.observeHinge()
    probe.setNeedsUpdateConstraints()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    foldProbe?.setNeedsUpdateConstraints()
  }

  deinit {
    foldBridge?.close()
  }
}

private final class FoldGeometryBridge: NSObject, FlutterStreamHandler {
  var channel: FlutterEventChannel?
  var capabilityChannel: FlutterMethodChannel?
  private var sink: FlutterEventSink?
  private var latest: [String: Any] = [
    "version": 1, "supported": false, "width": 0.0, "height": 0.0,
    "divisions": [], "occlusions": [], "status": "unavailable",
  ]

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    events(latest)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func close() {
    channel?.setStreamHandler(nil)
    capabilityChannel?.setMethodCallHandler(nil)
    sink = nil
  }

  func updateGeometry(size: CGSize, divisions: [CGRect], occlusions: [CGRect], supported: Bool) {
    var next = latest
    next["width"] = size.width
    next["height"] = size.height
    next["divisions"] = divisions.map(Self.encode)
    next["occlusions"] = occlusions.map(Self.encode)
    next["supported"] = supported
    publish(next)
  }

  func updateHinge(status: String) {
    var next = latest
    next["status"] = status
    publish(next)
  }

  private func publish(_ next: [String: Any]) {
    guard !NSDictionary(dictionary: next).isEqual(to: latest) else { return }
    latest = next
    sink?(next)
  }

  private static func encode(_ frame: CGRect) -> [String: Double] {
    ["x": Double(frame.minX), "y": Double(frame.minY),
     "width": Double(frame.width), "height": Double(frame.height)]
  }
}

private final class FoldGeometryProbe: UIView {
  weak var coordinateView: UIView?
  weak var bridge: FoldGeometryBridge?
  private var hingeInteraction: UIInteraction?
  private var lastBounds = CGRect.null
#if DEBUG
  private var debugHingeStatus = "unavailable"
  private var lastDebugGeometry = ""
#endif

  func observeHinge() {
    guard #available(iOS 27.1, *) else { return }
    let interaction = UIHingeInteraction { [weak self] _, update in
      let status: String
      if let hinge = update.hinge {
        switch hinge.status {
        case .closed: status = "closed"
        case .partiallyOpen: status = "partiallyOpen"
        case .fullyOpen: status = "fullyOpen"
        case .unknown: status = "unknown"
        @unknown default: status = "unknown"
        }
      } else {
        status = "unavailable"
      }
      // Status is diagnostic. Layout follows reserved regions, never angle
      // thresholds or the frequency of hinge-input callbacks.
      self?.bridge?.updateHinge(status: status)
#if DEBUG
      if let self, self.debugHingeStatus != status {
        self.debugHingeStatus = status
        NSLog("GlowpathFold status=%@", status)
      }
#endif
    }
    hingeInteraction = interaction
    addInteraction(interaction)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    setNeedsUpdateConstraints()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if bounds != lastBounds {
      lastBounds = bounds
      setNeedsUpdateConstraints()
    }
  }

  override func updateConstraints() {
    if let coordinateView {
      if #available(iOS 27.1, *) {
        // UIKit tracks these reads and schedules this method again when the
        // regions change. Frames are view-local points and include margins.
        let divisions = reservedRegions(kind: .division).map {
          flutterFrame($0.frame, in: coordinateView)
        }
        let occlusions = reservedRegions(kind: .occlusion).map {
          flutterFrame($0.frame, in: coordinateView)
        }
        bridge?.updateGeometry(size: coordinateView.bounds.size, divisions: divisions,
                               occlusions: occlusions, supported: true)
#if DEBUG
        logGeometry(in: coordinateView, divisions: divisions, occlusions: occlusions)
#endif
      } else {
        bridge?.updateGeometry(size: coordinateView.bounds.size, divisions: [],
                               occlusions: [], supported: false)
#if DEBUG
        logGeometry(in: coordinateView, divisions: [], occlusions: [])
#endif
      }
    }
    super.updateConstraints()
  }

  private func flutterFrame(_ frame: CGRect, in target: UIView) -> CGRect {
    // Flutter uses a zero-origin viewport. Do not multiply by screen scale:
    // UIKit points already correspond to Flutter logical pixels on iOS.
    convert(frame, to: target).offsetBy(dx: -target.bounds.minX, dy: -target.bounds.minY)
  }

#if DEBUG
  private func logGeometry(in target: UIView, divisions: [CGRect], occlusions: [CGRect]) {
    func rect(_ value: CGRect) -> [Double] {
      [Double(value.minX), Double(value.minY), Double(value.width), Double(value.height)]
    }
    let insets = target.safeAreaInsets
    let snapshot: [String: Any] = [
      "viewBounds": rect(target.bounds),
      "safeAreaInsets": ["top": Double(insets.top), "left": Double(insets.left),
                         "bottom": Double(insets.bottom), "right": Double(insets.right)],
      "divisions": divisions.map(rect), "occlusions": occlusions.map(rect),
      "status": debugHingeStatus,
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: snapshot, options: [.sortedKeys]),
          let line = String(data: data, encoding: .utf8), line != lastDebugGeometry else { return }
    lastDebugGeometry = line
    NSLog("GlowpathFold geometry=%@", line)
  }
#endif
}
