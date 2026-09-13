import Combine
import Foundation
import Mailbox
import UserNotifications

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
  @Published var authHint = ""
  @Published var signingIn = false
  @Published var resumed = true
  @Published var carAttached = false
  @Published var carThreadVisible = false
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

  init(sample: String? = nil) {
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
    } else {
      hydrateDisk()
      publish()
      refreshLook()
    }
    if gpsOn {
      location.setEnabled(true)
    }
    startSweep()
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

  func persistFields() {
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

  func sendText() {
    persistFields()
    let photo = stagedPhoto
    guard composeHasTurn(text: compose, photo: photo) else {
      return
    }
    let id = UUID().uuidString
    let ctx = PhoneContext(
      at: ISO8601DateFormatter().string(from: Date()),
      tz: TimeZone.current.identifier,
      geo: gpsOn ? prefs.lastGeo : nil,
      surface: surfaceHint(carAttached: carAttached)
    )
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
    let frame = pinFrame(PhoneContext(geo: geo, surface: surfaceHint(carAttached: carAttached)))
    if socket?.send(frame) != true {
      _ = outbox.push(frame)
      connect()
    }
    mouth.setHint(geoHint(enabled: true, geo: geo))
    publish()
  }

  func ingest(_ frame: WireFrame) {
    seen.note(frame: frame)
    let painted = mouth.ingest(frame)
    if painted && shouldSpeak(frame.kind, replay: frame.replay)
      && shouldPost(
        resumed: resumed,
        carAttached: carAttached,
        kind: frame.kind,
        threadVisible: carThreadVisible
      )
    {
      HelmNotify.postKit(
        slug: slug,
        body: notifyBody(frame.text, hasPhoto: frame.images?.isEmpty == false),
        replay: frame.replay
      )
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
      let back = wantBack
        ? api?.fetch(origin: origin, slug: slug, bearer: bearer, rev: backRev, path: "/api/backdrop")
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
    objectWillChange.send()
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
