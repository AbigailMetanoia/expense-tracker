//
//  WalletView.swift
//  costa
//

import SwiftUI

struct WalletView: View {
    enum Period: String, CaseIterable, Hashable {
        case thisWeek, thisMonth, thisYear

        var label: String {
            switch self {
            case .thisWeek: "This Week"
            case .thisMonth: "This Month"
            case .thisYear: "This Year"
            }
        }

        var cutoffDate: Date {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            switch self {
            case .thisWeek: return calendar.date(byAdding: .day, value: -6, to: today)!
            case .thisMonth: return calendar.date(byAdding: .day, value: -29, to: today)!
            case .thisYear: return calendar.date(byAdding: .day, value: -364, to: today)!
            }
        }
    }

    @Environment(AuthController.self) private var auth

    /// Reused for real expense data (category totals, "Total Cost").
    @State private var homeViewModel: HomeViewModel

    @State private var selectedPeriod: Period = .thisMonth
    @State private var showAddBalance = false
    @State private var showAllBudgets = false
    @State private var showAllTotalCost = false

    // NOTE: none of these three exist in the current API — there's no
    // wallet/balance/income endpoint in `CostAPIClient`. They're local
    // state so the screen is fully interactive, but nothing here
    // persists yet. Wire these to real data once the backend supports it.
    @State private var totalBalance: Double = 20_000_000
    @State private var incomeTotal: Double = 7_000_000
    @State private var pockets: [BudgetPocket] = [
        BudgetPocket(id: "groceries", category: CostCategory(id: "groceries", emoji: "🛍️", name: "Groceries", color: "#00796B", is_generated_by_ai: false), amount: 120_000, budgetLimit: 170_000),
        BudgetPocket(id: "house", category: CostCategory(id: "house", emoji: "🏠", name: "House", color: "#AD1457", is_generated_by_ai: false), amount: 1_000_000, budgetLimit: 1_500_000)
    ]

    init(viewModel: HomeViewModel = HomeViewModel()) {
        _homeViewModel = State(initialValue: viewModel)
    }

    private var currencyCode: String {
        homeViewModel.rows.first?.cost.currency ?? "IDR"
    }

    private var displayedRows: [HomeCostRow] {
        let cutoff = selectedPeriod.cutoffDate
        return homeViewModel.rows.filter { row in
            guard let date = row.expenseDate else { return false }
            return Calendar.current.startOfDay(for: date) >= cutoff
        }
    }

    private var expensesTotal: Double {
        displayedRows.reduce(0) { $0 + $1.cost.amount }
    }

    /// "Total Cost" breakdown — this one IS derivable from real data
    /// (grouping the loaded costs by category), unlike the budget pockets
    /// above.
    private var totalCostItems: [BudgetPocket] {
        var totals: [String: (category: CostCategory?, amount: Double)] = [:]
        var order: [String] = []
        for row in displayedRows {
            let id = row.cost.category_id ?? row.cost.category?.id ?? "uncategorized"
            if totals[id] == nil {
                totals[id] = (row.cost.category, 0)
                order.append(id)
            }
            totals[id]!.amount += row.cost.amount
        }
        return order.map { id in
            let entry = totals[id]!
            let category = entry.category ?? CostCategory(id: id, emoji: "💳", name: "Uncategorized", color: nil, is_generated_by_ai: false)
            return BudgetPocket(id: id, category: category, amount: entry.amount)
        }
        .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        ZStack {
            CostaAuroraBackground(glowCenter: UnitPoint(x: 0.5, y: 0.05), glowColor: .blue)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    balanceCard
                    budgetSection
                    totalCostSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100) // room above the floating tab bar
            }
        }
        .task {
            guard let token = await auth.validToken() else { return }
            await homeViewModel.load(accessToken: token, chartDays: 7)
        }
        .refreshable {
            guard let token = await auth.validToken() else { return }
            await homeViewModel.load(accessToken: token, chartDays: 7)
        }
        .sheet(isPresented: $showAddBalance) {
            AddBalanceView { amount in
                totalBalance += amount
            }
        }
        .sheet(isPresented: $showAllBudgets) {
            BudgetPocketsView(pockets: pockets, currency: currencyCode) { updated in
                if let i = pockets.firstIndex(where: { $0.id == updated.id }) {
                    pockets[i] = updated
                } else {
                    pockets.append(updated)
                }
            }
        }
        .sheet(isPresented: $showAllTotalCost) {
            TotalCostView(periodLabel: selectedPeriod.label, items: totalCostItems, currency: currencyCode)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wallet")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("Manage your money for good")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Button {
                showAddBalance = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                    Text("Add Balance")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(CostaColors.gradient, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Balance card

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 7){
                Text("Total Balance")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.primary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("Rp.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text(wholeAmount(totalBalance))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Text(",00")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer(minLength: 0)
                }
            }
            

            HStack {
                Spacer()
                StyledPillMenuPicker(selection: $selectedPeriod, options: Period.allCases) { $0.label }
            }

//            Divider().overlay(Color.white.opacity(0.15))

            HStack(spacing: 24) {
                statColumn(title: "Income", periodLabel: selectedPeriod.label, amount: incomeTotal, icon: "arrow.up", tint: CostaColors.green)
                statColumn(title: "Expenses", periodLabel: selectedPeriod.label, amount: expensesTotal, icon: "arrow.down", tint: CostaColors.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            Image("Gradient3")
                .resizable()
                .scaledToFill()
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func statColumn(title: String, periodLabel: String, amount: Double, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(tint, in: Circle())
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                Text("·")
                    .foregroundStyle(.white.opacity(0.4))
                Text(periodLabel)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Text(wholeAmount(amount))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Budget section

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Budget") { showAllBudgets = true }

            if pockets.isEmpty {
                Text("No budget pockets yet.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(pockets) { pocket in
                            budgetPocketCard(pocket)
                        }
                    }
                }
            }
        }
    }

    /// Real amount spent so far in `pocket.category`, within the current
    /// period — computed from actual loaded costs, unlike `budgetLimit`
    /// which is still a locally-set target (no budget API yet).
    private func spentAmount(for pocket: BudgetPocket) -> Double {
        displayedRows
            .filter { row in
                let rowCategoryId = row.cost.category_id ?? row.cost.category?.id
                return rowCategoryId != nil && rowCategoryId == pocket.category.id
            }
            .reduce(0) { $0 + $1.cost.amount }
    }

    private func budgetPocketCard(_ pocket: BudgetPocket) -> some View {
        let spent = spentAmount(for: pocket)
        let progress = pocket.budgetLimit > 0 ? min(spent / pocket.budgetLimit, 1) : 0
        let left = max(pocket.budgetLimit - spent, 0)

        return VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill((Color(hex: pocket.category.color ?? "") ?? .blue).opacity(0.3))
                    .frame(width: 40, height: 40)
                Text(pocket.category.emoji)
                    .font(.title3)
            }

            Text(pocket.category.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)

            Text("Rp " + wholeAmount(spent))
                .font(.body.weight(.bold))
                .foregroundStyle(.white)

            if pocket.budgetLimit > 0 {
                ProgressView(value: progress)
                    .tint(progress >= 1 ? CostaColors.red : CostaColors.green)
                    .scaleEffect(x: 1, y: 1.4, anchor: .center)

                Text(wholeAmount(left) + " left")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .frame(width: 150, alignment: .leading)
        .background(CostaColors.containerFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Total cost section

    private var totalCostSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Total Cost") { showAllTotalCost = true }

            if totalCostItems.isEmpty {
                Text("No costs recorded for this period.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                VStack(spacing: 10) {
                    ForEach(totalCostItems.prefix(3)) { item in
                        StyledTransactionRow(
                            emoji: item.category.emoji,
                            colorHex: item.category.color,
                            title: item.category.name,
                            subtitle: selectedPeriod.label,
                            amountText: "Rp." + wholeAmount(item.amount)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Shared section header

    private func sectionHeader(title: String, onSeeAll: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button(action: onSeeAll) {
                HStack(spacing: 2) {
                    Text("See All")
                        .font(.subheadline)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Formatting

    private func wholeAmount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "id_ID")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

#Preview("With Total Cost data") {
    let vm = HomeViewModel()
    let house = CostCategory(id: "house", emoji: "🏠", name: "House", color: "#2E7D32", is_generated_by_ai: false)
    let groceries = CostCategory(id: "groceries", emoji: "🛍️", name: "Groceries", color: "#00796B", is_generated_by_ai: false)
    vm.rows = [
        HomeCostRow(
            cost: Cost(id: "1", user_id: nil, name: "Rent", amount: 500_000, currency: "IDR", created_at: nil, updated_at: nil, category_id: "house", category: house),
            expenseId: "e1", expenseDate: Date()
        ),
        HomeCostRow(
            cost: Cost(id: "2", user_id: nil, name: "Groceries run", amount: 300_000, currency: "IDR", created_at: nil, updated_at: nil, category_id: "groceries", category: groceries),
            expenseId: "e2", expenseDate: Date()
        )
    ]
    return WalletView(viewModel: vm)
        .environment(AuthController())
}

#Preview {
    WalletView()
        .environment(AuthController())
}
