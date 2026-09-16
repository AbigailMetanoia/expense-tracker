//
//  TopSpendingView.swift
//  costa
//
//  "See All" destination from SpendingView's Top Spending section — same
//  category ranking, same row style (icon + name + amount), just the
//  full list instead of a capped preview.
//

import SwiftUI

struct TopSpendingView: View {
    @Environment(\.dismiss) private var dismiss

    /// Sorted highest-amount-first — same ranking logic as
    /// `SpendingView.categoryBreakdown`.
    let categories: [SpendingCategorySlice]
    var onSelect: ((SpendingCategorySlice) -> Void)?

    init(categories: [SpendingCategorySlice], onSelect: ((SpendingCategorySlice) -> Void)? = nil) {
        self.categories = categories.sorted { $0.amount > $1.amount }
        self.onSelect = onSelect
    }

    var body: some View {
        ZStack {
            CostaAuroraBackground(glowCenter: UnitPoint(x: 0.5, y: 0.05), glowColor: .blue)

            VStack(spacing: 0) {
                header

                ScrollView {
                    if categories.isEmpty {
                        Text("No spending recorded yet.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(categories) { item in
                                row(item)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
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

            Text("Top Spending")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom,10)
    }

    // MARK: - Row (matches SpendingView's topSpendingRow exactly)

    private func row(_ item: SpendingCategorySlice) -> some View {
        Button {
            onSelect?(item)
        } label: {
            StyledCategoryAmountRow(
                emoji: item.emoji,
                title: item.name,
                amountText: "Rp. " + formatted(item.amount)
            )
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
    TopSpendingView(
        categories: [
            SpendingCategorySlice(id: "food", name: "Food", emoji: "🍔", amount: 350_000, color: CostaColors.blueShades[0]),
            SpendingCategorySlice(id: "transport", name: "Transportation", emoji: "🚗", amount: 300_000, color: CostaColors.blueShades[1]),
            SpendingCategorySlice(id: "house", name: "House", emoji: "🏠", amount: 250_000, color: CostaColors.blueShades[2]),
            SpendingCategorySlice(id: "shopping", name: "Shopping", emoji: "🛍️", amount: 150_000, color: CostaColors.blueShades[3]),
            SpendingCategorySlice(id: "health", name: "Health", emoji: "💊", amount: 100_000, color: CostaColors.blueShades[4])
        ]
    ) { item in
        print("Tapped: \(item.name)")
    }
}
