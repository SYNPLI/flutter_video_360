import Flutter
import UIKit
import AVKit

class Video360View: UIView, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {}

    private let channel: FlutterMethodChannel

    private var timer: Timer?
    private var timeObserver: Any?
    private var player: AVPlayer?
    private var swifty360View: Swifty360View?
    private var fieldOfViewScale: CGFloat = 1

    init(viewId: String, messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(name: viewId, binaryMessenger: messenger)

        super.init(frame: .zero)

        self.addChannel()
    }

    deinit {
        dispose()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



// MARK: - Interface
extension Video360View {

    // flutter channel
    private func addChannel() {
        self.channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else {
                result(FlutterError(code: "player_disposed", message: "Video view has been released", details: nil))
                return
            }
            if call.method != "init" && call.method != "dispose" &&
                (self.player == nil || self.swifty360View == nil) {
                result(FlutterError(code: "player_not_initialized", message: "Video player is not initialized", details: nil))
                return
            }

            switch call.method {
            case "init":
                guard let argMaps = call.arguments as? Dictionary<String, Any>,
                      let url = argMaps["url"] as? String,
                      let videoURL = URL(string: url),
                      let headers = argMaps["headers"] as? Dictionary<String, String>,
                      let isAutoPlay = argMaps["isAutoPlay"] as? Bool,
                      let isRepeat = argMaps["isRepeat"] as? Bool,
                      let width = argMaps["width"] as? Double,
                      let height = argMaps["height"] as? Double,
                      let fieldOfViewScale = argMaps["fieldOfViewScale"] as? Double else {
                    result(FlutterError(code: call.method, message: "Missing argument", details: nil))
                    return
                }

                self.fieldOfViewScale = CGFloat(fieldOfViewScale)
                self.initView(videoURL: videoURL, headers: headers, width: width, height: height)
                self.updateTime()

                if isAutoPlay {
                    self.checkPlayerState()
                }

                if isRepeat {
                    NotificationCenter.default.addObserver(self,
                                                           selector: #selector(self.playerFinish(noti:)),
                                                           name: .AVPlayerItemDidPlayToEndTime,
                                                           object: nil)
                }

            case "dispose":
                self.dispose()

            case "play":
                self.play()

            case "stop":
                self.stop()

            case "reset":
                guard let argMaps = call.arguments as? Dictionary<String, Any>,
                      let autoplay = argMaps["autoplay"] as? Bool else {
                    result(FlutterError(code: call.method, message: "Missing argument", details: nil))
                    return
                }
                
                self.reset(autoplay: autoplay)

            case "jumpTo":
                guard let argMaps = call.arguments as? Dictionary<String, Any>,
                      let time = argMaps["millisecond"] as? Double,
                      let autoplay = argMaps["autoplay"] as? Bool else {
                    result(FlutterError(code: call.method, message: "Missing argument", details: nil))
                    return
                }
                self.jumpTo(second: time / 1000.0, autoplay: autoplay)

            case "seekTo":
                guard let argMaps = call.arguments as? Dictionary<String, Any>,
                      let time = argMaps["millisecond"] as? Double,
                      let autoplay = argMaps["autoplay"] as? Bool else {
                    result(FlutterError(code: call.method, message: "Missing argument", details: nil))
                    return
                }
                self.seekTo(second: time / 1000.0, autoplay: autoplay)

            case "onPanUpdate":
                guard let argMaps = call.arguments as? Dictionary<String, Any>,
                      let isStart = argMaps["isStart"] as? Bool,
                      let x = argMaps["x"] as? Double,
                      (0 ... Double(self.swifty360View?.frame.maxX ?? 0)) ~= x,
                      let y = argMaps["y"] as? Double,
                      (0 ... Double(self.swifty360View?.frame.maxY ?? 0)) ~= y else {
                    result(FlutterError(code: call.method, message: "Missing argument", details: nil))
                    return
                }
                let point = CGPoint(x: x, y: y)
                self.swifty360View?.cameraController.handlePan(isStart: isStart, point: point)
                
            case "resize":
                guard let argMaps = call.arguments as? Dictionary<String, Any>,
                      let width = argMaps["width"] as? Double,
                      let height = argMaps["height"] as? Double else {
                    result(FlutterError(code: call.method, message: "Missing argument", details: nil))
                    return
                }
                let size = CGSize(width: width, height: height)
                self.swifty360View?.frame.size = size
                self.swifty360View?.cameraController.updateCameraFOV(
                    withViewSize: size,
                    scale: self.fieldOfViewScale
                )
                
            case "centerCamera":
                self.swifty360View?.cameraController.currentPosition = CGPoint(x: 3.14, y: 0.0)
                guard var eulerAngles = self.swifty360View?.cameraController.pointOfView.eulerAngles else { return }
                eulerAngles.y = 3.14
                self.swifty360View?.cameraController.pointOfView.eulerAngles = eulerAngles

            default:
                result(FlutterMethodNotImplemented)
                return
            }
            result(nil)
        }
    }

    // 360View Init
    private func initView(videoURL: URL, headers: [String: String], width: Double, height: Double) {
        dispose()
        let asset = AVURLAsset(url: videoURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        let motionManager = Swifty360MotionManager.shared
        let view = Swifty360View(withFrame: CGRect(x: 0, y: 0, width: width, height: height),
                                 player: player, motionManager: motionManager)
        self.player = player
        self.swifty360View = view
        view.setup(player: player, motionManager: motionManager) { [weak self] compassAngle in
            self?.channel.invokeMethod("updateCompassAngle", arguments: ["compassAngle": compassAngle])
        }
        view.cameraController.allowDeviceMotionPanning = false
        view.cameraController.allowedPanGesturePanningAxes = [
            .horizontal,
            .vertical,
        ]
        view.cameraController.updateCameraFOV(
            withViewSize: CGSize(width: width, height: height),
            scale: self.fieldOfViewScale
        )
        self.addSubview(view)
    }

    // repeat
    @objc private func playerFinish(noti: NSNotification) {
        self.reset(autoplay: true)
    }

    //dispose
    func dispose() {
        timer?.invalidate()
        timer = nil
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        player = nil
        swifty360View?.removeFromSuperview()
        swifty360View = nil
        NotificationCenter.default.removeObserver(self)
    }

    // play
    private func play() {
        self.player?.play()
    }

    // stop
    private func stop() {
        self.player?.pause()
    }

    // reset
    private func reset(autoplay: Bool) {
        self.jumpTo(second: .zero, autoplay: autoplay)
    }

    // jumpTo
    private func jumpTo(second: Double, autoplay: Bool) {
        let sec = CMTimeMakeWithSeconds(Float64(second), preferredTimescale: Int32(NSEC_PER_SEC))
        self.player?.seek(to: sec)
        if (autoplay) {
            self.checkPlayerState()
        }
    }

    // seekTo
    private func seekTo(second: Double, autoplay: Bool) {
        guard let current = self.player?.currentTime() else { return }
        let sec = CMTimeMakeWithSeconds(Float64(second), preferredTimescale: Int32(NSEC_PER_SEC))
        self.player?.seek(to: current + sec)
        
        if (autoplay) {
            self.checkPlayerState()
        }
    }

    // updateTime
    private func updateTime() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        guard let player = self.player else { return }
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, let player = self.player, let view = self.swifty360View else { return }

            let duration = Int(Float(Int(time.value)) * 0.000001)
            let totalDuration = player.currentItem?.duration ?? .zero
            let total = Int(totalDuration.value)
            let isPlaying = player.isPlaying
            let compassAngle = view.compassAngle ?? 0

            self.channel.invokeMethod("updateTime", arguments: ["duration": duration, "total": total, "isPlaying": isPlaying, "compassAngle": compassAngle])
        }
    }

    // check player state - for auto play
    private func checkPlayerState() {
        guard self.timer == nil else { return }

        self.timer = Timer(timeInterval: 0.5,
                           target: self,
                           selector: #selector(self.checkReadyToPlay),
                           userInfo: nil,
                           repeats: true)
        RunLoop.main.add(self.timer!, forMode: .common)
    }

    @objc private func checkReadyToPlay() {
        guard let player = self.player,
              let currentItem = player.currentItem,
              currentItem.status == AVPlayerItem.Status.readyToPlay,
              currentItem.isPlaybackLikelyToKeepUp,
              !player.isPlaying else { return }

        self.play()

        self.timer?.invalidate()
        self.timer = nil
    }
}



// MARK: - AVPlayer Extension
extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}
