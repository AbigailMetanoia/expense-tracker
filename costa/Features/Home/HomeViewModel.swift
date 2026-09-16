//
//  HomeViewModel.swift
//  costa
//

import Foundation
import Observation

/// A flattened cost line item enriched with the parent expense's `date` field,
/// which is what `/api/cost/summary/daily` uses for daily bucketing.
struct HomeCostRow: Identifiable {
    var id: String { cost.id }
    let cost: Cost
    let expenseId: String
    /// Parsed from the parent expense's `YYYY-MM-DD` date string.
    let expenseDate: Date?
}

@MainActor
@Observable
final class HomeViewModel {
    var rows: [HomeCostRow] = []
    var dailyPoints: [DailyPoint] = []
    /// Number of days the current `dailyPoints` were fetched for.
    /// Updated atomically with the data so the chart axis never leads the data.
    var loadedChartDays: Int = 7
    var isLoading = false
    var errorMessage: String?

    /// Explicit, `nonisolated` no-arg init. All stored properties already
    /// have default values, so this doesn't touch any main-actor-isolated
    /// state — it just lets `HomeViewModel()` be used as a default
    /// parameter value elsewhere (e.g. `HomeView`'s init) without Swift
    /// complaining about calling a main-actor-isolated initializer from a
    /// synchronous nonisolated context.
    nonisolated init() {}

    var totalAmount: Double {
        rows.reduce(0) { $0 + $1.cost.amount }
    }

    /// Chart points from `/api/cost/summary/daily` (line + area chart).
    var chartData: [DailySpend] {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        return dailyPoints.compactMap { point in
            guard let date = parser.date(from: point.date) else { return nil }
            return DailySpend(date: date, total: point.total)
        }
    }

    func load(accessToken: String, chartDays: Int = 7) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let client = CostAPIClient(accessToken: accessToken)
            async let expenses = client.listExpenses(draft: false)
            async let summary = client.dailySummary(days: chartDays)
            let (fetchedExpenses, fetchedSummary) = try await (expenses, summary)

            let parser = DateFormatter()
            parser.calendar = Calendar(identifier: .gregorian)
            parser.locale = Locale(identifier: "en_US_POSIX")
            parser.dateFormat = "yyyy-MM-dd"

            rows = fetchedExpenses.flatMap { expense in
                expense.costs.map { cost in
                    HomeCostRow(
                        cost: cost,
                        expenseId: expense.id,
                        expenseDate: parser.date(from: expense.date)
                    )
                }
            }
            dailyPoints = fetchedSummary.points
            loadedChartDays = chartDays
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct DailySpend: Identifiable {
    var id: Date { date }
    var date: Date
    var total: Double
}
