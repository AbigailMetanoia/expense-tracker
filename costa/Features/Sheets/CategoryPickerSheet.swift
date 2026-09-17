//
//  CategoryPickerSheet.swift
//  costa
//
//  Lets the user attach a budget to an EXISTING category, instead of
//  BudgetPocketsView fabricating a brand-new (mismatched) category.
//

import SwiftUI

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let categories: [CostCategory]
    let onSelect: (CostCategory) -> Void

    var body: some View {
        VStack(spacing: 0) {
            CostaDragHandle()
                .padding(.top, 8)
                .padding(.bottom, 12)

            Text("Choose a Category")
                .font(.headline)
                .padding(.bottom, 12)

            if categories.isEmpty {
                Spacer()
                Text("All your categories already have a budget pocket.\nCreate a new category first when adding an expense.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            } else {
                List(categories, id: \.id) { category in
                    Button {
                        onSelect(category)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill((Color(hex: category.color ?? "") ?? .blue).opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Text(category.emoji)
                                    .font(.title3)
                            }
                            Text(category.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    Color(.systemBackground)
        .sheet(isPresented: .constant(true)) {
            CategoryPickerSheet(categories: [
                CostCategory(id: "1", emoji: "🛍️", name: "Groceries", color: "#2E7D32", is_generated_by_ai: false),
                CostCategory(id: "2", emoji: "🍔", name: "Dining", color: "#C62828", is_generated_by_ai: false)
            ]) { category in
                print("Picked: \(category.name)")
            }
        }
}
