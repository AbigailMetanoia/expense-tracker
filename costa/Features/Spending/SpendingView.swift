//
//  SpendingView.swift
//  costa
//

import Charts
import SwiftUI

struct SpendingView: View {
    enum Period: String, CaseIterable, Hashable {
        case day, week, month, year

        var label: String {
            switch self {
            case .day: "Day"
            case .week: "Week"
            case .month: "Month"
            case .year: "Year"
            }
        }

        var cutoffDate: Date {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            switch self {
            case .day: return today
            case .week: return calendar.date(byAdding: .day, value: -6, to: today)!
            case .month: return calendar.date(byAdding: .day, value: -29, to: today)!
            case .year: return calendar.date(byAdding: .day, value: -364, to: today)!
            }
        }
    }

    @Environment(AuthController.self) private var auth
    @State private var viewModel: HomeViewModel
    @State private var selectedPeriod: Period = .month
    @State private var showTopSpending = false

    init(viewModel: HomeViewModel = HomeViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    private var displayedRows: [HomeCostRow] {
        let cutoff = selectedPeriod.cutoffDate
        return viewModel.rows.filter { row in
            guard let date = row.expenseDate else { return false }
            return Calendar.current.startOfDay(for: date) >= cutoff
        }
    }

    private var totalAmount: Double {
        displayedRows.reduce(0) { $0 + $1.cost.amount }
    }

    private var currencyCode: String {
        displayedRows.first?.cost.currency ?? "IDR"
    }

    /// Category breakdown for the donut chart, legend, AND the "Top
    /// Spending" cards below — sorted by amount (largest first) so:
    /// 1. the legend/card order matches the ring's reading order, and
    /// 2. the biggest category gets the most saturated blue shade.
    private var categoryBreakdown: [SpendingCategorySlice] {
        var totals: [String: (name: String, emoji: String, amount: Double)] = [:]
        var order: [String] = []
        for row in displayedRows {
            let id = row.cost.category_id ?? row.cost.category?.id ?? "uncategorized"
            let name = row.cost.category?.name ?? "Uncategorized"
            let emoji = row.cost.category?.emoji.isEmpty == false ? row.cost.category!.emoji : "💳"
            if totals[id] == nil {
                totals[id] = (name, emoji, 0)
                order.append(id)
            }
            totals[id]!.amount += row.cost.amount
        }
        let sortedIds = order.sorted { totals[$0]!.amount > totals[$1]!.amount }
        return sortedIds.enumerated().map { index, id in
            let entry = totals[id]!
            let color = CostaColors.blueShades[index % CostaColors.blueShades.count]
            return SpendingCategorySlice(id: id, name: entry.name, emoji: entry.emoji, amount: entry.amount, color: color)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CostaAuroraBackground(glowCenter: UnitPoint(x: 0.5, y: 0.05), glowColor: .blue)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        periodPicker
                        summaryCard
                        topSpendingSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100) // room above the floating tab bar
                }
            }
            .task {
                guard let token = await auth.validToken() else { return }
                await viewModel.load(accessToken: token, chartDays: 7)
            }
            .refreshable {
                guard let token = await auth.validToken() else { return }
                await viewModel.load(accessToken: token, chartDays: 7)
            }
            .navigationDestination(isPresented: $showTopSpending) {
                TopSpendingView(categories: categoryBreakdown)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Expenses")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)
            Text("Track where your money goes.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary.opacity(0.8))
        }
    }

    // MARK: - Period picker

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(Period.allCases, id: \.self) { period in
                Button {
                    selectedPeriod = period
                } label: {
                    Text(period.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selectedPeriod == period ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedPeriod == period ? CostaColors.containerBackground.opacity(0.25) : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(CostaColors.containerBackground.opacity(0.1), in: Capsule())
    }

    // MARK: - Summary card (total + trend + donut)

    private var summaryCard: some View {
        SpendingSummaryCard(
            totalAmount: totalAmount,
            categories: categoryBreakdown,
            errorMessage: viewModel.errorMessage
        )
    }

    // MARK: - Top spending section
    //
    // Shows CATEGORIES ranked by how much they've cost, not individual
    // transactions — same data as the donut chart, presented as full-width
    // rows matching TotalCostView's row style (icon + name + amount).

    private var topSpendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Spending")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    showTopSpending = true
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

            if categoryBreakdown.isEmpty {
                Text("No spending yet.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(categoryBreakdown) { item in
                        topSpendingRow(item)
                    }
                }
            }
        }
    }

    private func topSpendingRow(_ item: SpendingCategorySlice) -> some View {
        StyledCategoryAmountRow(
            emoji: item.emoji,
            title: item.name,
            amountText: "Rp. " + wholeAmount(item.amount)
        )
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

#Preview("With chart data") {
    let vm = HomeViewModel()
    let today = Date()

    func category(_ id: String, _ emoji: String, _ name: String, _ hex: String) -> CostCategory {
        CostCategory(id: id, emoji: emoji, name: name, color: hex, is_generated_by_ai: false)
    }

    vm.rows = [
        HomeCostRow(
            cost: Cost(id: "1", user_id: nil, name: "Hamburger", amount: 350_000, currency: "IDR", created_at: nil, updated_at: nil, category_id: "food", category: category("food", "🍔", "Food", "#FF9500")),
            expenseId: "e1", expenseDate: today
        ),
        HomeCostRow(
            cost: Cost(id: "2", user_id: nil, name: "Gasoline", amount: 300_000, currency: "IDR", created_at: nil, updated_at: nil, category_id: "transport", category: category("transport", "🚗", "Transportation", "#2E7DE0")),
            expenseId: "e2", expenseDate: today
        ),
        HomeCostRow(
            cost: Cost(id: "3", user_id: nil, name: "Rent", amount: 250_000, currency: "IDR", created_at: nil, updated_at: nil, category_id: "house", category: category("house", "🏠", "House", "#2E7D32")),
            expenseId: "e3", expenseDate: today
        ),
        HomeCostRow(
            cost: Cost(id: "4", user_id: nil, name: "Groceries", amount: 150_000, currency: "IDR", created_at: nil, updated_at: nil, category_id: "shopping", category: category("shopping", "🛍️", "Shopping", "#00796B")),
            expenseId: "e4", expenseDate: today
        ),
        HomeCostRow(
            cost: Cost(id: "5", user_id: nil, name: "Vitamins", amount: 100_000, currency: "IDR", created_at: nil, updated_at: nil, category_id: "health", category: category("health", "💊", "Health", "#D6249F")),
            expenseId: "e5", expenseDate: today
        )
    ]

    return SpendingView(viewModel: vm)
        .environment(AuthController())
}

#Preview {
    SpendingView()
        .environment(AuthController())
}

// MARK: - SpendingSummaryCard
//
// The "Total Spent" card (amount + trend badge + donut chart + legend),
// extracted as its own component so it can be tweaked and previewed in
// isolation against the HiFi, without needing the rest of SpendingView
// (header, period picker, top-spending list) in the canvas.

struct SpendingCategorySlice: Identifiable {
    var id: String
    var name: String
    var emoji: String
    var amount: Double
    var color: Color
}

struct SpendingSummaryCard: View {
    let totalAmount: Double
    let categories: [SpendingCategorySlice]
    var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Total Spent")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("Rp.")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(wholeAmount(totalAmount))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text(",00")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }

            // NOTE: comparing to the prior period needs a second fetch (or
            // a backend endpoint) that isn't wired up yet — this trend
            // value is a placeholder derived from the current total.
            if totalAmount > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(CostaColors.red, in: Circle())
                    Text("Rp\(shortAmount(totalAmount / 2)) from last month")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(CostaColors.red.opacity(0.3), in: Capsule())
            }

            if categories.isEmpty {
                Text("No expenses recorded for this period.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 8)
            } else {
                donutAndLegend
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(CostaColors.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(CostaColors.containerFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var donutAndLegend: some View {
        HStack(spacing: 20) {
            Chart(categories, id: \.id) { item in
                SectorMark(
                    angle: .value("Amount", item.amount),
                    innerRadius: .ratio(0.65),
                    angularInset: 2
                )
                .cornerRadius(4)
                .foregroundStyle(item.color)
            }
            .chartLegend(.hidden)
            .frame(width: 130, height: 130)
            .overlay {
                VStack(spacing: 2) {
                    Text("\(categories.count)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text(categories.count == 1 ? "Category" : "Categories")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(categories) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 8, height: 8)
                        Text(item.name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(percentText(item.amount))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
    }

    // MARK: - Formatting

    private func percentText(_ amount: Double) -> String {
        guard totalAmount > 0 else { return "0%" }
        return String(format: "%.0f%%", (amount / totalAmount) * 100)
    }

    private func shortAmount(_ value: Double) -> String {
        if value >= 1_000_000 { return "\(Int(value / 1_000_000))M" }
        if value >= 1_000 { return "\(Int(value / 1_000))K" }
        return "\(Int(value))"
    }

    private func wholeAmount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "id_ID")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

#Preview("SpendingSummaryCard") {
    ZStack {
        CostaAuroraBackground(glowCenter: UnitPoint(x: 0.5, y: 0.05), glowColor: .blue)
        SpendingSummaryCard(
            totalAmount: 1_150_000,
            categories: [
                SpendingCategorySlice(id: "food", name: "Food", emoji: "🍔", amount: 350_000, color: CostaColors.blueShades[0]),
                SpendingCategorySlice(id: "transport", name: "Transportation", emoji: "🚗", amount: 300_000, color: CostaColors.blueShades[1]),
                SpendingCategorySlice(id: "house", name: "House", emoji: "🏠", amount: 250_000, color: CostaColors.blueShades[2]),
                SpendingCategorySlice(id: "shopping", name: "Shopping", emoji: "🛍️", amount: 150_000, color: CostaColors.blueShades[3]),
                SpendingCategorySlice(id: "health", name: "Health", emoji: "💊", amount: 100_000, color: CostaColors.blueShades[4])
            ]
        )
        .padding(20)
    }
}
