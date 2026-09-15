//
//  ReceiptCaptureFlowView.swift
//  costa
//

import SwiftUI
import UIKit
import VisionKit

/// Full-screen receipt capture → upload → edit flow.
struct ReceiptCaptureFlowView: View {
    enum Phase {
        case capture
        case preview(UIImage)
        case uploading(UIImage)
        case edit(Expense, BillExtraction?, UIImage)
        case failed(String, UIImage)
    }

    @Environment(AuthController.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .capture
    @State private var captureKey = 0

    var body: some View {
        Group {
            switch phase {
            case .capture:
                capturePane
            case .preview(let image):
                receiptPreview(for: image)
            case .uploading(let image):
                uploadingView(for: image)
            case .edit(let expense, let extraction, let image):
                EditReceiptDetailsView(
                    expense: expense,
                    extraction: extraction,
                    thumbnail: image,
                    onRetake: {
                        phase = .capture
                        captureKey += 1
                    }
                )
            case .failed(let message, let image):
                failedView(message: message, image: image)
            }
        }
    }

    // MARK: - Capture pane

    @ViewBuilder
    private var capturePane: some View {
        if VNDocumentCameraViewController.isSupported {
            DocumentCameraRepresentable(
                onCapture: { image in phase = .preview(image) },
                onCancel: { dismiss() },
                onFail: { _ in dismiss() }
            )
            .ignoresSafeArea()
            .id(captureKey)
        } else if UIImagePickerController.isSourceTypeAvailable(.camera) {
            CameraImagePickerRepresentable(
                onCapture: { phase = .preview($0) },
                onCancel: { dismiss() }
            )
            .ignoresSafeArea()
            .id(captureKey)
        } else {
            NavigationStack {
                ContentUnavailableView(
                    "Camera Unavailable",
                    systemImage: "camera.fill",
                    description: Text("Receipt capture needs a camera. Try on a physical device.")
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Preview

    private func receiptPreview(for image: UIImage) -> some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button("Retake") {
                            phase = .capture
                            captureKey += 1
                        }
                        Spacer()
                        Button("Save") {
                            Task { await uploadImage(image) }
                        }
                        .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Uploading

    private func uploadingView(for image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .overlay(.ultraThinMaterial.opacity(0.65))
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                    .tint(.white)
                Text("Scanning receipt…")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Failed

    private func failedView(message: String, image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .overlay(.black.opacity(0.55))
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal)
                HStack(spacing: 16) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.2), in: Capsule())

                    Button("Retry") {
                        Task { await uploadImage(image) }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.35), in: Capsule())
                }
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Upload

    private func uploadImage(_ image: UIImage) async {
        guard let token = await auth.validToken() else {
            phase = .failed("You are not signed in.", image)
            return
        }

        guard var jpeg = image.jpegData(compressionQuality: 0.85) else {
            phase = .failed("Failed to prepare image.", image)
            return
        }

        let maxBytes = 12 * 1024 * 1024
        if jpeg.count > maxBytes {
            guard let smaller = image.jpegData(compressionQuality: 0.5),
                  smaller.count <= maxBytes else {
                phase = .failed("Image is too large (max 12 MB). Please retake.", image)
                return
            }
            jpeg = smaller
        }

        phase = .uploading(image)

        do {
            let client = CostAPIClient(accessToken: token)
            let response = try await client.fromBill(imageJPEG: jpeg)
            phase = .edit(response.expense, response.extraction, image)
        } catch {
            phase = .failed(error.localizedDescription, image)
        }
    }
}

// MARK: - VisionKit document camera

private struct DocumentCameraRepresentable: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void
    var onFail: (Error) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraRepresentable
        init(parent: DocumentCameraRepresentable) { self.parent = parent }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0 else { parent.onCancel(); return }
            parent.onCapture(scan.imageOfPage(at: 0))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.onFail(error)
        }
    }
}

// MARK: - UIImagePicker fallback

private struct CameraImagePickerRepresentable: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePickerRepresentable
        init(parent: CameraImagePickerRepresentable) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

#Preview {
    ReceiptCaptureFlowView()
        .environment(AuthController())
}
