import Foundation

public let sampleIds = ["unsigned", "empty", "thread", "stream", "ping", "photo", "down"]

public struct SampleScene: Equatable {
  public var id: String
  public var slug: String
  public var email: String
  public var up: Bool
  public var hint: String
  public var lines: [ChatLine]
  public var typing: Bool

  public init(
    id: String,
    slug: String = "kit",
    email: String,
    up: Bool,
    hint: String,
    lines: [ChatLine],
    typing: Bool = false
  ) {
    self.id = id
    self.slug = slug
    self.email = email
    self.up = up
    self.hint = hint
    self.lines = lines
    self.typing = typing
  }
}

public func parseSample(_ raw: String?) -> String? {
  let id = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
  return sampleIds.contains(id) ? id : nil
}

/// `-sample thread` or `--sample=thread`. Unknown ids are ignored.
public func launchSampleId(_ args: [String]) -> String? {
  if let i = args.firstIndex(of: "-sample"), args.indices.contains(i + 1) {
    return parseSample(args[i + 1])
  }
  for arg in args {
    if arg.hasPrefix("--sample=") {
      return parseSample(String(arg.dropFirst("--sample=".count)))
    }
  }
  return nil
}

/// Paint a canned scene. Hydrate skips drafts, so this uses `replace`.
public func paintSample(_ mouth: Mouth, scene: SampleScene) {
  mouth.replace(lines: scene.lines, up: scene.up, hint: scene.hint)
  if scene.typing {
    mouth.ingest(WireFrame(kind: "typing"))
  }
  mouth.setAvatarRev(0)
  mouth.setBackdropRev(0)
  mouth.setRoomTheme("")
  mouth.setFaceHint("")
}

/// Canned Ada/Kit turns for Simulator `-sample thread`. Release ignores it.
public func sampleScene(_ id: String) -> SampleScene? {
  guard let key = parseSample(id) else {
    return nil
  }
  switch key {
  case "unsigned":
    return SampleScene(
      id: key, email: "", up: false, hint: "Sign in with Google to talk", lines: []
    )
  case "empty":
    return SampleScene(
      id: key,
      email: "ada@example.com",
      up: true,
      hint: "GPS attaches on send if the OS allows it.",
      lines: []
    )
  case "ping":
    return SampleScene(
      id: key,
      email: "ada@example.com",
      up: true,
      hint: "pin ±12m this send",
      lines: [
        sampleLine("p1", false, "20:40 — still on the dock? Gate latches in twenty.", kind: "push"),
        sampleLine("p2", true, "Walking back."),
        sampleLine("p3", false, "I'll hush."),
      ]
    )
  case "down":
    return SampleScene(
      id: key,
      email: "ada@example.com",
      up: false,
      hint: "socket down — reconnecting",
      lines: [
        sampleLine("d1", true, "On the dock — is the gate still open?", pending: true),
      ]
    )
  case "stream":
    return SampleScene(
      id: key,
      email: "ada@example.com",
      up: true,
      hint: "pin ±12m this send",
      lines: [
        sampleLine("s1", true, "On the dock — is the gate still open?"),
        ChatLine(
          id: draftId, fromYou: false, text: "Gate's on the latch until 21:00. I'll ping you at…",
          kind: "draft", live: true
        ),
      ],
      typing: true
    )
  case "photo":
    return SampleScene(
      id: key,
      email: "ada@example.com",
      up: true,
      hint: "pin ±12m this send",
      lines: [
        sampleLine("ph1", true, "This the right hatch?", photo: samplePhotoUrl),
        sampleLine("ph2", false, "Yes — port side, yellow tape. Don't step the wet plate."),
      ]
    )
  default:
    return SampleScene(
      id: "thread",
      email: "ada@example.com",
      up: true,
      hint: "pin ±12m this send",
      lines: [
        sampleLine("t1", true, "On the dock — is the gate still open?"),
        sampleLine(
          "t2", false, "Gate's on the latch until 21:00. I'll ping you at 20:40 if you're still out."
        ),
        sampleLine("t3", true, "Leave by 20:50 then."),
        sampleLine("t4", false, "Leave-by 20:50. Pin is this-send, ±12m."),
      ]
    )
  }
}

/// 1×1 JPEG so the photo bubble paints without Cab's drawable.
public let samplePhotoUrl =
  "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wAAAAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI/8AAEQgAAQABAwERAAIRAQMRAf/EABQBAQAAAAAAAAAAAAAAAAAAAAj/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAGf/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="

func sampleLine(
  _ id: String,
  _ fromYou: Bool,
  _ text: String,
  kind: String? = nil,
  photo: String? = nil,
  pending: Bool = false
) -> ChatLine {
  ChatLine(id: id, fromYou: fromYou, text: text, kind: kind, photo: photo, pending: pending)
}

/// `prefix.apps.googleusercontent.com` → `com.googleusercontent.apps.prefix`
public func reversedGoogleClientId(_ iosClientId: String) -> String {
  let id = iosClientId.trimmingCharacters(in: .whitespacesAndNewlines)
  let suffix = ".apps.googleusercontent.com"
  guard id.hasSuffix(suffix) else {
    return ""
  }
  return "com.googleusercontent.apps." + id.dropLast(suffix.count)
}
