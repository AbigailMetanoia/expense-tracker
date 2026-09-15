//
//  EditTransactionDetailsSheet.swift
//  costa
//
//  Presented when the user taps the "Transaction Details" section on
//  EditReceiptDetailsView. Edits a local draft only — nothing is sent to
//  the server until the parent screen's top-level Save is tapped.
//

import SwiftUI

struct EditTransactionDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var paymentMethod: String
    @State private var location: String

    let onSave: (_ date: Date, _ paymentMethod: String, _ location: String) -> Void

    init(
        date: Date,
        paymentMethod: String,
        location: String,
        onSave: @escaping (_ date: Date, _ paymentMethod: String, _ location: String) -> Void
    ) {
        _date = State(initialValue: date)
        _paymentMethod = State(initialValue: paymentMethod)
        _location = State(initialValue: location)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            CostaDragHandle()
                .padding(.top, 8)
                .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    StyledDateField(title: "Date", date: $date)

                    StyledSelectField(
                        title: "Payment Method",
                        selection: $paymentMethod,
                        options: PaymentMethodOption.allCases.map(\.rawValue),
                        optionLabel: { raw in PaymentMethodOption(rawValue: raw)?.displayName ?? raw }
                    )

                    StyledTextField(
                        title: "Location",
                        placeholder: "e.g Starbucks",
                        text: $location
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }

            CostaActionButtons(
                cancelTitle: "Cancel",
                saveTitle: "Save",
                cancelAction: { dismiss() },
                saveAction: {
                    onSave(date, paymentMethod, location)
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
            EditTransactionDetailsSheet(
                date: Date(),
                paymentMethod: "CREDIT_CARD",
                location: "Jakarta, Indonesia",
                onSave: { _, _, _ in }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
}
