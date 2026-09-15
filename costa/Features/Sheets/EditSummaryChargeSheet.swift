//
//  EditSummaryChargeSheet.swift
//  costa
//
//  Presented when the user taps the "Tax" or "Service Charge" row in the
//  Summary section on EditReceiptDetailsView. A single sheet handles both,
//  since they're really the same kind of thing (a named charge that's
//  either a percentage of the subtotal or a fixed amount).
//

import SwiftUI

// MARK: - Model

/// A named charge applied on top of the item subtotal (tax, service
/// charge, etc). `value` means different things depending on `mode`:
/// a percentage (0–100) when `.percentage`, or a currency amount when `.fixed`.
struct ReceiptCharge: Identifiable, Hashable {
    enum ChargeType: String, CaseIterable, Hashable {
        case tax = "Tax"
        case service = "Service Charge"
    }

    enum AmountMode: String, CaseIterable, Hashable {
        case percentage = "Percentage"
        case fixed = "Fix Amount"
    }

    var id = UUID()
    var type: ChargeType
    var mode: AmountMode
    var value: Double

    /// Resolves this charge to a currency amount given the receipt's subtotal.
    func amount(subtotal: Double) -> Double {
        switch mode {
        case .percentage: subtotal * (value / 100)
        case .fixed: value
        }
    }
}

// MARK: - Sheet

struct EditSummaryChargeSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var type: ReceiptCharge.ChargeType
    @State private var mode: ReceiptCharge.AmountMode
    @State private var valueText: String

    let currency: String
    let onSave: (ReceiptCharge) -> Void

    private let chargeId: UUID

    init(charge: ReceiptCharge, currency: String, onSave: @escaping (ReceiptCharge) -> Void) {
        chargeId = charge.id
        _type = State(initialValue: charge.type)
        _mode = State(initialValue: charge.mode)
        _valueText = State(initialValue: charge.value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(charge.value))
            : String(charge.value))
        self.currency = currency
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            CostaDragHandle()
                .padding(.top, 8)
                .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    StyledSelectField(
                        title: "Type",
                        selection: $type,
                        options: ReceiptCharge.ChargeType.allCases,
                        optionLabel: { $0.rawValue }
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)

                        StyledSegmentedToggle(
                            selection: $mode,
                            options: ReceiptCharge.AmountMode.allCases,
                            label: { $0.rawValue }
                        )

                        StyledTextField(
                            title: "",
                            placeholder: "0",
                            text: $valueText,
                            leadingText: mode == .fixed ? currency : nil,
                            trailingText: mode == .percentage ? "%" : nil,
                            keyboardType: .decimalPad
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }

            CostaActionButtons(
                cancelTitle: "Cancel",
                saveTitle: "Save",
                cancelAction: { dismiss() },
                saveAction: {
                    let value = Double(valueText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    onSave(ReceiptCharge(id: chargeId, type: type, mode: mode, value: value))
                    dismiss()
                }
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    Color(.systemBackground)
        .sheet(isPresented: .constant(true)) {
            EditSummaryChargeSheet(
                charge: ReceiptCharge(type: .tax, mode: .percentage, value: 10),
                currency: "IDR",
                onSave: { _ in }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
}
