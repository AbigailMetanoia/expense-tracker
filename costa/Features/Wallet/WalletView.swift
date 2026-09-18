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

    /// One "money added" event, timestamped so it can be filtered by
    /// `Period` the same way `HomeCostRow` expenses are. Currently this is
    /// the ONLY thing that counts as Income — there's no income endpoint
    /// in `CostAPIClient`, so every entry here comes from the user
    /// confirming an amount in `AddBalanceView`. Swap this for a real
    /// income model once the backend supports one.
    private struct IncomeEntry: Identifiable, Codable {
        var id: String
        var amount: Double
        var date: Date
    }

    @Environment(AuthController.self) private var auth

    /// Reused for real expense data (category totals, "Total Cost").
    @State private var homeViewModel: HomeViewModel

    @State private var selectedPeriod: Period = .thisMonth
    @State private var showAddBalance = false
    @State private var showAllBudgets = false
    @State private var showAllTotalCost = false

    // NOTE: there's no wallet/balance endpoint in `CostAPIClient`. This is
    // local state so the screen is fully interactive, but it doesn't
    // persist yet. Unlike Income below, `totalBalance` is a running total
    // (not filtered by period) — it represents "how much money exists
    // right now", not a dated transaction.
    @State private var totalBalance: Double = 20_000_000

    /// Every Add Balance confirmation, each with its own date. Persisted
    /// locally (see `loadIncomeEntries`/`saveIncomeEntries`) so Income
    /// survives an app relaunch even without a backend.
    @State private var incomeEntries: [IncomeEntry] = []

    /// Budget pockets, built ONLY from real categories fetched via
    /// `listCategories()` — never hardcoded — so `pocket.category.id`
    /// always matches the `category_id` used on actual `Cost` records.
    @State private var pockets: [BudgetPocket] = []
    /// All categories in the workspace, used both to build `pockets` and
    /// to populate the "Add Budget Pocket" picker in `BudgetPocketsView`.
    @State private var allCategories: [CostCategory] = []

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

    /// Income entries within `selectedPeriod`, same filtering shape as
    /// `displayedRows` above so Income and Expenses behave consistently
    /// when the period picker changes.
    private var displayedIncomeEntries: [IncomeEntry] {
        let cutoff = selectedPeriod.cutoffDate
        return incomeEntries.filter { Calendar.current.startOfDay(for: $0.date) >= cutoff }
    }

    private var incomeTotal: Double {
        displayedIncomeEntries.reduce(0) { $0 + $1.amount }
    }

    /// "Total Cost" breakdown — derived from real loaded costs.
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
        NavigationStack {
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
                // Local, doesn't need a token — load it up front so Income
                // shows correct data as soon as the screen appears.
                incomeEntries = loadIncomeEntries()

                guard let token = await auth.validToken() else { return }
                await homeViewModel.load(accessToken: token, chartDays: 7)
                await loadPockets(accessToken: token)
            }
            .refreshable {
                guard let token = await auth.validToken() else { return }
                await homeViewModel.load(accessToken: token, chartDays: 7)
                await loadPockets(accessToken: token)
            }
            .sheet(isPresented: $showAddBalance) {
                AddBalanceView { amount in
                    totalBalance += amount
                    addIncomeEntry(amount: amount)
                }
            }
            .navigationDestination(isPresented: $showAllBudgets) {
                BudgetPocketsView(pockets: pockets, allCategories: allCategories, currency: currencyCode) { updated in
                    if let i = pockets.firstIndex(where: { $0.id == updated.id }) {
                        pockets[i] = updated
                    } else {
                        pockets.append(updated)
                    }
                    saveBudgetLimit(updated.budgetLimit, for: updated.category.id ?? updated.id)
                }
            }
            .navigationDestination(isPresented: $showAllTotalCost) {
                TotalCostView(periodLabel: selectedPeriod.label, items: totalCostItems, currency: currencyCode)
            }
        }
    }

    // MARK: - Loading pockets from real categories

    /// Fetches the real category list and builds `pockets` from it,
    /// merging in whatever budget limits were saved locally. This is
    /// what guarantees `pocket.category.id` matches `cost.category_id`,
    /// so `spentAmount(for:)` below actually finds matching costs.
    private func loadPockets(accessToken: String) async {
        do {
            let client = CostAPIClient(accessToken: accessToken)
            let categories = try await client.listCategories()
            allCategories = categories
            let limits = loadBudgetLimits()
            pockets = categories.compactMap { category -> BudgetPocket? in
                guard let limit = limits[category.id ?? ""], limit > 0 else { return nil }
                return BudgetPocket(
                    id: category.id ?? UUID().uuidString,
                    category: category,
                    amount: 0, // recomputed live by spentAmount(for:)
                    budgetLimit: limit
                )
            }
        } catch {
            print("Failed to load categories for budget pockets: \(error)")
        }
    }

    // MARK: - Local budget-limit persistence
    // NOTE: there's no budget endpoint in `CostAPIClient` yet — only the
    // budget LIMIT is stored locally (UserDefaults) keyed by real category
    // id. "Spent" is always computed live from real costs, never stored.
    // Swap this for a real API call once the backend supports budgets.

    private static let budgetLimitsKey = "costa.budgetLimits"

    private func loadBudgetLimits() -> [String: Double] {
        (UserDefaults.standard.dictionary(forKey: Self.budgetLimitsKey) as? [String: Double]) ?? [:]
    }

    private func saveBudgetLimit(_ amount: Double, for categoryId: String) {
        var limits = loadBudgetLimits()
        limits[categoryId] = amount
        UserDefaults.standard.set(limits, forKey: Self.budgetLimitsKey)
    }

    // MARK: - Local income persistence
    // NOTE: same situation as budget limits above — no income endpoint in
    // `CostAPIClient`, so every Add Balance confirmation is recorded here
    // as a dated `IncomeEntry` and stored locally (UserDefaults, JSON-
    // encoded). Swap this for a real API call once the backend supports
    // income/transactions.

    private static let incomeEntriesKey = "costa.incomeEntries"

    private func loadIncomeEntries() -> [IncomeEntry] {
        guard let data = UserDefaults.standard.data(forKey: Self.incomeEntriesKey),
              let entries = try? JSONDecoder().decode([IncomeEntry].self, from: data)
        else { return [] }
        return entries
    }

    private func saveIncomeEntries() {
        guard let data = try? JSONEncoder().encode(incomeEntries) else { return }
        UserDefaults.standard.set(data, forKey: Self.incomeEntriesKey)
    }

    private func addIncomeEntry(amount: Double) {
        let entry = IncomeEntry(id: UUID().uuidString, amount: amount, date: Date())
        incomeEntries.append(entry)
        saveIncomeEntries()
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

            HStack(spacing: 10) {
                statColumn(title: "Income", periodLabel: selectedPeriod.label, amount: incomeTotal, icon: "arrow.up", tint: CostaColors.green)

                Divider().overlay(Color.white.opacity(0.15))

                statColumn(title: "Expenses", periodLabel: selectedPeriod.label, amount: expensesTotal, icon: "arrow.down", tint: CostaColors.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(
            ZStack {
                CostaColors.containerFill.opacity(0.1)
                Image("Gradient3")
                    .resizable()
                    .scaledToFill()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
//        .background {
//            RoundedRectangle(cornerRadius: 20, style: .continuous)
//                .fill(.ultraThinMaterial)
//                .blur(radius: 0.5)
//        }
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 14)
//        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
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
                    .foregroundStyle(.primary)
                Text("·")
                    .foregroundStyle(.white.opacity(0.4))
                Text(periodLabel)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(wholeAmount(amount))
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.primary)
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
                    HStack(spacing: 15) {
                        ForEach(pockets) { pocket in
                            budgetPocketCard(pocket)
                        }
                    }
                }
            }
        }
    }

    /// Real amount spent so far in `pocket.category`, within the current
    /// period — computed live from actual loaded costs. This now works
    /// correctly because `pocket.category.id` comes from the same real
    /// category list that costs are tagged with.
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
                    .fill(CostaColors.circleContainer)
                    .frame(width: 40, height: 40)
                Text(pocket.category.emoji)
                    .font(.system(size: 21, weight: .regular))
            }

            VStack(alignment: .leading, spacing: 3){
                Text(pocket.category.name)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.primary)

                Text("Rp " + wholeAmount(spent))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            if pocket.budgetLimit > 0 {
                ProgressView(value: progress)
                    .tint(progress >= 1 ? CostaColors.red : CostaColors.green)
                    .scaleEffect(x: 1, y: 1.4, anchor: .center)

                Text(wholeAmount(left) + " left")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
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
