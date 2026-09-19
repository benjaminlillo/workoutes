import SwiftUI

struct SessionToolbarButton: View {
    @Environment(SessionController.self) private var session
    @State private var confirmingStop = false

    var body: some View {
        Button {
            if session.isActive { confirmingStop = true }
            else { session.start() }
        } label: {
            Image(systemName: "figure.run")
                .symbolEffect(
                    .wiggle.forward.byLayer,
                    options: .repeat(.continuous),
                    isActive: session.isActive
                )
                .foregroundStyle(session.isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        }
        .accessibilityLabel(session.isActive ? "Stop Session" : "Start Session")
        .confirmationDialog("Stop this session?", isPresented: $confirmingStop, titleVisibility: .visible) {
            Button("Stop and Save", role: .destructive) { session.requestStop() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The time recorded so far will be saved in History.")
        }
    }
}
