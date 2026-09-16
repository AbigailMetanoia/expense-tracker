//
//  PocketDetailsView.swift
//  costa
//
//  Read-only drill-down from BudgetPocketsView: shows the pocket's total
//  and every transaction that falls under it, grouped by day (Today,
//  Yesterday, then the actual date further back).
//

import SwiftUI

/// A single transaction line shown in a pocket's history.
struct PocketTransaction: Identifiable {
    var id: String
    var name: String
    var date: Date
    var amount: Double
    var emoji: String
    var colorHex: String?
}

struct PocketDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    let pocket: BudgetPocket
    let transactions: [PocketTransaction]
    let currency: String

    init(pocket: BudgetPocket, transactions: [PocketTransaction], currency: String = "IDR") {
        self.pocket = pocket
        self.transactions = transactions
        self.currency = currency
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

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    HStack{
                        backButton
//                        Text("Budget Pockets")
//                            .font(.title2.weight(.bold))
//                            .foregroundStyle(.white)
                    }
                    

                    headerCard

                    Text("Recent Transactions")
                        .font(.headline)
                        .foregroundStyle(.white)

                    if transactions.isEmpty {
                        Text("No transactions yet in this pocket.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)
                    } else {
                        ForEach(groupedByDay, id: \.label) { group in
                            dayGroup(group)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Back button

    private var backButton: some View {
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
    }

    // MARK: - Header card

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((pocketColor).opacity(0.3))
                    .frame(width: 44, height: 44)
                Text(pocket.category.emoji)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(pocket.category.name)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("Rp.")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(formatted(pocket.amount))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text(",00")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var pocketColor: Color {
        Color(hex: pocket.category.color ?? "") ?? .blue
    }

    // MARK: - Day group

    private func dayGroup(_ group: (label: String, items: [PocketTransaction])) -> some View {
        VStack(spacing: 10) {
            Text(group.label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, tx in
                    transactionRow(tx, dayLabel: group.label)
                    if index < group.items.count - 1 {
                        Divider()
                            .overlay(Color.white.opacity(0.08))
                            .padding(.leading, 68)
                    }
                }
            }
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func transactionRow(_ tx: PocketTransaction, dayLabel: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((Color(hex: tx.colorHex ?? "") ?? pocketColor).opacity(0.3))
                    .frame(width: 44, height: 44)
                Text(tx.emoji)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tx.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(dayLabel), \(tx.date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Text("-Rp" + formatted(tx.amount))
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(14)
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
        PocketDetailsView(
            pocket: BudgetPocket(
                id: "house",
                category: CostCategory(id: "house", emoji: "🏠", name: "House", color: "#2E7D32", is_generated_by_ai: false),
                amount: 900_000
            ),
            transactions: [
                PocketTransaction(id: "1", name: "Hamburger", date: today, amount: 40_000, emoji: "🍔", colorHex: "#C62828"),
                PocketTransaction(id: "2", name: "Laundry", date: today, amount: 10_000, emoji: "🧺", colorHex: "#00796B"),
                PocketTransaction(id: "3", name: "Groceries", date: today, amount: 100_000, emoji: "🛍️", colorHex: "#2E7D32"),
                PocketTransaction(id: "4", name: "Gasoline", date: today, amount: 50_000, emoji: "⛽", colorHex: "#1565C0"),
                PocketTransaction(id: "5", name: "Hamburger", date: yesterday, amount: 40_000, emoji: "🍔", colorHex: "#C62828"),
                PocketTransaction(id: "6", name: "Laundry", date: yesterday, amount: 10_000, emoji: "🧺", colorHex: "#00796B")
            ]
        )
    }
}
