import SwiftUI

struct NextWorkoutNoteButton: View {
    @AppStorage("nextWorkoutNote") private var note = ""
    @AppStorage("appAccentColor") private var accentColorRawValue = ThemeColor.indigo.rawValue
    @State private var isPresented = false

    private var hasNote: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "note.text")
                .overlay(alignment: .topTrailing) {
                    if hasNote {
                        Circle()
                            .fill(ThemeColor.resolve(accentColorRawValue).color)
                            .frame(width: 7, height: 7)
                            .offset(x: 5, y: -4)
                            .accessibilityHidden(true)
                    }
                }
        }
        .accessibilityLabel("Next Workout Note")
        .accessibilityValue(hasNote ? Text("Note saved") : Text(""))
        .accessibilityIdentifier("nextWorkoutNoteButton")
        .popover(isPresented: $isPresented, attachmentAnchor: .rect(.bounds)) {
            TextEditor(text: $note)
                .font(.body)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if note.isEmpty {
                        Text("Next Workout Note")
                            .foregroundStyle(.placeholder)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel("Next Workout Note")
                .accessibilityIdentifier("nextWorkoutNoteEditor")
                .frame(width: 296, height: 174)
                .padding(12)
                .presentationBackground(Color(uiColor: .systemBackground))
                .presentationCompactAdaptation(.popover)
        }
    }
}
