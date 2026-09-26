import SwiftUI
import Mailbox

struct HelmGoals: View {
  @EnvironmentObject var model: HelmModel

  var body: some View {
    let colors = helmColors(model.paintedTheme)
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text("Goals").font(.title2).foregroundStyle(Color(rgb: colors.fg))
            Spacer()
            Button("Full report") { model.askGoal(askAimsReport) }
            Button("Rubric") { model.askGoal(askAimsRubric) }
          }
          ForEach(model.aims.aims, id: \.area) { aim in
            aimCard(aim, colors: colors)
          }
          ForEach(model.aims.links, id: \.self) { link in
            Text(linkLine(link))
              .font(.caption)
              .foregroundStyle(Color(rgb: colors.muted))
          }
        }
        .padding(16)
      }
      .background(Color(rgb: colors.canvas))
      .navigationTitle("Goals")
      .navigationBarTitleDisplayMode(.inline)
    }
    .onChange(of: model.aims) { _ in
      model.markAimsSeen()
    }
  }

  private func aimCard(_ aim: Aim, colors: HelmColors) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(aim.area).font(.headline).foregroundStyle(Color(rgb: colors.fg))
        Spacer()
        Text(signed(aim.rating30))
          .font(.headline)
          .foregroundStyle(Color(rgb: scoreHex(aim.rating30, colors: colors)))
      }
      Text(aim.sentence).foregroundStyle(Color(rgb: colors.fg))
      dayGrid(aim.days, colors: colors)
      Text(statsLine(aim)).font(.caption).foregroundStyle(Color(rgb: colors.muted))
      if !aim.weeks.isEmpty {
        weekStrip(aim.weeks, colors: colors)
      }
      let trend = trendLine(aim)
      if !trend.isEmpty {
        Text(trend).font(.caption2).foregroundStyle(Color(rgb: colors.muted))
      }
      Button("Ask Kit about \(aim.area)") {
        model.askGoal(askAim(aim.area))
      }
      .accessibilityLabel("Ask Kit about \(aim.area)")
    }
    .padding(12)
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(rgb: colors.line), lineWidth: 1))
  }

  private func dayGrid(_ days: [AimDay], colors: HelmColors) -> some View {
    HStack(spacing: 4) {
      ForEach(Array(days.enumerated()), id: \.offset) { _, day in
        VStack(spacing: 2) {
          RoundedRectangle(cornerRadius: 3)
            .fill(day.events.isEmpty ? Color.clear : Color(rgb: scoreHex(Double(day.score), colors: colors)))
            .overlay(
              RoundedRectangle(cornerRadius: 3).stroke(Color(rgb: colors.line), lineWidth: day.events.isEmpty ? 1 : 0)
            )
            .opacity(day.events.isEmpty ? 1 : dayWeight(day.score))
            .frame(width: 16, height: 16)
          Text(signed(day.score)).font(.caption2).foregroundStyle(Color(rgb: colors.muted))
        }
      }
    }
  }

  private func weekStrip(_ weeks: [AimWeek], colors: HelmColors) -> some View {
    HStack(alignment: .center, spacing: 3) {
      ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
        let h = CGFloat(min(abs(week.mean), 3) / 3) * 18
        RoundedRectangle(cornerRadius: 2)
          .fill(Color(rgb: scoreHex(week.mean, colors: colors)))
          .frame(width: 8, height: max(week.mean == 0 ? 1 : h, 1))
      }
    }
    .frame(height: 36)
  }

  private func scoreHex(_ score: Double, colors: HelmColors) -> UInt32 {
    if score > 0 {
      return colors.ok
    }
    if score < 0 {
      return colors.danger
    }
    return colors.muted
  }
}

extension AimLink: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(a)
    hasher.combine(b)
    hasher.combine(r)
    hasher.combine(n)
  }
}
