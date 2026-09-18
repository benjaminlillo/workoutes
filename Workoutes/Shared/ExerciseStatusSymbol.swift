import SwiftUI

struct ExerciseStatusSymbol: View {
    let status: ExerciseStatus
    let accentColor: Color

    var body: some View {
        ZStack {
            Circle().fill(status == .done ? accentColor : .clear)
            Circle().strokeBorder(status == .empty ? .gray : accentColor, lineWidth: 2)
            if status == .done {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            } else if status == .playing {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
        }
        .frame(width: 28, height: 28)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
}
