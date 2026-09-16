//
//  BudgetPocketsView.swift
//  costa
//
//  Grid of per-category budget "pockets". Tapping a pocket opens
//  CategoryFormSheet in edit mode (pre-filled); "Add Budget Pocket" opens
//  the same sheet in add mode. Persisting to the backend is left to the
//  caller via `onSave`, same pattern as the other sheets in this app.
//

import SwiftUI

/// A category paired with the amount budgeted for it. This is a local
/// display model — `CostCategory` itself doesn't carry a budget amount
/// yet (see the NOTE on `CategoryFormSheet`'s `budget` parameter).
struct BudgetPocket: Identifiable {
    var id: String
    var category: CostCategory
    var amount: Double
    /// The budget target for this pocket, used for the progress bar on
    /// WalletView's pocket cards ("X left" = budgetLimit - amount).
    /// Defaults to 0 (no progress shown) for call sites that only care
    /// about `amount` (BudgetPocketsView, TotalCostView).
    var budgetLimit: Double = 0
}

struct BudgetPocketsView: View {
    @Environment(\.dismiss) private var dismiss

    private enum ActiveSheet: Identifiable {
        case add
        case edit(BudgetPocket)

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let pocket): "edit-\(pocket.id)"
            }
        }
    }

    @State private var pockets: [BudgetPocket]
    @State private var activeSheet: ActiveSheet?

    let currency: String
    let onSave: (BudgetPocket) -> Void

    init(
        pockets: [BudgetPocket] = [],
        currency: String = "IDR",
        onSave: @escaping (BudgetPocket) -> Void
    ) {
        _pockets = State(initialValue: pockets)
        self.currency = currency
        self.onSave = onSave
    }

    private var totalAmount: Double {
        pockets.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ZStack {
            CostaAuroraBackground(glowCenter: UnitPoint(x: 0.5, y: 0.05), glowColor: .blue)

            VStack(spacing: 0) {
                header

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())],
                        spacing: 14
                    ) {
                        ForEach(pockets) { pocket in
                            Button {
                                activeSheet = .edit(pocket)
                            } label: {
                                pocketCard(pocket)
                            }
                            .buttonStyle(.plain)
                        }

                        addPocketCard
                    }
                    .padding(20)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .add:
                CategoryFormSheet(currency: currency) { name, emoji, colorHex, budget in
                    let category = CostCategory(
                        id: UUID().uuidString,
                        emoji: emoji,
                        name: name,
                        color: colorHex,
                        is_generated_by_ai: false
                    )
                    let pocket = BudgetPocket(id: category.id ?? UUID().uuidString, category: category, amount: budget ?? 0)
                    pockets.append(pocket)
                    onSave(pocket)
                }

            case .edit(let pocket):
                CategoryFormSheet(
                    existing: pocket.category,
                    initialBudget: pocket.amount,
                    currency: currency
                ) { name, emoji, colorHex, budget in
                    guard let index = pockets.firstIndex(where: { $0.id == pocket.id }) else { return }
                    pockets[index].category.name = name
                    pockets[index].category.emoji = emoji
                    pockets[index].category.color = colorHex
                    if let budget { pockets[index].amount = budget }
                    onSave(pockets[index])
                }
            }
        }
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

            Text("Budget Pockets")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Pocket card

    private func pocketCard(_ pocket: BudgetPocket) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill((Color(hex: pocket.category.color ?? "") ?? .blue).opacity(0.25))
                    .frame(width: 44, height: 44)
                Text(pocket.category.emoji)
                    .font(.title3)
            }

            Text(pocket.category.name)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)

            Text(percentText(pocket))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            Text("Rp " + formatted(pocket.amount))
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Add pocket card

    private var addPocketCard: some View {
        Button {
            activeSheet = .add
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12), in: Circle())

                Text("Add Budget Pocket")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Formatting

    private func percentText(_ pocket: BudgetPocket) -> String {
        guard totalAmount > 0 else { return "0% of total" }
        let percent = (pocket.amount / totalAmount) * 100
        return String(format: "%.0f%% of total", percent)
    }

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
        BudgetPocketsView(
            pockets: [
                BudgetPocket(id: "1", category: CostCategory(id: "1", emoji: "🛍️", name: "Groceries", color: "#2E7D32", is_generated_by_ai: false), amount: 900_000),
                BudgetPocket(id: "2", category: CostCategory(id: "2", emoji: "🍔", name: "Groceries", color: "#C62828", is_generated_by_ai: false), amount: 900_000),
                BudgetPocket(id: "3", category: CostCategory(id: "3", emoji: "🛶", name: "Groceries", color: "#00796B", is_generated_by_ai: false), amount: 900_000),
                BudgetPocket(id: "4", category: CostCategory(id: "4", emoji: "🚒", name: "Groceries", color: "#1565C0", is_generated_by_ai: false), amount: 900_000)
            ]
        ) { pocket in
            print("Saved pocket: \(pocket)")
        }
    }
}
