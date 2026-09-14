import SwiftUI
import PhotosUI
import AVFoundation

/// §10.6 item 1: the photo section at the top of `MealEditorView`'s form.
/// Edits `draft.photo`/`draft.thumbnail` in place via `ImageProcessor`.
struct MealEditorPhotoSection: View {
    @Binding var photo: Data?
    @Binding var thumbnail: Data?
    var mealName: String

    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showingPhotosPicker = false
    @State private var showingCamera = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingCameraPermissionAlert = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var photoAccessibilityLabel: String {
        mealName.isEmpty ? "Meal photo" : "Photo of \(mealName)"
    }

    var body: some View {
        Section {
            ZStack {
                if let photo, let uiImage = UIImage(data: photo) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel(photoAccessibilityLabel)
                } else {
                    photoMenu {
                        VStack(spacing: 8) {
                            Image(systemName: "camera")
                                .font(.largeTitle)
                                .accessibilityHidden(true)
                            Text("Add Photo")
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 160)
                        .background(Color(.secondarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                if isProcessing {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.35))
                        .overlay(ProgressView().tint(.white))
                }
            }
            .frame(height: 200)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)

            if photo != nil {
                photoMenu {
                    Text("Change Photo")
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(
                onCapture: { data in
                    showingCamera = false
                    process(data)
                },
                onCancel: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingPhotosPicker, selection: $photosPickerItem, matching: .images)
        .onChange(of: photosPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    process(data)
                } else {
                    errorMessage = "That photo couldn't be used. Please try another."
                }
                photosPickerItem = nil
            }
        }
        .alert("Camera Access Is Off", isPresented: $showingCameraPermissionAlert) {
            Button("Open Settings") { openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Turn on camera access in Settings to take a photo.")
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func photoMenu<Content: View>(@ViewBuilder label: () -> Content) -> some View {
        Menu {
            if cameraAvailable {
                Button {
                    requestCameraAccess()
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }
            Button {
                showingPhotosPicker = true
            } label: {
                Label("Choose from Library", systemImage: "photo")
            }
            if photo != nil {
                Button(role: .destructive) {
                    photo = nil
                    thumbnail = nil
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                }
            }
        } label: {
            label()
        }
        .buttonStyle(.plain)
    }

    private func requestCameraAccess() {
        if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
            showingCameraPermissionAlert = true
        } else {
            showingCamera = true
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func process(_ data: Data) {
        isProcessing = true
        Task {
            do {
                let prepared = try await ImageProcessor.prepare(data)
                photo = prepared.photo
                thumbnail = prepared.thumbnail
            } catch {
                errorMessage = "That photo couldn't be used. Please try another."
            }
            isProcessing = false
        }
    }
}

#Preview {
    Form {
        MealEditorPhotoSection(photo: .constant(nil), thumbnail: .constant(nil), mealName: "Chicken fajitas")
    }
}
