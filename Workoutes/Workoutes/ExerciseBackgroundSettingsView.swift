import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct ExerciseBackgroundSettingsView: View {
    @Environment(ExerciseBackgroundStore.self) private var background
    @Environment(\.openURL) private var openURL
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var capturedPhoto: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCameraSettings = false

    var body: some View {
        Form {
            Section("Preview") {
                if let image = background.image {
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .frame(height: 240)
                    .accessibilityLabel("Current Exercises background")
                } else {
                    ContentUnavailableView("Default Background", systemImage: "photo", description: Text("Choose a photo for your Exercises tab."))
                }
            }

            Section {
                PhotosPicker(selection: $selectedPhoto, matching: .images, preferredItemEncoding: .compatible) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                }
                Button {
                    Task { await openCamera() }
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                if isLoading {
                    ProgressView("Saving background…")
                }
            } footer: {
                Text(UIImagePickerController.isSourceTypeAvailable(.camera)
                     ? "The photo is saved on this device and fills the Exercises background."
                     : "The photo is saved on this device. Camera capture is unavailable on this device or simulator.")
            }
            .disabled(isLoading)

            if background.image != nil {
                Section {
                    Button("Remove Background", role: .destructive) {
                        do { try background.remove() }
                        catch { errorMessage = error.localizedDescription }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .navigationTitle("Exercises Background")
        .navigationBarTitleDisplayMode(.inline)
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
        .alert("Exercises Background", isPresented: Binding(
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
