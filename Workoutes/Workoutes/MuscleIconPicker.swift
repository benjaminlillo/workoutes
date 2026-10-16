import SwiftUI

struct MuscleIconPicker: View {
    @Binding var selection: MuscleIcon?
    let color: Color

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button {
                    selection = nil
                } label: {
                    HStack {
                        Circle().fill(color).frame(width: 12, height: 12)
                        Text("No Icon")
                        Spacer()
                        if selection == nil { Image(systemName: "checkmark") }
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == nil ? .isSelected : [])
                .accessibilityIdentifier("muscleIcon.none")

                ForEach(MuscleIcon.Group.allCases) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.rawValue).font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 10)], spacing: 10) {
                            ForEach(MuscleIcon.allCases.filter { $0.group == group }) { icon in
                                iconButton(icon)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .defaultScreenBackground()
        .transparentNavigationChrome()
        .navigationTitle("Muscle Icon")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func iconButton(_ icon: MuscleIcon) -> some View {
        Button {
            selection = icon
        } label: {
            VStack(spacing: 8) {
                MuscleIconView(icon: icon, color: color)
                    .frame(width: 40, height: 40)
                Text(icon.name)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 90)
            .padding(6)
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(selection == icon ? color : ContainerBorderStyle.color,
                                  lineWidth: selection == icon ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(icon.name)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(selection == icon ? .isSelected : [])
        .accessibilityIdentifier("muscleIcon.\(icon.rawValue)")
    }
}
