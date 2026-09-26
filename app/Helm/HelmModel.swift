import Combine
import Foundation
import Mailbox
import UserNotifications

#if canImport(Network)
  import Network
#endif
#if canImport(UIKit)
  import UIKit
#endif

@MainActor
final class HelmModel: ObservableObject {
  let mouth = Mouth()
  let prefs = HelmPrefs()
  let seen = SeenCursor()
  private var outbox = Outbox()
  private var socket: MailboxSocket?
  private var cache: ThreadCache?
  private var blobs: AvatarApi?
  private let notify = HelmNotifyDelegate()
  private let location = HelmLocation()
  private let net = HelmNet()
  private let voice = HelmVoice()
  private var sweepTimer: Timer?
  private(set) var sampleShown = false

  @Published var origin: String
  @Published var slug: String
  @Published var spike: String
  @Published var email: String
  @Published var sub: String = ""
  @Published var cranes: [String] = []
  @Published var themeId: String
  @Published var fontId: String
  @Published var photoSizeId: String
  @Published var backdropOn: Bool
  @Published var followTheme: Bool
  @Published var gpsOn: Bool
  @Published var compose = ""
  @Published var stagedPhoto: String?
  @Published var showSettings = false
  @Published var showEmoji = false
  @Published var showAttach = false
  @Published var authHint = ""
  @Published var signingIn = false
  @Published var resumed = true
  @Published var carAttached = false
  @Published var carThreadVisible = false
  @Published var aims = AimsBoard()
  @Published var aimsSeen: [String: String] = [:]
  @Published var showGoals = false
  @Published var voiceOn = false
  @Published var voiceOffered = false
  @Published var langId = defaultLang
  @Published var speakPhase: SpeakPhase = .idle
  @Published var hold = HoldState.idle
  @Published var lines: [ChatLine] = []
  @Published var up = false
  @Published var hint = ""
  @Published var catalog: [SlashCommand] = []
  @Published var roomTheme = ""
  @Published var avatarRev = 0
  @Published var backdropRev = 0
  @Published var faceJpeg: Data?
  @Published var backdropJpeg: Data?
  @Published var typingUntil: Int64 = 0
  @Published var googleReady: Bool
  @Published var webClientId: String
  @Published var draft = ""

  var paintedTheme: String {
    Mailbox.paintedTheme(follow: followTheme, roomTheme: roomTheme, mine: themeId)
  }

  var bearer: String {
    liveBearer(
      session: prefs.session,
      sessionExp: prefs.sessionExp,
      spike: spike,
      nowEpochSec: Int64(Date().timeIntervalSince1970)
    )
  }

  init(sample: String? = nil, theme: String? = nil, open: String? = nil) {
    origin = prefs.origin
    slug = prefs.slug
    spike = prefs.spike
    email = prefs.email
    themeId = prefs.theme
    fontId = prefs.font
    photoSizeId = prefs.photoSize
    backdropOn = prefs.backdrop
    followTheme = prefs.followTheme
    gpsOn = prefs.gps
    aimsSeen = parseSeenAims(prefs.aimsSeen)
    voiceOn = prefs.voice
    voiceOffered = prefs.voiceOffered
    langId = prefs.lang
    webClientId = HelmConfig.googleWebClientId
    googleReady = !HelmConfig.googleWebClientId.trimmingCharacters(in: .whitespaces).isEmpty
    cache = ThreadCache(file: HelmPrefs.threadFile)
    blobs = AvatarApi(transport: URLSessionTransport(), cache: BlobCache(dir: HelmPrefs.blobDir))
    bindNotifyReply()
    location.onFix = { [weak self] geo in
      Task { @MainActor in
        self?.prefs.lastGeo = geo
        if self?.gpsOn == true {
          self?.mouth.setHint(geoHint(enabled: true, geo: geo))
          self?.publish()
        }
      }
    }
    if HelmConfig.debug, let id = parseSample(sample) {
      applySample(id)
      applyShotChrome(theme: theme, open: open)
    } else {
      hydrateDisk()
      publish()
      refreshLook()
    }
    if gpsOn && !sampleShown {
      location.setEnabled(true)
    }
    HelmCar.start { [weak self] attached in
      Task { @MainActor in
        self?.carAttached = attached
      }
    }
    net.start()
    bindVoice()
    if !sampleShown {
      refreshVoice()
    }
    startSweep()
  }

  var goalsChanged: Int {
    changedAims(aims, seen: aimsSeen)
  }

  var voiceBar: Bool {
    voiceBarShown(offered: voiceOffered, on: voiceOn)
  }

  func applySample(_ id: String) {
    guard HelmConfig.debug, let scene = sampleScene(id) else {
      return
    }
    sampleShown = true
    slug = scene.slug
    email = scene.email
    paintSample(mouth, scene: scene)
    stagedPhoto = nil
    publish()
  }

  func bindNotifyReply() {
    notify.onReply = { [weak self] text in
      Task { @MainActor in
        guard let self else {
          return
        }
        self.compose = text
        self.sendText()
      }
    }
    UNUserNotificationCenter.current().delegate = notify
  }

  func setGps(_ on: Bool) {
    gpsOn = on
    persistFields()
    location.setEnabled(on)
    mouth.setHint(geoHint(enabled: on, geo: on ? prefs.lastGeo : nil))
    publish()
  }

  func startSweep() {
    sweepTimer?.invalidate()
    let seconds = TimeInterval(sweepEveryMs) / 1000
    sweepTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.tickSweep()
      }
    }
  }

  func tickSweep() {
    guard watchingThread(phoneResumed: resumed, carThreadVisible: carThreadVisible) else {
      return
    }
    _ = socket?.sweep()
  }

  func applyShotChrome(theme: String?, open: String?) {
    guard sampleShown else {
      return
    }
    if let theme, !theme.isEmpty {
      themeId = parseTheme(theme)
      followTheme = false
    }
    switch open {
    case "settings":
      showSettings = true
    case "emoji":
      showEmoji = true
    case "attach":
      showAttach = true
    case "draft":
      stagedPhoto = samplePhotoUrl
    default:
      break
    }
    publish()
  }

  func persistFields() {
    if sampleShown {
      return
    }
    prefs.origin = origin
    prefs.slug = slug
    prefs.theme = themeId
    prefs.font = fontId
    prefs.photoSize = photoSizeId
    prefs.backdrop = backdropOn
    prefs.followTheme = followTheme
    prefs.gps = gpsOn
    prefs.putSpike(
      spike,
      persistToDisk: persistSpikeAllowed(
        origin: origin,
        hasGoogleSession: !prefs.session.isEmpty,
        debugBuild: HelmConfig.debug
      )
    )
  }

  func connect() {
    persistFields()
    let err = mailboxConnectError(
      slug: slug,
      bearer: bearer,
      sessionExpired: sessionExpired(
        expEpochSec: prefs.sessionExp,
        nowEpochSec: Int64(Date().timeIntervalSince1970)
      )
    )
    if let err {
      mouth.setHint(err)
      publish()
      return
    }
    mouth.setHint("Connecting…")
    publish()
    if socket == nil {
      socket = MailboxSocket(
        onFrame: { [weak self] frame in
          Task { @MainActor in self?.ingest(frame) }
        },
        onState: { [weak self] up in
          Task { @MainActor in
            self?.mouth.setUp(up)
            if up {
              self?.mouth.setHint("Live")
              self?.flushOutbox()
              self?.sendSeenIfWatching()
              self?.refreshVoice()
            } else {
              self?.mouth.setHint("Offline")
            }
            self?.publish()
          }
        },
        onAuthLost: { [weak self] in
          Task { @MainActor in self?.authLost() }
        }
      )
    }
    socket?.start(origin: origin, slug: slug, bearer: bearer)
    startSweep()
    refreshLook()
  }

  func sendText(spoken: Bool = false) {
    persistFields()
    let photo = stagedPhoto
    guard composeHasTurn(text: compose, photo: photo) else {
      return
    }
    let id = UUID().uuidString
    let ctx = currentContext(geo: gpsOn ? prefs.lastGeo : nil, spoken: spoken)
    let frame = inbound(compose, id: id, context: ctx, images: photo.map { [$0] })
    mouth.add(
      ChatLine(
        id: id,
        fromYou: true,
        text: stripHarnessContext(compose),
        kind: "inbound",
        photo: photo,
        pending: true,
        at: Int64(Date().timeIntervalSince1970 * 1000)
      )
    )
    compose = ""
    stagedPhoto = nil
    if socket?.send(frame) != true {
      _ = outbox.push(frame)
      connect()
    }
    publish()
    persistThread()
  }

  func sendPin() {
    persistFields()
    guard let geo = prefs.lastGeo else {
      mouth.setHint(geoHint(enabled: gpsOn, geo: nil))
      publish()
      return
    }
    let frame = pinFrame(currentContext(geo: geo))
    if socket?.send(frame) != true {
      _ = outbox.push(frame)
      connect()
    }
    mouth.setHint(geoHint(enabled: true, geo: geo))
    publish()
  }

  func setResumed(_ on: Bool) {
    resumed = on
    if on {
      HelmNotify.dismissKit()
      sendSeenIfWatching()
    }
  }

  func sendSeenIfWatching() {
    guard watchingThread(phoneResumed: resumed, carThreadVisible: carThreadVisible) else {
      return
    }
    _ = socket?.send(ackSeen())
  }

  func react(id: String, emoji: String) {
    guard socket?.send(reactFrame(id: id, text: emoji)) == true else {
      return
    }
    mouth.applyReaction(id: id, text: emoji)
    publish()
  }

  func askGoal(_ text: String) {
    showGoals = false
    compose = text
    sendText()
  }

  func markAimsSeen() {
    let seen = seenAims(mouth.aims)
    aimsSeen = seen
    prefs.aimsSeen = encodeSeenAims(seen)
  }

  func toggleVoice() {
    voiceOn.toggle()
    prefs.voice = voiceOn
    if !voiceOn {
      voice.hush()
      speakPhase = .idle
      hold = .idle
    }
  }

  func setLang(_ id: String) {
    langId = parseLang(id)
    prefs.lang = langId
  }

  func voiceDown() {
    voice.hush()
    speakPhase = .idle
    hold = .listening
    voice.begin(lang: langId)
  }

  func voiceUp() {
    hold = .finishing
    voice.finish()
  }

  func voiceCancel() {
    hold = .idle
    voice.abort()
  }

  func ingest(_ frame: WireFrame) {
    seen.note(frame: frame)
    let painted = mouth.ingest(frame)
    voice.heard(
      frame: frame,
      fresh: painted,
      origin: origin,
      bearer: bearer,
      lang: langId
    )
    if dismissKitOnFrame(kind: frame.kind, replay: frame.replay, fresh: painted, seen: frame.seen) {
      HelmNotify.dismissKit()
    }
    if painted && shouldSpeak(frame.kind, replay: frame.replay)
      && watchingThread(phoneResumed: resumed, carThreadVisible: carThreadVisible),
      let id = frame.id
    {
      _ = socket?.send(ackSeen(id))
    }
    if let body = kitNoticeBody(
      painted: painted,
      kind: frame.kind,
      replay: frame.replay,
      resumed: resumed,
      carAttached: carAttached,
      threadVisible: carThreadVisible,
      text: frame.text,
      hasPhoto: frame.images?.isEmpty == false
    ) {
      HelmNotify.postKit(slug: slug, body: body, replay: false)
    }
    publish()
    persistThread()
    if frame.kind == "face" || frame.kind == "backdrop" {
      refreshLook()
    }
  }

  func stagePhoto(data: Data) {
    persistFields()
    let edge = photoEdge(photoSizeId)
    guard let jpeg = jpegFromImageData(data, edge: edge, maxBytes: photoJpegBytesMax) else {
      mouth.setHint(describePhotoError(photoErrorToken("too large")))
      publish()
      return
    }
    switch photoDataUrl(jpeg) {
    case .ok(let url):
      stagedPhoto = url
    case .err(let error):
      mouth.setHint(describePhotoError(error))
    }
    publish()
  }

  func signOut() {
    prefs.signOut()
    email = ""
    sub = ""
    cranes = []
    socket?.stop()
    mouth.setUp(false)
    mouth.setHint("Signed out")
    publish()
  }

  func applyGoogle(session: NativeSession) {
    prefs.session = session.token
    prefs.sessionExp = session.exp
    prefs.email = session.email ?? ""
    email = prefs.email
    sub = session.sub
    spike = ""
    prefs.putSpike("", persistToDisk: false)
    if let me = HelmGoogle.fetchMe(origin: origin, token: session.token) {
      cranes = me.cranes
      sub = me.sub
      if let listed = me.email, !listed.isEmpty {
        email = listed
        prefs.email = listed
      }
      if !me.cranes.isEmpty && !me.cranes.contains(slug) {
        slug = me.cranes[0]
      }
    }
    authHint = mailboxSignedInHint(email: email, cranes: cranes)
    publish()
    connect()
  }

  func setBackdrop(_ on: Bool) {
    backdropOn = on
    persistFields()
    refreshLook()
  }

  func authLost() {
    prefs.signOut()
    email = ""
    mouth.setHint(mailboxAuthLostHint())
    publish()
  }

  func carTest() {
    HelmNotify.postKit(slug: slug, body: carCheckText(carAttached: carAttached), replay: false)
  }

  func pickTheme(_ id: String) {
    themeId = parseTheme(id)
    followTheme = false
    persistFields()
    publish()
  }

  func currentContext(geo: Geo?, spoken: Bool = false) -> PhoneContext {
    PhoneContext(
      at: ISO8601DateFormatter().string(from: Date()),
      tz: TimeZone.current.identifier,
      geo: geo,
      battery: peekBattery(),
      net: peekNet(),
      surface: surfaceHint(carAttached: carAttached),
      input: inputHint(spoken: spoken)
    )
  }

  func peekBattery() -> BatteryHint? {
    #if canImport(UIKit)
      let device = UIDevice.current
      let wasOn = device.isBatteryMonitoringEnabled
      device.isBatteryMonitoringEnabled = true
      let level = device.batteryLevel
      let charging = device.batteryState == .charging || device.batteryState == .full
      if !wasOn {
        device.isBatteryMonitoringEnabled = false
      }
      return batteryHintFromLevel(level, charging: charging)
    #else
      return nil
    #endif
  }

  func peekNet() -> String {
    net.hint()
  }

  private func flushOutbox() {
    for frame in outbox.popAll() {
      _ = socket?.send(frame)
    }
  }

  func refreshLook() {
    let api = blobs
    faceJpeg = api?.cached(origin: origin, slug: slug)
    if backdropOn {
      backdropJpeg = api?.cached(origin: origin, slug: slug, path: "/api/backdrop")
    } else {
      backdropJpeg = nil
    }
    let origin = self.origin
    let slug = self.slug
    let bearer = self.bearer
    let faceRev = avatarRev
    let backRev = backdropRev
    let wantBack = backdropOn
    DispatchQueue.global(qos: .userInitiated).async {
      let face = api?.fetch(origin: origin, slug: slug, bearer: bearer, rev: faceRev)
      let back =
        wantBack
        ? api?.fetch(
          origin: origin, slug: slug, bearer: bearer, rev: backRev, path: "/api/backdrop")
        : nil
      DispatchQueue.main.async {
        self.faceJpeg = face
        self.backdropJpeg = wantBack ? back : nil
        self.publish()
      }
    }
  }

  private func hydrateDisk() {
    let room = ThreadRoom(origin: origin, slug: slug, user: email)
    let cached = cache?.read(room) ?? []
    mouth.hydrate(cached)
    for line in cached {
      if let seq = line.seq {
        seen.remember(id: line.id, seq: seq)
      }
    }
    roomTheme = prefs.roomTheme(slug)
  }

  private func persistThread() {
    if sampleShown {
      return
    }
    let room = ThreadRoom(origin: origin, slug: slug, user: email)
    cache?.write(room, lines: mouth.lines)
    prefs.putRoomTheme(slug, id: mouth.roomTheme)
  }

  private func publish() {
    lines = mouth.lines
    up = mouth.up
    hint = mouth.hint
    catalog = mouth.catalog
    roomTheme = mouth.roomTheme
    avatarRev = mouth.avatarRev
    backdropRev = mouth.backdropRev
    typingUntil = mouth.typingUntil
    aims = mouth.aims
    objectWillChange.send()
  }

  private func bindVoice() {
    voice.onWords = { [weak self] words in
      Task { @MainActor in
        guard let self else {
          return
        }
        self.hold = .idle
        let text = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard composeHasTurn(text: text, photo: self.stagedPhoto) else {
          return
        }
        self.voice.arm()
        self.compose = text
        self.sendText(spoken: true)
      }
    }
    voice.onPhase = { [weak self] phase in
      Task { @MainActor in
        self?.speakPhase = phase
      }
    }
    voice.onFail = { [weak self] why in
      Task { @MainActor in
        self?.mouth.setHint(why)
        self?.publish()
      }
    }
    voice.onBlocked = { [weak self] in
      Task { @MainActor in
        self?.hold = .blocked
      }
    }
  }

  private func refreshVoice() {
    let origin = self.origin
    guard !origin.trimmingCharacters(in: .whitespaces).isEmpty else {
      return
    }
    DispatchQueue.global(qos: .utility).async {
      guard
        let offered = try? AuthApi(transport: URLSessionTransport()).config(origin: origin).voice
      else {
        return
      }
      DispatchQueue.main.async {
        self.voiceOffered = offered
        self.prefs.voiceOffered = offered
      }
    }
  }
}

/// Cached `NWPathMonitor` so send can peek without waiting.
final class HelmNet {
  #if canImport(Network)
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.gantree.helm.net")
  #endif
  private let lock = NSLock()
  private var lastHint = "unknown"

  func start() {
    #if canImport(Network)
      monitor.pathUpdateHandler = { [weak self] path in
        let hint = netHint(
          wifi: path.usesInterfaceType(.wifi),
          cellular: path.usesInterfaceType(.cellular)
        )
        self?.lock.lock()
        self?.lastHint = hint
        self?.lock.unlock()
      }
      monitor.start(queue: queue)
    #endif
  }

  func hint() -> String {
    lock.lock()
    defer { lock.unlock() }
    return lastHint
  }
}

enum HelmConfig {
  static var debug: Bool {
    #if DEBUG
      true
    #else
      false
    #endif
  }

  static var mailboxOrigin: String {
    let baked = Bundle.main.object(forInfoDictionaryKey: "HelmMailboxOrigin") as? String ?? ""
    if !baked.trimmingCharacters(in: .whitespaces).isEmpty {
      return baked
    }
    #if DEBUG
      return "http://127.0.0.1:3000"
    #else
      return ""
    #endif
  }

  static var googleWebClientId: String {
    (Bundle.main.object(forInfoDictionaryKey: "HelmGoogleWebClientId") as? String) ?? ""
  }

  static var googleIosClientId: String {
    (Bundle.main.object(forInfoDictionaryKey: "HelmGoogleIosClientId") as? String) ?? ""
  }
}
