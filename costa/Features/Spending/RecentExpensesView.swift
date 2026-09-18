//
//  RecentExpensesView.swift
//  costa
//
//  Full transaction history, grouped by day (Today, Yesterday, then the
//  actual date further back). Reuses `PocketTransaction` since the data
//  shape is identical to what PocketDetailsView needs.
//

import SwiftUI

struct RecentExpensesView: View {
    @Environment(\.dismiss) private var dismiss

    let transactions: [PocketTransaction]
    /// Called when a row is tapped — e.g. to open that transaction for
    /// editing. Rows are plain (non-interactive) if nil.
    var onSelect: ((PocketTransaction) -> Void)?

    init(transactions: [PocketTransaction], onSelect: ((PocketTransaction) -> Void)? = nil) {
        self.transactions = transactions
        self.onSelect = onSelect
    }

    private var groupedByDay: [(label: String, items: [PocketTransaction])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { day in
            let label: String
            if calendar.isDateInToday(day) {
                label = "Today"
            } else if calendar.isDateInYesterday(day) {
                label = "Yesterday"
            } else {
                label = day.formatted(date: .abbreviated, time: .omitted)
            }
            let items = groups[day]!.sorted { $0.date > $1.date }
            return (label, items)
        }
    }

    var body: some View {
        ZStack {
            CostaAuroraBackground(glowCenter: UnitPoint(x: 0.5, y: 0.05), glowColor: .blue)

            VStack(spacing: 0) {
                header

                ScrollView {
                    if transactions.isEmpty {
                        Text("No expenses yet.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 20) {
                            ForEach(groupedByDay, id: \.label) { group in
                                dayGroup(group)
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
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)

            Text("Recent Expenses")
//                .font(.title2.weight(.bold))
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Day group

    private func dayGroup(_ group: (label: String, items: [PocketTransaction])) -> some View {
        VStack(spacing: 12) {
            Text(group.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)

            ForEach(group.items) { tx in
                row(tx, dayLabel: group.label)
            }
        }
    }

    private func row(_ tx: PocketTransaction, dayLabel: String) -> some View {
        Button {
            onSelect?(tx)
        } label: {
            StyledTransactionRow(
                emoji: tx.emoji,
                colorHex: tx.colorHex,
                title: tx.name,
                subtitle: "\(dayLabel), \(tx.date.formatted(date: .omitted, time: .shortened))",
                amountText: "-Rp" + formatted(tx.amount)
            )
        }
        .buttonStyle(.plain)
//        .disabled(onSelect == nil)
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
    let calendar = Calendar.current
    let today = Date()
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

    NavigationStack {
        RecentExpensesView(
            transactions: [
                PocketTransaction(id: "1", name: "Hamburger", date: today, amount: 40_000, emoji: "🍔", colorHex: "#C62828"),
                PocketTransaction(id: "2", name: "Laundry", date: today, amount: 10_000, emoji: "🧺", colorHex: "#00796B"),
                PocketTransaction(id: "3", name: "Groceries", date: today, amount: 100_000, emoji: "🛍️", colorHex: "#2E7D32"),
                PocketTransaction(id: "4", name: "Gasoline", date: today, amount: 50_000, emoji: "⛽", colorHex: "#1565C0"),
                PocketTransaction(id: "5", name: "Hamburger", date: yesterday, amount: 40_000, emoji: "🍔", colorHex: "#C62828"),
                PocketTransaction(id: "6", name: "Laundry", date: yesterday, amount: 10_000, emoji: "🧺", colorHex: "#00796B"),
                PocketTransaction(id: "7", name: "Groceries", date: yesterday, amount: 100_000, emoji: "🛍️", colorHex: "#2E7D32")
            ]
        ) { tx in
            print("Tapped: \(tx.name)")
        }
    }
}
