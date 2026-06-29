import SwiftUI

/// History side panel — slides out to the right of the window on the same field
/// (not a popover). A focus-stats header sits above the session list. Each row
/// shows a session newest-first and can be renamed inline or deleted; both edits
/// rewrite the JSONL log via the model. (Plan §5 noted history as a v2 add;
/// promoted to v1, then extended with stats + editing by request.)
struct HistoryPanel: View {
    var model: TimerModel
    var onClose: () -> Void
    @State private var records: [SessionRecord] = []
    @State private var stats = TimerModel.Stats(count: 0, totalSeconds: 0, weekSeconds: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("History").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkSoft)
                .help("Close")
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
            Divider()

            statsBlock
            Divider()

            if records.isEmpty {
                Spacer()
                Text("아직 완료된 세션이 없어요")
                    .font(Theme.labelFont)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(records) { record in
                            HistoryRow(record: record, onUpdate: update, onDelete: delete)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
        .onAppear(perform: reload)
    }

    // Focus stats — count + lifetime + this-week, in the label: value shape.
    private var statsBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            statLine("지금까지 수행한 타이머", "\(stats.count)")
            statLine("지금까지 집중한 시간", Self.focusText(stats.totalSeconds))
            statLine("이번주 집중한 시간", Self.focusText(stats.weekSeconds))
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func statLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(label + ":")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
    }

    /// Whole-minute focus duration → "X시간 Y분" (drops a zero hour or minute).
    static func focusText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)시간 \(m)분" }
        if h > 0 { return "\(h)시간" }
        return "\(m)분"
    }

    private func reload() {
        records = model.allRecords()
        stats = model.stats()
    }

    private func update(_ id: UUID, _ label: String) {
        model.updateRecordLabel(id, label)
        reload()
    }

    private func delete(_ id: UUID) {
        model.deleteRecord(id)
        reload()
    }
}

private struct HistoryRow: View {
    let record: SessionRecord
    var onUpdate: (UUID, String) -> Void
    var onDelete: (UUID) -> Void

    @State private var editing = false
    @State private var draft = ""

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d HH:mm"
        return f
    }()

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: record.completed ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(record.completed ? Theme.red : Theme.inkSoft)

            VStack(alignment: .leading, spacing: 2) {
                if editing {
                    TextField("목표", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .onSubmit(commit)
                } else {
                    Text((record.label?.isEmpty == false) ? record.label! : "(목표 없음)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                }
                Text("\(Self.formatter.string(from: record.startedAt)) · \(record.actualSeconds / 60)/\(record.plannedSeconds / 60)분")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
            }

            Spacer(minLength: 6)

            if editing {
                iconButton("checkmark", tint: Theme.red, help: "저장", action: commit)
            } else {
                iconButton("pencil", tint: Theme.inkSoft, help: "수정") {
                    draft = record.label ?? ""
                    editing = true
                }
                iconButton("trash", tint: Theme.inkSoft, help: "삭제") { onDelete(record.id) }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
    }

    private func commit() {
        onUpdate(record.id, draft)
        editing = false
    }

    private func iconButton(_ name: String, tint: Color, help: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
