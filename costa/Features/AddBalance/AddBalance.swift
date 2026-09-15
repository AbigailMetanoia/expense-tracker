//
//  AddBalanceView.swift
//  costa
//
//  Pushed from the Wallet screen's "Add Balance" affordance. Local input
//  only — `onConfirm` hands back the entered amount so the caller can wire
//  it to whatever top-up/income API is appropriate for their flow.
//

import SwiftUI

struct AddBalanceView: View {
    @Environment(\.dismiss) private var dismiss

    /// Raw digits the user has typed, e.g. "50000". Kept as a string (not
    /// a Double) so leading/backspace editing behaves predictably.
    @State private var amountDigits: String = ""

    let currency: String
    let presetAmounts: [Double]
    let onConfirm: (Double) -> Void

    init(
        currency: String = "IDR",
        presetAmounts: [Double] = [50_000, 100_000, 500_000, 1_000_000],
        onConfirm: @escaping (Double) -> Void
    ) {
        self.currency = currency
        self.presetAmounts = presetAmounts
        self.onConfirm = onConfirm
    }

    private var amountValue: Double {
        Double(amountDigits) ?? 0
    }

    var body: some View {
        ZStack {
            CostaAuroraBackground(glowCenter: UnitPoint(x: 0.5, y: 0.05), glowColor: .blue)

            VStack(spacing: 0) {
                header

                amountCard
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                presetRow
                    .padding(.top, 24)

                Spacer(minLength: 12)

                StyledNumericKeypad(
                    onDigit: appendDigit,
                    onBackspace: {
                        if !amountDigits.isEmpty { amountDigits.removeLast() }
                    }
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)

                StyledGradientButton(
                    title: "Add Balance",
                    isDisabled: amountValue <= 0
                ) {
                    onConfirm(amountValue)
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
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

            Spacer()

            Text("Top Up Balance")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            // Balances the back button so the title stays visually centered.
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Amount card

    private var amountCard: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("Rp.")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(formattedInteger)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                Text(",00")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text("Enter Amount")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 100)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Preset chips

    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presetAmounts, id: \.self) { amount in
                    StyledAmountChip(title: "Rp " + formatted(amount)) {
                        amountDigits = String(Int(amount))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Keypad input handling

    private func appendDigit(_ digit: String) {
        amountDigits += digit
        // Strip runaway leading zeros (e.g. "0" + "5" shouldn't stay "05").
        while amountDigits.count > 1 && amountDigits.hasPrefix("0") {
            amountDigits.removeFirst()
        }
    }

    // MARK: - Formatting

    private var formattedInteger: String {
        formatted(amountValue)
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
        AddBalanceView { amount in
            print("Confirmed top up: \(amount)")
        }
    }
}
