//
//  EditCostDetailSheet.swift
//  costa
//

import SwiftUI

struct EditCostDetailSheet: View {
    @Environment(AuthController.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: EditCostDetailViewModel
    /// Called with the server-updated `Cost` after a successful save, before the sheet dismisses.
    private let onSaved: ((Cost) -> Void)?

    init(
        cost: Cost,
        service: EditCostDetailServicing = LiveEditCostDetailService(),
        onSaved: ((Cost) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: EditCostDetailViewModel(cost: cost, service: service))
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: 0) {
            CostaDragHandle()
                .padding(.top, 8)
                .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    StyledTextField(
                        title: "Name",
                        placeholder: "e.g Groceries",
                        text: $viewModel.nameText
                    )

                    StyledTextField(
                        title: "Quantity",
                        placeholder: "1",
                        text: $viewModel.quantityText,
                        keyboardType: .decimalPad
                    )

                    StyledTextField(
                        title: "Unit Price",
                        placeholder: "e.g 20000",
                        text: $viewModel.unitPriceText,
                        leadingText: viewModel.cost.currency,
                        keyboardType: .decimalPad
                    )

                    Text("Total: \(viewModel.calculatedTotal, format: .currency(code: viewModel.cost.currency))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Category selector with add mode
                    if categoryOptions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Add at least one category to classify this line item.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                viewModel.isAddingCategory = true
                            } label: {
                                Text("Add category")
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        StyledSelectField(
                            title: "Category",
                            selection: $viewModel.selectedCategory,
                            options: categoryOptions,
                            optionLabel: { $0.name },
                            onAddNew: { viewModel.isAddingCategory = true }
                        )
                    }

                    // Error message
                    if let error = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }

            CostaActionButtons(
                cancelTitle: "Cancel",
                saveTitle: "Save",
                isSaveDisabled: viewModel.isLoading
                    || viewModel.nameText.trimmingCharacters(in: .whitespaces).isEmpty
                    || viewModel.selectedCategory.id == nil,
                cancelAction: { dismiss() },
                saveAction: { Task { await saveAndDismiss() } }
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                        .controlSize(.large)
                }
                .allowsHitTesting(true)
            }
        }
        .sheet(isPresented: $viewModel.isAddingCategory) {
            CategoryFormSheet(
                currency: viewModel.cost.currency,
                isSaving: viewModel.isLoading,
                onSave: { name, emoji, colorHex, _ in
                    // NOTE: budget-per-category isn't wired up yet — see
                    // CategoryFormSheet's doc comment. Only name/emoji/color
                    // are persisted here.
                    viewModel.newCategoryName = name
                    viewModel.newCategoryEmoji = emoji
                    viewModel.newCategoryColor = colorHex
                    Task {
                        guard let token = await auth.validToken() else {
                            viewModel.errorMessage = "Authentication failed."
                            return
                        }
                        await viewModel.addCategory(accessToken: token)
                    }
                }
            )
        }
        .task {
            guard let token = await auth.validToken() else { return }
            await viewModel.loadCategories(accessToken: token)
        }
    }

    /// Options for the Category dropdown: whatever `viewModel.categories`
    /// has loaded so far, PLUS the category already assigned to this item
    /// (if any) — so the dropdown shows up immediately with at least one
    /// valid option even before `loadCategories(accessToken:)` finishes,
    /// instead of briefly falling back to the "Add category" empty state
    /// just because the network call hadn't resolved yet.
    private var categoryOptions: [CostCategory] {
        var options = viewModel.categories
        let current = viewModel.selectedCategory
        if let id = current.id, !id.isEmpty, !options.contains(where: { $0.id == id }) {
            options.insert(current, at: 0)
        }
        return options
    }

    private func saveAndDismiss() async {
        guard let token = await auth.validToken() else {
            viewModel.errorMessage = "Authentication failed."
            return
        }

        do {
            try await viewModel.save(accessToken: token)
            onSaved?(viewModel.cost)
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Previews

#if DEBUG
enum EditCostDetailSheetPreviewData {
    static let sampleCost = Cost(
        id: "1",
        user_id: nil,
        name: "Venti Mocha Latte",
        amount: 50000,
        currency: "IDR",
        created_at: nil,
        updated_at: nil,
        category_id: "food",
        category: CostCategory(
            id: "food",
            emoji: "🍔",
            name: "Food",
            color: "#FF9500",
            is_generated_by_ai: false
        )
    )

    static let mockCategories: [CostCategory] = [
        CostCategory(id: "food", emoji: "🍔", name: "Food", color: "#FF9500", is_generated_by_ai: false),
        CostCategory(id: "t", emoji: "🚗", name: "Transport", color: nil, is_generated_by_ai: false),
        CostCategory(id: "u", emoji: "🏠", name: "Utilities", color: nil, is_generated_by_ai: false)
    ]

    static var mockService: MockEditCostDetailService {
        MockEditCostDetailService(
            categories: mockCategories,
            createCategoryResult: .success(
                CostCategory(
                    id: "new-cat",
                    emoji: "🆕",
                    name: "New category",
                    color: "#2d7ef7",
                    is_generated_by_ai: false
                )
            ),
            patchResult: .success(sampleCost)
        )
    }
}

/// Presents like a real sheet so Safe Area + detents match the app.
private struct EditCostDetailSheetPreviewHost: View {
    @State private var isPresented = true

    var body: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
            .sheet(isPresented: $isPresented) {
                EditCostDetailSheet(
                    cost: EditCostDetailSheetPreviewData.sampleCost,
                    service: EditCostDetailSheetPreviewData.mockService
                )
                .environment(AuthController.previewAuthenticated())
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
    }
}

#Preview("Edit cost (mock + sheet)") {
    assert(!EditCostDetailSheetPreviewData.mockCategories.isEmpty, "Preview: need categories for picker")
    assert(EditCostDetailSheetPreviewData.sampleCost.currency == "IDR", "Preview: currency mismatch")
    return EditCostDetailSheetPreviewHost()
}
#endif
