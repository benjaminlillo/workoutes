import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct BackgroundCustomizationSheet: View {
    private enum BackgroundMode: String, CaseIterable {
        case wallpaper = "Wallpaper"
        case gradient = "Gradient"
        case automatic = "Automatic"
    }

    let background: ExerciseBackgroundStore
    let title: String
    let tagColors: [String]
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var colors: [String] = ExerciseBackgroundStore.defaultGradientColors
    @Environment(\.openURL) private var openURL
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var capturedPhoto: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCameraSettings = false
    @State private var mode: BackgroundMode

    private var displayedColors: [String] {
        colors == ExerciseBackgroundStore.defaultGradientColors
            ? ThemeColor.resolve(accentColorRawValue).defaultGradientColors : colors
    }

    init(background: ExerciseBackgroundStore, title: String, tagColors: [String] = []) {
        self.background = background
        self.title = title
        self.tagColors = tagColors
        _mode = State(initialValue: background.usesAutomaticGradient ? .automatic
                        : (background.gradientColors.isEmpty && background.image != nil ? .wallpaper : .gradient))
        _colors = State(initialValue: background.gradientColors.isEmpty
                        ? ExerciseBackgroundStore.defaultGradientColors : background.gradientColors)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Background Type", selection: $mode) {
                        ForEach(BackgroundMode.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isLoading)
                    .subtleFormRowBorder()
                }

                Section("Preview") {
                    preview
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .subtleFormRowBorder()
                }

                if mode == .wallpaper {
                    Section {
                        PhotosPicker(selection: $selectedPhoto, matching: .images, preferredItemEncoding: .compatible) {
                            Label("Choose from Photos", systemImage: "photo.on.rectangle")
                        }
                        .subtleFormRowBorder(.first)
                        Button {
                            Task { await openCamera() }
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                        .subtleFormRowBorder(isLoading ? .middle : .last)
                        if isLoading {
                            ProgressView("Saving background…")
                                .subtleFormRowBorder(.last)
                        }
                    } footer: {
                        Text(UIImagePickerController.isSourceTypeAvailable(.camera)
                             ? "The photo applies only to this screen."
                             : "The photo is saved on this device. Camera capture is unavailable on this device or simulator.")
                    }
                    .disabled(isLoading)
                } else if mode == .gradient {

                    Section {
                        ForEach(displayedColors.indices, id: \.self) { index in
                            HStack {
                                ColorPicker("Color \(index + 1)", selection: Binding(
                                    get: { Color(hex: displayedColors.indices.contains(index) ? displayedColors[index] : "FFFFFF") },
                                    set: { if displayedColors.indices.contains(index) {
                                        var edited = displayedColors
                                        edited[index] = $0.toHex()
                                        colors = edited
                                    } }
                                ), supportsOpacity: false)
                                if colors.count > 1 {
                                    Button(role: .destructive) {
                                        var edited = displayedColors
                                        edited.remove(at: index)
                                        colors = edited
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Remove color \(index + 1)")
                                }
                            }
                            .subtleFormRowBorder(.row(at: index, count: colors.count + (colors.count < 3 ? 1 : 0)))
                        }
                        if colors.count < 3 {
                            Button("Add Color", systemImage: "plus") { colors = displayedColors + ["F4D8BD"] }
                                .subtleFormRowBorder(.last)
                        }
                    } header: {
                        Text("Soft Gradient")
                    } footer: {
                        Text("Choose up to three colors. A soft white overlay keeps the background subtle.")
                        if colors == ExerciseBackgroundStore.defaultGradientColors {
                            Text("The default gradient follows your accent color. Editing these colors customizes only this screen.")
                        }
                    }
                    .disabled(isLoading)
                } else {
                    Section {
                        Text("The gradient follows the colors of the selected tags. Without tags, it uses the default gradient.")
                            .foregroundStyle(.secondary)
                            .subtleFormRowBorder()
                    }
                }

                if background.usesAutomaticGradient || background.image != nil || background.gradientColors != ExerciseBackgroundStore.defaultGradientColors {
                    Section {
                        Button("Reset Background", role: .destructive) {
                            do {
                                try background.remove()
                                colors = ExerciseBackgroundStore.defaultGradientColors
                                mode = .gradient
                            }
                            catch { errorMessage = error.localizedDescription }
                        }
                        .disabled(isLoading)
                        .subtleFormRowBorder()
                    }
                }
            }
            .transparentNavigationChrome()
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: mode) { _, selectedMode in
                do {
                    if selectedMode == .automatic {
                        try background.setAutomaticGradient()
                    } else if selectedMode == .gradient {
                        try background.saveGradient(colors: colors)
                    } else {
                        try background.useWallpaper()
                    }
                } catch { errorMessage = error.localizedDescription }
            }
            .onChange(of: colors) { _, selectedColors in
                guard mode == .gradient else { return }
                do { try background.saveGradient(colors: selectedColors) }
                catch { errorMessage = error.localizedDescription }
            }
            .task(id: selectedPhoto) {
                guard let photo = selectedPhoto else { return }
                isLoading = true
                defer {
                    isLoading = false
                    selectedPhoto = nil
                }
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self) else {
                        throw ExerciseBackgroundStore.BackgroundError.invalidImage
                    }
                    try Task.checkCancellation()
                    try background.save(data: data)
                } catch is CancellationError {
                    // Leaving the screen doesn't replace the existing background.
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .fullScreenCover(isPresented: $showingCamera, onDismiss: saveCapturedPhoto) {
                BackgroundCameraPicker { image in
                    capturedPhoto = image
                    showingCamera = false
                }
                .ignoresSafeArea()
            }
            .alert("Background", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil; showCameraSettings = false } }
            )) {
                if showCameraSettings {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
                Button("OK", role: .cancel) { errorMessage = nil; showCameraSettings = false }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if mode == .automatic {
            if tagColors.isEmpty {
                DefaultScreenBackground()
            } else {
                SoftBackgroundGradient(colors: tagColors)
            }
        } else if mode == .gradient {
            if colors == ExerciseBackgroundStore.defaultGradientColors {
                DefaultScreenBackground()
            } else {
                SoftBackgroundGradient(colors: colors)
            }
        } else if let image = background.image {
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
        } else {
            ContentUnavailableView("Choose a Photo", systemImage: "photo")
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }

    private func saveCapturedPhoto() {
        guard let image = capturedPhoto else { return }
        defer { capturedPhoto = nil }
        do {
            guard let data = image.jpegData(compressionQuality: 0.9) else {
                throw ExerciseBackgroundStore.BackgroundError.invalidImage
            }
            try background.save(data: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        isLoading = true
        defer { isLoading = false }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let authorized: Bool
        if status == .notDetermined {
            authorized = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            authorized = status == .authorized
        }
        if authorized {
            showingCamera = true
        } else {
            showCameraSettings = AVCaptureDevice.authorizationStatus(for: .video) == .denied
            errorMessage = "Camera access is unavailable. You can choose a photo from your library or allow camera access in Settings."
        }
    }
}

private struct BackgroundCameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void
        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onFinish(nil) }
    }
}
