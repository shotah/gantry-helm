import Mailbox
import SwiftUI

struct HelmTasks: View {
  @EnvironmentObject var model: HelmModel
  @State private var words = ""
  @State private var ticked: Set<Int64> = []

  var body: some View {
    let colors = helmColors(model.paintedTheme)
    let today = localDayStamp()
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Tasks").font(.title2).foregroundStyle(Color(rgb: colors.fg))
            Spacer()
            Button("Full list") { model.askTask(todoListCommand) }
          }
          ForEach(model.todo) { row in
            taskRow(row, today: today, colors: colors)
          }
          if let footer = pocketFooter(model.todo.count) {
            Text(footer)
              .font(.caption)
              .foregroundStyle(Color(rgb: colors.muted))
          }
          HStack(spacing: 8) {
            TextField("in your words", text: $words)
              .textFieldStyle(.roundedBorder)
              .onSubmit { addTask() }
            Button("Add") { addTask() }
          }
          .padding(.top, 8)
        }
        .padding(16)
      }
      .background(Color(rgb: colors.canvas))
      .navigationTitle("Tasks")
      .navigationBarTitleDisplayMode(.inline)
    }
    .onAppear { model.markTodoSeen() }
    .onChange(of: model.todo) { _ in
      ticked = settleTicked()
      model.markTodoSeen()
    }
  }

  private func taskRow(_ row: TodoRow, today: String, colors: HelmColors) -> some View {
    let done = ticked.contains(row.id)
    return HStack(alignment: .center, spacing: 8) {
      Button {
        guard canTick(id: row.id, ticked: ticked) else {
          return
        }
        ticked.insert(row.id)
        model.tickTask(todoDoneCommand(row.id))
      } label: {
        Image(systemName: done ? "checkmark.square.fill" : "square")
          .foregroundStyle(Color(rgb: colors.fg))
      }
      .accessibilityLabel("done \(row.slug)")
      VStack(alignment: .leading, spacing: 2) {
        Text(row.text)
          .strikethrough(done)
          .foregroundStyle(Color(rgb: done ? colors.muted : colors.fg))
        Text(todoMeta(row, today: today))
          .font(.caption2)
          .foregroundStyle(Color(rgb: colors.muted))
      }
      Spacer(minLength: 0)
    }
  }

  private func addTask() {
    guard let text = todoAddText(words) else {
      return
    }
    words = ""
    model.askTask(text)
  }
}

private func localDayStamp(_ date: Date = Date(), calendar: Calendar = .current) -> String {
  let c = calendar.dateComponents([.year, .month, .day], from: date)
  guard let y = c.year, let m = c.month, let d = c.day else {
    return ""
  }
  return String(format: "%04d-%02d-%02d", y, m, d)
}
