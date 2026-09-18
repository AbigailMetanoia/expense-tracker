//
//  AddExpenseOptionsSheet.swift
//  costa
//

import SwiftUI
import PhotosUI

/// Bottom sheet: ways to add an expense (matches HiFi design).
struct AddExpenseOptionsSheet: View {
    @Binding var isPresented: Bool
    var onSnapReceipt: () -> Void = {}
    /// Called once the user has picked a single photo from their library.
    /// The image is handed up as-is (no cropping here) — the parent screen
    /// decides what to do with it, e.g. feed it into
    /// `ReceiptCaptureFlowView`'s Review phase the same way a camera scan
    /// would.
    var onUploadFromGallery: (UIImage) -> Void = { _ in }
    var onEnterManually: () -> Void = {}

    /// Gallery selection state lives here since `PhotosPicker` needs a
    /// binding; the loaded `UIImage` is handed off via `onUploadFromGallery`
    /// once decoding finishes.
    @State private var pickedGalleryItem: PhotosPickerItem?

    // MARK: - Costa color tokens (dark theme)
    // TODO: move these into Assets.xcassets as named colors so light/dark
    // variants can be swapped without touching this file.
    private let sheetBackground = Color(red: 0x08 / 255, green: 0x0B / 255, blue: 0x12 / 255)
    private let dividerColor = Color.white.opacity(0.08)
    private let handleColor = Color.white.opacity(0.25)

    private let snapReceiptTint = Color(red: 0x1C / 255, green: 0x4E / 255, blue: 0x80 / 255)   // deep blue
    private let uploadGalleryTint = Color(red: 0x8A / 255, green: 0x61 / 255, blue: 0x16 / 255)  // amber/gold
    private let enterManuallyTint = Color(red: 0x1F / 255, green: 0x7A / 255, blue: 0x3D / 255)  // green

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
                .padding(.top, 8)
                .padding(.bottom, 20)

            VStack(spacing: 0) {
                optionRow(
//                    icon: "camera.fill",
                    icon: "📸",
                    iconTint: snapReceiptTint,
                    title: "Snap Receipt",
                    subtitle: "Use your camera to quickly capture expense details."
                ) {
                    isPresented = false
                    onSnapReceipt()
                }

                sheetDivider

                PhotosPicker(selection: $pickedGalleryItem, matching: .images) {
                    optionRowLabel(
//                        icon: "photo.on.rectangle.angled",
                        icon: "🖼️",
                        iconTint: uploadGalleryTint,
                        title: "Upload from Gallery",
                        subtitle: "Add up to 1 receipt at once from your gallery."
                    )
                }
                .buttonStyle(.plain)

                sheetDivider

                optionRow(
//                    icon: "doc.badge.plus",
                    icon: "🧾",
                    iconTint: enterManuallyTint,

                    title: "Enter Manually",
                    subtitle: "Manually input your transaction details."
                ) {
                    isPresented = false
                    onEnterManually()
                }
            }
            .padding(.horizontal, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(sheetBackground)
        // On iOS 26+, swap this for the real Liquid Glass material, e.g.
        // .background(.clear) and apply `.glassEffect(.regular)` at the
        // presenting view's `.sheet(...)` call, since sheets are one of the
        // surfaces Apple's HIG allows glass on (alongside tab bars, toolbars,
        // and floating buttons). `.regularMaterial` below is the safe
        // pre-26 fallback so the sheet still reads as translucent chrome.
        .background(.regularMaterial)
        .onChange(of: pickedGalleryItem) { _, newItem in
            guard let newItem else { return }
            Task {
                defer { pickedGalleryItem = nil }
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                isPresented = false
                onUploadFromGallery(image)
            }
        }
    }

    private var dragHandle: some View {
        Capsule()
            .fill(handleColor)
            .frame(width: 36, height: 5)
    }

    private var sheetDivider: some View {
        Divider()
            .overlay(dividerColor)
            .padding(.leading, 10)
    }

    /// The row's visual content only, no `Button` wrapper. Used both by
    /// `optionRow(...)` (plain tap → action closure) and directly inside
    /// `PhotosPicker`'s label (tap → system photo picker), so Snap Receipt,
    /// Upload from Gallery, and Enter Manually all look identical.
    private func optionRowLabel(
        icon: String,
        iconTint: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
//            Image(systemName: icon)
//                .font(.system(size: 17, weight: .medium))
//                .foregroundStyle(.white)
//                .frame(width: 49, height: 49)
//                .background(Circle().fill(iconTint))
            Text(icon)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 49, height: 49)
                .background(Circle().fill(iconTint))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }

    private func optionRow(
        icon: String,
        iconTint: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            optionRowLabel(icon: icon, iconTint: iconTint, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddExpenseOptionsSheet(
        isPresented: .constant(true),
        onUploadFromGallery: { image in
            print("Picked image: \(image.size)")
        }
    )
    .preferredColorScheme(.dark)
}
