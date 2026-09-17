//
//  BudgetAmountSheet.swift
//  costa
//
//  Sets (or edits) the monthly budget limit for one EXISTING category.
//  Unlike CategoryFormSheet, this never creates or renames a category —
//  it only changes `budgetLimit`, so the category id here always matches
//  the id used on real Cost records.
//

import SwiftUI

struct BudgetAmountSheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: CostCategory
    let currency: String
    @State private var amountText: String

    let onSave: (Double) -> Void

    init(
        category: CostCategory,
        initialAmount: Double = 0,
        currency: String = "IDR",
        onSave: @escaping (Double) -> Void
    ) {
        self.category = category
        self.currency = currency
        self.onSave = onSave
        _amountText = State(initialValue: initialAmount > 0
            ? (initialAmount.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(initialAmount)) : String(initialAmount))
            : "")
    }

    private var isSaveDisabled: Bool {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            CostaDragHandle()
                .padding(.top, 8)
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((Color(hex: category.color ?? "") ?? .blue).opacity(0.2))
                            .frame(width: 44, height: 44)
                        Text(category.emoji)
                            .font(.title3)
                    }
                    Text(category.name)
                        .font(.title3.weight(.semibold))
                    Spacer()
                }

                StyledTextField(
                    title: "Monthly Budget",
                    placeholder: "e.g 500000",
                    text: $amountText,
                    leadingText: currency,
                    keyboardType: .decimalPad
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            CostaActionButtons(
                cancelTitle: "Cancel",
                saveTitle: "Save",
                isSaveDisabled: isSaveDisabled,
                cancelAction: { dismiss() },
                saveAction: {
                    let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    onSave(amount)
                    dismiss()
                }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview("Add") {
    Color(.systemBackground)
        .sheet(isPresented: .constant(true)) {
            BudgetAmountSheet(
                category: CostCategory(id: "1", emoji: "🛍️", name: "Groceries", color: "#2E7D32", is_generated_by_ai: false)
            ) { amount in
                print("Saved amount: \(amount)")
            }
        }
}

#Preview("Edit") {
    Color(.systemBackground)
        .sheet(isPresented: .constant(true)) {
            BudgetAmountSheet(
                category: CostCategory(id: "1", emoji: "🛍️", name: "Groceries", color: "#2E7D32", is_generated_by_ai: false),
                initialAmount: 170_000
            ) { amount in
                print("Saved amount: \(amount)")
            }
        }
}
