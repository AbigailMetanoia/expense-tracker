//
//  EditNotesSheet.swift
//  costa
//
//  Presented when the user taps the "Notes" section on
//  EditReceiptDetailsView. Edits a local draft only.
//

import SwiftUI

struct EditNotesSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var notes: String
    let onSave: (String) -> Void

    init(notes: String, onSave: @escaping (String) -> Void) {
        _notes = State(initialValue: notes)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            CostaDragHandle()
                .padding(.top, 8)
                .padding(.bottom, 20)

            ScrollView {
                StyledTextArea(
                    title: "Notes",
                    placeholder: "Add Notes here....",
                    text: $notes
                )
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }

            CostaActionButtons(
                cancelTitle: "Cancel",
                saveTitle: "Save",
                cancelAction: { dismiss() },
                saveAction: {
                    onSave(notes)
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
            EditNotesSheet(notes: "Meeting with client for 2 hours", onSave: { _ in })
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
}
