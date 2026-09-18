//
//  ReceiptCaptureFlowView.swift
//  costa
//
//  Full-screen receipt capture flow:
//  1. Capture  — live camera
//  2. Review   — captured photo, with an adjustable crop frame ONLY when
//                the source didn't already do edge detection (see
//                `Phase.review`'s `needsCrop` below)
//  3. Uploading
//  4a. Low confidence — extraction found no line items; Cancel exits to
//      Home, Retake goes back to the camera.
//  4b. Edit    — EditReceiptDetailsView, when extraction looks good.
//  (Failed — a genuine network/auth error, separate from "low confidence".)
//

import SwiftUI
import UIKit
import VisionKit

struct ReceiptCaptureFlowView: View {
    enum Phase {
        case capture
        /// `needsCrop` distinguishes sources that already did their own
        /// edge detection/perspective correction (VisionKit's document
        /// scanner) from sources that didn't (the `UIImagePicker` camera
        /// fallback, and gallery uploads) — see `reviewPane`.
        case review(UIImage, needsCrop: Bool)
        case uploading(UIImage)
        case edit(Expense, BillExtraction?, UIImage)
        case lowConfidence(UIImage)
        case failed(String, UIImage)
    }

    @Environment(AuthController.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase
    @State private var captureKey = 0
    @State private var cropRect: CGRect = .zero

    init(initialPhase: Phase = .capture) {
        _phase = State(initialValue: initialPhase)
    }

    var body: some View {
        Group {
            switch phase {
            case .capture:
                capturePane
            case .review(let image, let needsCrop):
                reviewPane(for: image, needsCrop: needsCrop)
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
            case .lowConfidence(let image):
                lowConfidenceView(image: image)
            case .failed(let message, let image):
                failedView(message: message, image: image)
            }
        }
    }

    // MARK: - 1. Capture pane

    @ViewBuilder
    private var capturePane: some View {
        if VNDocumentCameraViewController.isSupported {
            DocumentCameraRepresentable(
                // VisionKit already detected the document's edges and
                // corrected perspective before handing us this image, so
                // skip the manual crop step entirely.
                onCapture: { image in phase = .review(image, needsCrop: false) },
                onCancel: { dismiss() },
                onFail: { _ in dismiss() }
            )
            .ignoresSafeArea()
            .id(captureKey)
        } else if UIImagePickerController.isSourceTypeAvailable(.camera) {
            CameraImagePickerRepresentable(
                // Plain camera capture, no edge detection happened — the
                // user may still want to crop out background/hands/etc.
                onCapture: { phase = .review($0, needsCrop: true) },
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

    // MARK: - 2. Review pane
    //
    // With `needsCrop == false` (VisionKit source) this is just the photo
    // plus Retake/Confirm — no frame, matching what the user asked for.
    // With `needsCrop == true` (fallback camera, or a gallery upload) the
    // adjustable `ReceiptCropOverlay` is shown so the user can frame the
    // receipt themselves before it's sent off for extraction.

    private func reviewPane(for image: UIImage, needsCrop: Bool) -> some View {
        GeometryReader { geo in
            let containerSize = geo.size

            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: containerSize.width, height: containerSize.height)

                if needsCrop {
                    ReceiptCropOverlay(rect: $cropRect, containerSize: containerSize)
                }

                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.black.opacity(0.4), in: Circle())
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8)

                        Spacer()
                    }

                    Spacer()

                    HStack {
                        Button {
                            phase = .capture
                            captureKey += 1
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(.black.opacity(0.4), in: Circle())
                        }
                        .accessibilityLabel("Retake")

                        Spacer()

                        Button {
                            let output = needsCrop
                                ? image.cropped(toDisplayRect: cropRect, inContainer: containerSize)
                                : image
                            Task { await uploadImage(output) }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue, in: Circle())
                        }
                        .accessibilityLabel("Confirm")
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .onAppear {
                guard needsCrop else { return }
                // Start the crop frame inset ~8% from each edge — a
                // reasonable default that the user can drag from there.
                let inset = min(containerSize.width, containerSize.height) * 0.08
                cropRect = CGRect(
                    x: inset,
                    y: inset,
                    width: containerSize.width - inset * 2,
                    height: containerSize.height - inset * 2
                )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - 3. Uploading

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

    // MARK: - 4a. Low confidence warning

    private func lowConfidenceView(image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .overlay(.black.opacity(0.55))

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)

                Text("Try Again")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Could not extract price line items from this image. Try a clearer photo.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 12) {
                    Button {
                        dismiss() // back to Home
                    } label: {
                        Text("Cancel")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        phase = .capture // back to Camera
                        captureKey += 1
                    } label: {
                        Text("Retake")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(Color(red: 0.11, green: 0.11, blue: 0.13), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Failed (genuine technical error, not a confidence issue)

    private func failedView(message: String, image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .overlay(.black.opacity(0.55))
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)
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

            // NOTE: this treats "no line items extracted" as the low-
            // confidence signal, since that's the one thing we know is
            // reliably present on the response. If/when the backend adds
            // a real confidence score to `BillExtraction`, swap this for
            // e.g. `(response.extraction?.confidence ?? 0) < 0.7`.
            if response.expense.costs.isEmpty {
                phase = .lowConfidence(image)
            } else {
                phase = .edit(response.expense, response.extraction, image)
            }
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

#Preview("Capture") {
    ReceiptCaptureFlowView()
        .environment(AuthController())
}

#Preview("Review — no crop (VisionKit)") {
    ReceiptCaptureFlowView(initialPhase: .review(previewReceiptPlaceholder(), needsCrop: false))
        .environment(AuthController())
}

#Preview("Review — with crop (fallback/gallery)") {
    ReceiptCaptureFlowView(initialPhase: .review(previewReceiptPlaceholder(), needsCrop: true))
        .environment(AuthController())
}

#Preview("Low confidence") {
    ReceiptCaptureFlowView(initialPhase: .lowConfidence(previewReceiptPlaceholder()))
        .environment(AuthController())
}

/// A plain dark placeholder image, just so preview-only phases (like the
/// low-confidence warning) have something to show behind the alert
/// without needing a real captured receipt.
private func previewReceiptPlaceholder() -> UIImage {
    let size = CGSize(width: 400, height: 800)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
        UIColor(white: 0.2, alpha: 1).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
    }
}
