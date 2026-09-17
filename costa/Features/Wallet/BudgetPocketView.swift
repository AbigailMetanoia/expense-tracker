//
//  BudgetPocketsView.swift
//  costa
//
//  Grid of per-category budget "pockets". Tapping a pocket opens
//  BudgetAmountSheet (pre-filled) to change its budget limit. "Add Budget
//  Pocket" attaches a budget to one of the user's EXISTING categories —
//  it never fabricates a new category with a random id, which is what
//  previously caused budgets to silently stop matching real costs.
//

import SwiftUI

/// A category paired with the amount budgeted for it. This is a local
/// display model — `CostCategory` itself doesn't carry a budget amount
/// yet (there's no budget endpoint in `CostAPIClient`).
struct BudgetPocket: Identifiable {
    var id: String
    var category: CostCategory
    /// Amount spent so far — always computed live from real costs by the
    /// caller (see `WalletView.spentAmount(for:)`); this view doesn't
    /// compute it itself since it has no access to cost data.
    var amount: Double
    /// The budget target for this pocket.
    var budgetLimit: Double = 0
}

struct BudgetPocketsView: View {
    @Environment(\.dismiss) private var dismiss

    private enum ActiveSheet: Identifiable {
        case pickCategory
        case setBudget(CostCategory, existingLimit: Double)
        case edit(BudgetPocket)

        var id: String {
            switch self {
            case .pickCategory: "pick"
            case .setBudget(let category, _): "set-\(category.id ?? category.name)"
            case .edit(let pocket): "edit-\(pocket.id)"
            }
        }
    }

    @State private var pockets: [BudgetPocket]
    @State private var activeSheet: ActiveSheet?

    /// All real categories in the workspace (from `listCategories()`),
    /// used to populate the "Add Budget Pocket" picker with categories
    /// that don't already have a pocket.
    let allCategories: [CostCategory]
    let currency: String
    let onSave: (BudgetPocket) -> Void

    init(
        pockets: [BudgetPocket] = [],
        allCategories: [CostCategory] = [],
        currency: String = "IDR",
        onSave: @escaping (BudgetPocket) -> Void
    ) {
        _pockets = State(initialValue: pockets)
        self.allCategories = allCategories
        self.currency = currency
        self.onSave = onSave
    }

    private var totalBudget: Double {
        pockets.reduce(0) { $0 + $1.budgetLimit }
    }

    private var availableCategories: [CostCategory] {
        allCategories.filter { category in
            !pockets.contains { $0.category.id == category.id }
        }
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
            case .pickCategory:
                CategoryPickerSheet(categories: availableCategories) { category in
                    activeSheet = nil
                    // Wait for the picker sheet to fully dismiss before
                    // presenting the budget-amount sheet — presenting both
                    // in the same tick causes SwiftUI's classic
                    // ghosted/overlapping-sheet glitch.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        activeSheet = .setBudget(category, existingLimit: 0)
                    }
                }

            case .setBudget(let category, let existingLimit):
                BudgetAmountSheet(category: category, initialAmount: existingLimit, currency: currency) { amount in
                    if let index = pockets.firstIndex(where: { $0.category.id == category.id }) {
                        pockets[index].budgetLimit = amount
                        onSave(pockets[index])
                    } else {
                        let pocket = BudgetPocket(
                            id: category.id ?? UUID().uuidString,
                            category: category,
                            amount: 0,
                            budgetLimit: amount
                        )
                        pockets.append(pocket)
                        onSave(pocket)
                    }
                }

            case .edit(let pocket):
                BudgetAmountSheet(category: pocket.category, initialAmount: pocket.budgetLimit, currency: currency) { amount in
                    guard let index = pockets.firstIndex(where: { $0.id == pocket.id }) else { return }
                    pockets[index].budgetLimit = amount
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

            Text("Rp " + formatted(pocket.budgetLimit))
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
            activeSheet = .pickCategory
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
        guard totalBudget > 0 else { return "0% of total" }
        let percent = (pocket.budgetLimit / totalBudget) * 100
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
        let categories = [
            CostCategory(id: "1", emoji: "🛍️", name: "Groceries", color: "#2E7D32", is_generated_by_ai: false),
            CostCategory(id: "2", emoji: "🍔", name: "Dining", color: "#C62828", is_generated_by_ai: false),
            CostCategory(id: "3", emoji: "🚌", name: "Transport", color: "#00796B", is_generated_by_ai: false)
        ]
        BudgetPocketsView(
            pockets: [BudgetPocket(id: "1", category: categories[0], amount: 0, budgetLimit: 900_000)],
            allCategories: categories
        ) { pocket in
            print("Saved pocket: \(pocket)")
        }
    }
}
