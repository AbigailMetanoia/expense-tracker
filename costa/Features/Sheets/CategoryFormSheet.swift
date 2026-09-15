//
//  CategoryFormSheet.swift
//  costa
//
//  Reusable Add/Edit form for a category. Pass `existing: nil` to create a
//  new category, or an existing `CostCategory` to edit one. This sheet
//  only manages the local draft — it doesn't call the network itself, so
//  callers can wire it to either a "create" or "update" endpoint as
//  appropriate for their context.
//
//  Usage:
//      .sheet(isPresented: $isAddingCategory) {
//          CategoryFormSheet(currency: "IDR") { name, emoji, colorHex, budget in
//              // create or patch a CostCategory with these values
//          }
//      }
//

import SwiftUI

struct CategoryFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var emoji: String
    @State private var colorHex: String
    @State private var budgetText: String

    let currency: String
    var isSaving: Bool

    /// `budget` is `nil` if the Amount field was left empty.
    let onSave: (_ name: String, _ emoji: String, _ colorHex: String, _ budget: Double?) -> Void

    init(
        existing: CostCategory? = nil,
        initialBudget: Double? = nil,
        currency: String = "IDR",
        isSaving: Bool = false,
        onSave: @escaping (_ name: String, _ emoji: String, _ colorHex: String, _ budget: Double?) -> Void
    ) {
        _name = State(initialValue: existing?.name ?? "")
        _emoji = State(initialValue: existing?.emoji ?? "")
        _colorHex = State(initialValue: existing?.color ?? "#FF3B77")
        _budgetText = State(initialValue: initialBudget.map {
            $0.truncatingRemainder(dividingBy: 1) == 0 ? String(Int($0)) : String($0)
        } ?? "")
        self.currency = currency
        self.isSaving = isSaving
        self.onSave = onSave
    }

    private var previewColor: Color {
        Color(hex: colorHex) ?? .pink
    }

    var body: some View {
        VStack(spacing: 0) {
            CostaDragHandle()
                .padding(.top, 8)
                .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    StyledTextField(
                        title: "Category Name",
                        placeholder: "e.g Groceries",
                        text: $name
                    )

                    StyledTextField(
                        title: "Amount",
                        placeholder: "e.g 20000",
                        text: $budgetText,
                        leadingText: currency,
                        keyboardType: .decimalPad
                    )

                    StyledTextField(
                        title: "Emoji",
                        placeholder: "e.g. 🛍️",
                        text: $emoji
                    )

                    colorSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }

            CostaActionButtons(
                cancelTitle: "Cancel",
                saveTitle: "Save",
                isSaveDisabled: isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty,
                cancelAction: { dismiss() },
                saveAction: {
                    let budget = Double(budgetText.replacingOccurrences(of: ",", with: "."))
                    onSave(name, emoji, colorHex, budget)
                    dismiss()
                }
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Color section

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)

            HStack(spacing: 16) {
                // The ColorPicker itself is the visible circle — its
                // default look already renders as a color swatch. Putting
                // the pencil icon in an `.overlay` (with hit testing
                // disabled) means taps always land on the real control,
                // instead of relying on an invisible layer on top of it.
                ColorPicker(
                    "",
                    selection: Binding(
                        get: { previewColor },
                        set: { newColor in
                            if let hex = newColor.toHex() { colorHex = hex }
                        }
                    )
                )
                .labelsHidden()
                .scaleEffect(1.7)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .allowsHitTesting(false)
                )
                .accessibilityLabel("Choose custom color")

                // Live preview combining the chosen color and emoji, so the
                // user sees roughly how the category chip will look.
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(previewColor.opacity(0.85))
                        .frame(width: 48, height: 48)

                    Text(emoji.isEmpty ? "🙂" : emoji)
                        .font(.caption)
                        .padding(4)
                        .background(Circle().fill(Color(uiColor: .systemBackground)))
                        .offset(x: 4, y: 4)
                }
                .accessibilityLabel("Preview")
            }
        }
    }
}

#Preview("Add") {
    Color(.systemBackground)
        .sheet(isPresented: .constant(true)) {
            CategoryFormSheet(currency: "IDR") { _, _, _, _ in }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
}

#Preview("Edit") {
    Color(.systemBackground)
        .sheet(isPresented: .constant(true)) {
            CategoryFormSheet(
                existing: CostCategory(id: "food", emoji: "🍔", name: "Food", color: "#FF9500", is_generated_by_ai: false),
                initialBudget: 500_000,
                currency: "IDR"
            ) { _, _, _, _ in }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
}
