//
//  TotalCostView.swift
//  costa
//
//  Read-only breakdown of total cost per category for a given period
//  (e.g. "This Month"). Reuses `BudgetPocket` since the data shape
//  (name + icon + amount) is identical to what BudgetPocketsView needs.
//

import SwiftUI

struct TotalCostView: View {
    @Environment(\.dismiss) private var dismiss

    let periodLabel: String
    let items: [BudgetPocket]
    let currency: String
    /// Called when a row is tapped — e.g. to push `PocketDetailsView` for
    /// that category. Rows render as plain (non-interactive) text if nil.
    var onSelect: ((BudgetPocket) -> Void)?

    init(
        periodLabel: String = "This Month",
        items: [BudgetPocket],
        currency: String = "IDR",
        onSelect: ((BudgetPocket) -> Void)? = nil
    ) {
        self.periodLabel = periodLabel
        self.items = items
        self.currency = currency
        self.onSelect = onSelect
    }

    var body: some View {
        ZStack {
            CostaAuroraBackground(glowCenter: UnitPoint(x: 0.5, y: 0.05), glowColor: .blue)

            VStack(spacing: 0) {
                header
                VStack{
                    Text(periodLabel)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 10)
//                        .padding(.bottom, 16)

                    ScrollView {
                        if items.isEmpty {
                            Text("No costs recorded for this period.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.top, 40)
                        } else {
                            listCard
                                .padding(.horizontal, 20)
                        }
                    }
                }

            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)

            Text("Total Cost")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - List

    private var listCard: some View {
        VStack(spacing: 15) {
            ForEach(items) { item in
                row(item)
            }
        }
    }

    private func row(_ item: BudgetPocket) -> some View {
        Button {
            onSelect?(item)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill((Color(hex: item.category.color ?? "") ?? .blue).opacity(0.3))
                        .frame(width: 44, height: 44)
                    Text(item.category.emoji)
                        .font(.title3)
                }

                Text(item.category.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)

                Spacer()

                Text("Rp. " + formatted(item.amount))
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(16)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onSelect == nil)
    }

    // MARK: - Formatting

    private func formatted(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "id_ID")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

#Preview {
    NavigationStack {
        TotalCostView(
            items: [
                BudgetPocket(id: "1", category: CostCategory(id: "1", emoji: "🏠", name: "House", color: "#2E7D32", is_generated_by_ai: false), amount: 900_000),
                BudgetPocket(id: "2", category: CostCategory(id: "2", emoji: "🏠", name: "House", color: "#2E7D32", is_generated_by_ai: false), amount: 900_000),
                BudgetPocket(id: "3", category: CostCategory(id: "3", emoji: "🏠", name: "House", color: "#2E7D32", is_generated_by_ai: false), amount: 900_000),
                BudgetPocket(id: "4", category: CostCategory(id: "4", emoji: "🏠", name: "House", color: "#2E7D32", is_generated_by_ai: false), amount: 900_000)
            ]
        ) { pocket in
            print("Tapped: \(pocket.category.name)")
        }
    }
}
