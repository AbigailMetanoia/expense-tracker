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

    /// Default palette used when a category has no `color` set on the
    /// server — cycled in order so repeated runs stay stable-ish.
    private static let fallbackPalette: [Color] = [.orange, .blue, .green, .teal, .pink, .purple, .yellow]

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

    /// Category breakdown for the donut chart + legend, sorted by amount
    /// (largest slice first) so the legend order matches the ring's
    /// reading order.
    private var categoryBreakdown: [(id: String, name: String, amount: Double, color: Color)] {
        var totals: [String: (name: String, amount: Double)] = [:]
        var order: [String] = []
        for row in displayedRows {
            let id = row.cost.category_id ?? row.cost.category?.id ?? "uncategorized"
            let name = row.cost.category?.name ?? "Uncategorized"
            if totals[id] == nil {
                totals[id] = (name, 0)
                order.append(id)
            }
            totals[id]!.amount += row.cost.amount
        }
        return order
            .map { id -> (id: String, name: String, amount: Double, color: Color) in
                let entry = totals[id]!
                let hex = displayedRows.first(where: { ($0.cost.category_id ?? $0.cost.category?.id) == id })?.cost.category?.color
                let color = hex.flatMap { Color(hex: $0) } ?? Self.fallbackPalette[order.firstIndex(of: id)! % Self.fallbackPalette.count]
                return (id, entry.name, entry.amount, color)
            }
            .sorted { $0.amount > $1.amount }
    }

    var body: some View {
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
            // chartDays is irrelevant here — Spending doesn't use the
            // daily-summary series, only the flattened cost rows.
            await viewModel.load(accessToken: token, chartDays: 7)
        }
        .refreshable {
            guard let token = await auth.validToken() else { return }
            await viewModel.load(accessToken: token, chartDays: 7)
        }
        .sheet(isPresented: $showTopSpending) {
            TopSpendingView(transactions: displayedRows.map { $0.cost.asPocketTransaction() })
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Expenses")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text("Track where your money goes.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
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
                            selectedPeriod == period ? Color.white.opacity(0.15) : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.06), in: Capsule())
    }

    // MARK: - Summary card (total + trend + donut)

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Total Spent")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

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

            // NOTE: same limitation as Home — comparing to the prior
            // period needs a second fetch (or a backend endpoint) that
            // isn't wired up yet. Placeholder trend shown below.
            if totalAmount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up")
                        .font(.caption2.weight(.bold))
                    Text("Rp\(shortAmount(totalAmount / 2)) from last month")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.3), in: Capsule())
            }

            if categoryBreakdown.isEmpty {
                Text("No expenses recorded for this period.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 8)
            } else {
                donutAndLegend
            }

            if let err = viewModel.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var donutAndLegend: some View {
        HStack(spacing: 20) {
            Chart(categoryBreakdown, id: \.id) { item in
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
                    Text("\(categoryBreakdown.count)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text(categoryBreakdown.count == 1 ? "Category" : "Categories")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(categoryBreakdown, id: \.id) { item in
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

    // MARK: - Top spending section

    private var topSpendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Spending")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showTopSpending = true
                } label: {
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

            if displayedRows.isEmpty {
                Text("No spending yet.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(displayedRows.sorted { $0.cost.amount > $1.cost.amount }.prefix(10)) { row in
                        CostRowView(cost: row.cost)
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
