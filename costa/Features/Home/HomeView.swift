//
//  HomeView.swift
//  costa
//

import SwiftUI

struct HomeView: View {
    enum TimeFilter: String, CaseIterable, Hashable {
        case today
        case last7Days
        case last30Days
        case all

        /// Short label for the pill chip — the previous labels ("Expenses
        /// last 7 days") were sized for a full-width row, not a small
        /// dropdown pill like the new design uses.
        var label: String {
            switch self {
            case .today:      "Today"
            case .last7Days:  "This Week"
            case .last30Days: "This Month"
            case .all:        "All Time"
            }
        }

        var chartDays: Int {
            switch self {
            case .today:      1
            case .last7Days:  7
            case .last30Days: 30
            case .all:        90
            }
        }

        var cutoffDate: Date? {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            switch self {
            case .today:      return today
            case .last7Days:  return calendar.date(byAdding: .day, value: -6, to: today)
            case .last30Days: return calendar.date(byAdding: .day, value: -29, to: today)
            case .all:        return nil
            }
        }
    }

    @Environment(AuthController.self) private var auth
    @State private var viewModel: HomeViewModel
    @State private var showSignOutConfirmation = false
    @State private var selectedFilter: TimeFilter = .last7Days
    @State private var isAmountHidden = false
    @State private var showRecentExpenses = false
    @Binding var selectedCost: Cost?
    /// Parent increments this after a cost line is edited so we refetch lists and chart.
    var refreshCostsToken: Int = 0

    init(
        selectedCost: Binding<Cost?>,
        refreshCostsToken: Int = 0,
        viewModel: HomeViewModel = HomeViewModel()
    ) {
        self._selectedCost = selectedCost
        self.refreshCostsToken = refreshCostsToken
        _viewModel = State(initialValue: viewModel)
    }

    private var firstName: String {
        auth.user?.email?.components(separatedBy: "@").first?.capitalized ?? "there"
    }

    private var currencyCode: String {
        displayedRows.first?.cost.currency ?? viewModel.rows.first?.cost.currency ?? "IDR"
    }

    private var displayedRows: [HomeCostRow] {
        guard let cutoff = selectedFilter.cutoffDate else { return viewModel.rows }
        let cutoffDay = Calendar.current.startOfDay(for: cutoff)
        return viewModel.rows.filter { row in
            guard let date = row.expenseDate else { return false }
            return Calendar.current.startOfDay(for: date) >= cutoffDay
        }
    }

    private var displayedTotalAmount: Double {
        displayedRows.reduce(0) { $0 + $1.cost.amount }
    }

    private var displayedRecentCosts: [Cost] {
        Array(displayedRows.prefix(10).map(\.cost))
    }

    var body: some View {
        ZStack {
            CostaAuroraBackground(glowCenter: UnitPoint(x: 0.5, y: 0.05), glowColor: .blue)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    filterChip
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    summaryCard
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    incomeExpenseRow
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    recentSection
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 100) // room above the floating tab bar
                }
            }
        }
        .refreshable { await reload() }
        .task(id: selectedFilter) {
            guard let token = await auth.validToken() else { return }
            await viewModel.load(accessToken: token, chartDays: selectedFilter.chartDays)
        }
        .onChange(of: refreshCostsToken) { _, _ in
            Task {
                guard let token = await auth.validToken() else { return }
                await viewModel.load(accessToken: token, chartDays: selectedFilter.chartDays)
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.rows.isEmpty {
                ProgressView().tint(.white)
            }
        }
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                Task { await auth.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(auth.user?.email ?? "Are you sure you want to sign out?")
        }
        .sheet(isPresented: $showRecentExpenses) {
            // NOTE: RecentExpensesView takes `[PocketTransaction]`, a
            // lighter display model, while Home works with real `[Cost]`.
            // This maps one to the other for display only — swap in a
            // real transaction fetch here if RecentExpensesView should
            // show more than what's already loaded on Home.
            RecentExpensesView(transactions: displayedRecentCosts.map { $0.asPocketTransaction() })
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(CostaColors.containerBackground.opacity(0.2))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "person.fill")
                }

            Text("Hello, \(firstName) \u{1F44B}")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                showSignOutConfirmation = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(CostaColors.containerBackground.opacity(0.2), in: Circle())
            }
            .buttonStyle(.plain)
        }.padding(.bottom, 10)
    }

    // MARK: - Filter chip

    private var filterChip: some View {
        HStack {
            StyledPillMenuPicker(
                selection: $selectedFilter,
                options: TimeFilter.allCases
            ) { $0.label }
            Spacer()
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Total Spending")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.8))
                Button {
                    isAmountHidden.toggle()
                } label: {
                    Image(systemName: isAmountHidden ? "eye.slash" : "eye")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if isAmountHidden {
                    Text("Rp. ••••••••")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("Rp.")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                    Text(wholeAmountText(displayedTotalAmount))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                    Text(",00")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            // NOTE: comparison-to-last-month isn't available yet — Home
            // only fetches the current filter's rows and a daily summary,
            // not a prior-period total. Wire this once the API can return
            // (or we can compute) last month's total for comparison.
            if let trend = spendingTrendPlaceholder {
                HStack(spacing: 6) {
                    Image(systemName: trend.isIncrease ? "arrow.up" : "arrow.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(trend.isIncrease ? CostaColors.red : CostaColors.green, in: Circle())
                    
                    Text(trend.text)
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(trend.isIncrease ? CostaColors.red.opacity(0.3) : CostaColors.green.opacity(0.3), in: Capsule())
            }

            if let err = viewModel.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(CostaColors.containerBackground.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Placeholder trend text — see the NOTE above `summaryCard`.
    private var spendingTrendPlaceholder: (isIncrease: Bool, text: String)? {
        guard displayedTotalAmount > 0 else { return nil }
        return (false, "Rp\(shortAmount(displayedTotalAmount)) from last month")
    }

    // MARK: - Income / Expenses row

    private var incomeExpenseRow: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Income",
                amount: incomeTotalPlaceholder,
                icon: "arrow.up",
                tint: CostaColors.green
            )
            statCard(
                title: "Expenses",
                amount: displayedTotalAmount,
                icon: "arrow.down",
                tint: CostaColors.red
            )
        }
    }

    /// NOTE: there's no income endpoint in the current API client, so this
    /// is a stub. Replace with `viewModel.incomeTotal` (or similar) once
    /// income tracking is wired up on the backend.
    private var incomeTotalPlaceholder: Double { 0 }

    private func statCard(title: String, amount: Double, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(tint, in: Circle())
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.primary)
            }
            Text("Rp. " + wholeAmountText(amount))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(CostaColors.containerBackground.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Recent expenses

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Expenses")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    showRecentExpenses = true
                } label: {
                    HStack(spacing: 5) {
                        Text("See All")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            if displayedRows.isEmpty && !viewModel.isLoading {
                Text("No expenses yet.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                VStack(spacing: 10) {
                    ForEach(displayedRecentCosts) { cost in
                        Button {
                            selectedCost = cost
                        } label: {
                            CostRowView(cost: cost)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func reload() async {
        guard let token = await auth.validToken() else { return }
        await viewModel.load(accessToken: token, chartDays: selectedFilter.chartDays)
    }

    private func shortAmount(_ value: Double) -> String {
        if value >= 1_000_000 { return "\(Int(value / 1_000_000))M" }
        if value >= 1_000 { return "\(Int(value / 1_000))K" }
        return "\(Int(value))"
    }

    private func wholeAmountText(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "id_ID")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

// MARK: - Cost row

/// Thin wrapper around the shared `StyledTransactionRow`, so Home's
/// transaction list looks identical to Wallet/Pocket/TopSpending's.
struct CostRowView: View {
    let cost: Cost

    var body: some View {
        StyledTransactionRow(
            emoji: cost.category?.emoji.isEmpty == false ? cost.category!.emoji : "💳",
            colorHex: cost.category?.color,
            title: cost.name,
            subtitle: cost.category?.name ?? "Uncategorized",
            amountText: "-Rp" + wholeAmount(cost.amount)
        )
    }

    private func wholeAmount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "id_ID")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

// MARK: - Cost -> PocketTransaction bridge

extension Cost {
    /// Maps a real `Cost` into the lighter `PocketTransaction` shape that
    /// RecentExpensesView/PocketDetailsView expect. `date` falls back to
    /// `.now` since `Cost` itself doesn't carry a timestamp — pass the
    /// parent expense's date in if you have it available at the call site.
    func asPocketTransaction() -> PocketTransaction {
        PocketTransaction(
            id: id,
            name: name,
            date: .now,
            amount: amount,
            emoji: category?.emoji.isEmpty == false ? category!.emoji : "💳",
            colorHex: category?.color
        )
    }
}

#Preview("Single recent expense") {
    CostRowView(
        cost: Cost(
            id: "preview-1",
            user_id: nil,
            name: "Hamburger",
            amount: 40_000,
            currency: "IDR",
            created_at: nil,
            updated_at: nil,
            category_id: "food",
            category: CostCategory(id: "food", emoji: "🍔", name: "Food", color: "#C62828", is_generated_by_ai: false)
        )
    )
    .padding()
    .background(Color(red: 0.04, green: 0.09, blue: 0.15))
}

#Preview("Recent Expenses — 1 example") {
    let vm = HomeViewModel()
    vm.rows = [
        HomeCostRow(
            cost: Cost(
                id: "preview-1",
                user_id: nil,
                name: "Hamburger",
                amount: 40_000,
                currency: "IDR",
                created_at: nil,
                updated_at: nil,
                category_id: "food",
                category: CostCategory(id: "food", emoji: "🍔", name: "Food", color: "#C62828", is_generated_by_ai: false)
            ),
            expenseId: "preview-expense-1",
            expenseDate: Date()
        )
    ]
    return HomeView(selectedCost: .constant(nil), viewModel: vm)
        .environment(AuthController())
}

#Preview {
    HomeView(selectedCost: .constant(nil), refreshCostsToken: 0)
        .environment(AuthController())
}
