//
//  AddExpenseOptionsSheet.swift
//  costa
//

import SwiftUI

/// Bottom sheet: ways to add an expense (matches HiFi design).
struct AddExpenseOptionsSheet: View {
    @Binding var isPresented: Bool
    var onSnapReceipt: () -> Void = {}
    var onUploadFromGallery: () -> Void = {}
    var onEnterManually: () -> Void = {}

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
                    icon: "camera.fill",
                    iconTint: snapReceiptTint,
                    title: "Snap Receipt",
                    subtitle: "Use your camera to quickly capture expense details."
                ) {
                    isPresented = false
                    onSnapReceipt()
                }

                sheetDivider

                optionRow(
                    icon: "photo.on.rectangle.angled",
                    iconTint: uploadGalleryTint,
                    title: "Upload from Gallery",
                    subtitle: "Add up to 1 receipt at once from your gallery."
                ) {
                    isPresented = false
                    onUploadFromGallery()
                }

                sheetDivider

                optionRow(
                    icon: "doc.badge.plus",
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
    }

    private var dragHandle: some View {
        Capsule()
            .fill(handleColor)
            .frame(width: 36, height: 5)
    }

    private var sheetDivider: some View {
        Divider()
            .overlay(dividerColor)
            .padding(.leading, 84)
    }

    private func optionRow(
        icon: String,
        iconTint: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddExpenseOptionsSheet(isPresented: .constant(true))
        .preferredColorScheme(.dark)
}
