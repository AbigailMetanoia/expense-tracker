//
//  EditReceiptDetailsView.swift
//  costa
//
//  This screen is a READ-ONLY review of the scanned/entered receipt.
//  Tapping a section opens a dedicated sheet to edit just that part —
//  Transaction Details, an individual item, Notes, or a Tax/Service
//  charge. Edits only touch local state; the top-right "Save" button is
//  what actually persists everything to the server.
//

import SwiftUI
import UIKit
import PhotosUI

// MARK: - Editable cost line

struct EditableCost: Identifiable {
    var id: String
    var name: String
    /// String representation so the user can type freely; parsed on save.
    var amountText: String
    var currency: String
    var category_id: String?
    var category: CostCategory?

    init(
        id: String,
        name: String,
        amountText: String,
        currency: String,
        category_id: String?,
        category: CostCategory?
    ) {
        self.id = id
        self.name = name
        self.amountText = amountText
        self.currency = currency
        self.category_id = category_id
        self.category = category
    }

    init(cost: Cost) {
        id = cost.id
        name = cost.name
        let a = cost.amount
        amountText = a.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(a)) : String(a)
        currency = cost.currency
        category_id = cost.category_id
        category = cost.category
    }

    var amount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}

// MARK: - View

struct EditReceiptDetailsView: View {
    enum Source {
        case scanBill
        case manual
    }

    /// Which sub-sheet is currently presented. One enum + one `.sheet(item:)`
    /// keeps section-editing sheets from fighting over presentation state.
    private enum ActiveSheet: Identifiable {
        case transaction
        case notes
        case cost(EditableCost)
        case charge(ReceiptCharge)

        var id: String {
            switch self {
            case .transaction: "transaction"
            case .notes: "notes"
            case .cost(let cost): "cost-\(cost.id)"
            case .charge(let charge): "charge-\(charge.id)"
            }
        }
    }

    @Environment(AuthController.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let originalExpense: Expense
    let extraction: BillExtraction?
    let thumbnail: UIImage
    var onRetake: () -> Void
    var source: Source = .scanBill
    var isReadOnly: Bool = false

    @State private var expenseDate: Date
    @State private var paymentMethod: String
    @State private var location: String
    @State private var notes: String
    @State private var editCosts: [EditableCost]
    @State private var charges: [ReceiptCharge]

    @State private var isSaving = false
    @State private var saveError: String?
    @State private var transactionExpanded = true
    @State private var itemsExpanded = true
    @State private var notesExpanded = true
    @State private var summaryExpanded = true
    @State private var activeSheet: ActiveSheet?

    // MARK: Manual-entry photo attachment
    // `thumbnail` is a `let`, supplied once at init, so a locally-picked
    // replacement is tracked separately and preferred for display when
    // present. Only relevant for `source == .manual`, where there's no
    // VisionKit scan to retake — the user instead attaches an optional
    // reference photo from their library.
    @State private var pickedPhotoItem: PhotosPickerItem?
    @State private var pickedThumbnail: UIImage?

    private var displayedThumbnail: UIImage {
        pickedThumbnail ?? thumbnail
    }

    /// Reused purely for its category list/loading/add-new-category
    /// capability (same pattern as `EditCostDetailSheet`) — categories are
    /// a workspace-wide list, not derived from what's already on the
    /// receipt's items, so they still show up (with an "Add category"
    /// option) even on a freshly scanned receipt where no item has a
    /// category yet.
    @State private var categoriesViewModel: EditCostDetailViewModel

    init(
        expense: Expense,
        extraction: BillExtraction?,
        thumbnail: UIImage,
        onRetake: @escaping () -> Void,
        source: Source = .scanBill,
        isReadOnly: Bool = false
    ) {
        originalExpense = expense
        self.extraction = extraction
        self.thumbnail = thumbnail
        self.onRetake = onRetake
        self.source = source
        self.isReadOnly = isReadOnly

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        _expenseDate = State(initialValue: parser.date(from: expense.date) ?? Date())

        let pm = extraction?.payment_method ?? expense.payment_method ?? "UNSPECIFIED"
        _paymentMethod = State(initialValue: pm)

        let loc = extraction?.location?.isEmpty == false
            ? extraction!.location!
            : (expense.location ?? "")
        _location = State(initialValue: loc)
        _notes = State(initialValue: expense.notes ?? "")
        _editCosts = State(initialValue: expense.costs.map { EditableCost(cost: $0) })

        // NOTE: tax/service charges aren't part of the `Expense`/`Cost`
        // models yet, so they start with sensible defaults rather than
        // being loaded from the server. Wire this up to real persisted
        // fields once the backend supports it.
        _charges = State(initialValue: [
            ReceiptCharge(type: .tax, mode: .percentage, value: 10),
            ReceiptCharge(type: .service, mode: .fixed, value: 0)
        ])

        // Any real Cost works here — it's only used as a vehicle to reach
        // the shared category list, never saved itself.
        let placeholderCost = expense.costs.first ?? Cost(
            id: "placeholder",
            user_id: nil,
            name: "",
            amount: 0,
            currency: "IDR",
            created_at: nil,
            updated_at: nil,
            category_id: nil,
            category: nil
        )
        _categoriesViewModel = State(initialValue: EditCostDetailViewModel(cost: placeholderCost))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                Section {
                    headerCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                transactionCard
                itemsCard
                notesCard
                summaryCard
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(12)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .transaction:
                    EditTransactionDetailsSheet(
                        date: expenseDate,
                        paymentMethod: paymentMethod,
                        location: location,
                        onSave: { newDate, newPaymentMethod, newLocation in
                            expenseDate = newDate
                            paymentMethod = newPaymentMethod
                            location = newLocation
                        }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)

                case .notes:
                    EditNotesSheet(
                        notes: notes,
                        onSave: { notes = $0 }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)

                case .cost(let cost):
                    let costModel = Cost(
                        id: cost.id,
                        user_id: nil,
                        name: cost.name,
                        amount: cost.amount,
                        currency: cost.currency,
                        created_at: nil,
                        updated_at: nil,
                        category_id: cost.category_id,
                        category: cost.category
                    )
                    EditCostDetailSheet(cost: costModel, onSaved: { updated in
                        if let i = editCosts.firstIndex(where: { $0.id == updated.id }) {
                            editCosts[i] = EditableCost(cost: updated)
                        } else {
                            editCosts.append(EditableCost(cost: updated))
                        }
                    })

                case .charge(let charge):
                    EditSummaryChargeSheet(
                        charge: charge,
                        currency: editCosts.first?.currency ?? "IDR",
                        onSave: { updated in
                            if let i = charges.firstIndex(where: { $0.id == updated.id }) {
                                charges[i] = updated
                            }
                        }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 20)
            }
            .task {
                guard let token = await auth.validToken() else { return }
                await categoriesViewModel.loadCategories(accessToken: token)
            }
            .onChange(of: pickedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        pickedThumbnail = image
                    }
                }
            }
            .sheet(isPresented: $categoriesViewModel.isAddingCategory) {
                CategoryFormSheet(
                    currency: editCosts.first?.currency ?? "IDR",
                    isSaving: categoriesViewModel.isLoading,
                    onSave: { name, emoji, colorHex, _ in
                        // NOTE: budget-per-category isn't wired up yet —
                        // see CategoryFormSheet's doc comment.
                        categoriesViewModel.newCategoryName = name
                        categoriesViewModel.newCategoryEmoji = emoji
                        categoriesViewModel.newCategoryColor = colorHex
                        Task {
                            guard let token = await auth.validToken() else { return }
                            await categoriesViewModel.addCategory(accessToken: token)
                        }
                    }
                )
            }
            .navigationTitle("Receipt Detail")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Back")
                }
                if !isReadOnly {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task { await performSave() }
                        }
                        label: {
                            Group {
                                if isSaving {
                                    ProgressView()
                                        .controlSize(.mini)
                                        .tint(.white)
                                } else {
                                    Text("Save")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(isSaving)
                        .tint(.blue)
                    }
                }
            }
            .alert("Save Failed", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                if let err = saveError { Text(err) }
            }
        }
    }

    // MARK: - Header card

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnailOverlay

            VStack(alignment: .center, spacing: 15) {
                if extraction != nil && source == .scanBill {
                    StyledStatusBadge(text: "Auto-detected", tint: .darkGreen)
                }

                // Category stays an inline dropdown (not a sub-sheet) since
                // it's a quick single choice, not a multi-field edit.
                // Always shown — even with zero categories yet — so the
                // user has a way to create the first one.
                if categoriesViewModel.categories.isEmpty {
                    Button {
                        categoriesViewModel.isAddingCategory = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                            Text("Add category")
                                .font(.subheadline.weight(.regular))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                        .background(Color(uiColor: .secondarySystemFill), in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    StyledSelectField(
                        title: "Category", titleIcon: "square.grid.2x2.fill",
                        selection: overallCategoryBinding,
                        options: categoriesViewModel.categories,
                        optionLabel: { $0.name },
                        onAddNew: { categoriesViewModel.isAddingCategory = true }
                    )
                }
            }
        }
        .padding(16)
        .receiptCard()
    }

    private var overallCategoryBinding: Binding<CostCategory> {
        Binding(
            get: { editCosts.first?.category ?? categoriesViewModel.categories[0] },
            set: { newValue in
                for i in editCosts.indices {
                    editCosts[i].category = newValue
                    editCosts[i].category_id = newValue.id
                }
            }
        )
    }

    private var thumbnailOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(uiImage: displayedThumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 98, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            switch source {
            case .scanBill:
                Button(action: onRetake) {
                    thumbnailActionIcon("camera.fill")
                }
                .offset(x: -5, y: 4)
                .accessibilityLabel("Retake photo")

            case .manual:
                // No VisionKit scan to retake here — instead, let the user
                // optionally attach a reference photo from their library.
                PhotosPicker(selection: $pickedPhotoItem, matching: .images) {
                    thumbnailActionIcon(pickedThumbnail == nil ? "photo.badge.plus" : "camera.fill")
                }
                .offset(x: -5, y: 4)
                .accessibilityLabel(pickedThumbnail == nil ? "Add photo" : "Change photo")
            }
        }
    }

    /// Shared visual style for the small circular action button overlaid
    /// on the receipt thumbnail, so retake (scan) and add-photo (manual)
    /// look consistent.
    private func thumbnailActionIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(.blue)
            .frame(width: 35, height: 35)
            .background(.white.opacity(0.1), in: Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
    }

    // MARK: - Transaction details card (read-only, taps open the edit sheet)

    private var transactionCard: some View {
        Section {
            if transactionExpanded {
                readOnlyRow(label: "Date", value: expenseDate.formatted(date: .abbreviated, time: .omitted))
                readOnlyRow(label: "Payment Method", value: PaymentMethodOption(rawValue: paymentMethod)?.displayName ?? paymentMethod)
                readOnlyRow(label: "Location", value: location.isEmpty ? "—" : location)
            }
        } header: {
            sectionHeader(icon: "calendar", title: "Transaction Details", isExpanded: $transactionExpanded)
                .textCase(nil)
                .listRowInsets(EdgeInsets())
        }
    }

    private func readOnlyRow(label: String, value: String) -> some View {
        Button {
            if !isReadOnly { activeSheet = .transaction }
        } label: {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .rowPadding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
    }

    // MARK: - Items card

    private var itemsCard: some View {
        Section {
            if itemsExpanded {
                if editCosts.isEmpty {
                    VStack(spacing: 10) {
                        Text("No items extracted")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)

                        if !isReadOnly {
                            Button {
                                activeSheet = .cost(makeNewCostDraft())
                            } label: {
                                Label("Add item", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(16)
                    .listRowInsets(EdgeInsets())
                } else {
                    ForEach(editCosts) { cost in
                        Button(action: { activeSheet = .cost(cost) }) {
                            HStack(spacing: 10) {
                                Text("1x")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, height: 28)
                                    .background(.secondary.opacity(0.15), in: Circle())

                                Text(cost.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(cost.amountText)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: 90, alignment: .trailing)
                            }
                            .rowPadding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if !isReadOnly {
                                Button(role: .destructive) {
                                    deleteCost(cost)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets())
                    }
                }
            }
        } header: {
            sectionHeader(icon: "bag.fill", title: "Items", isExpanded: $itemsExpanded)
                .textCase(nil)
                .listRowInsets(EdgeInsets())
        }
    }

    // MARK: - Notes card

    private var notesCard: some View {
        Section {
            if notesExpanded {
                Button {
                    if !isReadOnly { activeSheet = .notes }
                } label: {
                    Text(notes.isEmpty ? "Add a note…" : notes)
                        .font(.subheadline)
                        .foregroundStyle(notes.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .rowPadding()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
            }
        } header: {
            sectionHeader(icon: "doc.text.fill", title: "Notes", isExpanded: $notesExpanded)
                .textCase(nil)
                .listRowInsets(EdgeInsets())
        }
    }

    // MARK: - Summary card

    private var subtotal: Double {
        editCosts.reduce(0) { $0 + $1.amount }
    }

    private var grandTotal: Double {
        subtotal + charges.reduce(0) { $0 + $1.amount(subtotal: subtotal) }
    }

    private var summaryCard: some View {
        let currency = editCosts.first?.currency ?? "IDR"

        return Section {
            if summaryExpanded {
                StyledSummaryRow(
                    label: "Subtotal",
                    value: formatAmount(subtotal, currency: currency)
                )
                .rowPadding()
                .listRowInsets(EdgeInsets())

                ForEach(charges) { charge in
                    Button {
                        if !isReadOnly { activeSheet = .charge(charge) }
                    } label: {
                        StyledSummaryRow(
                            label: chargeLabel(charge),
                            value: formatAmount(charge.amount(subtotal: subtotal), currency: currency),
                            infoText: charge.type == .tax && charge.mode == .percentage
                                ? "Calculated automatically from the subtotal."
                                : nil
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .rowPadding()
                    .listRowInsets(EdgeInsets())
                }

//                Divider()
//                    .padding(.horizontal, 16)

                StyledSummaryRow(
                    label: "Total",
                    value: "Rp " + formatAmount(grandTotal, currency: currency),
                    emphasized: true
                )
                .rowPadding()
                .listRowInsets(EdgeInsets())
            }
        } header: {
            sectionHeader(
                icon: "chart.pie.fill",
                title: "Summary",
                subtitle: "Auto Calculated",
                isExpanded: $summaryExpanded
            )
            .textCase(nil)
            .listRowInsets(EdgeInsets())
        }
    }

    private func chargeLabel(_ charge: ReceiptCharge) -> String {
        if charge.type == .tax, charge.mode == .percentage {
            let percent = charge.value.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(charge.value))
                : String(charge.value)
            return "Tax (\(percent)%)"
        }
        return charge.type.rawValue
    }

    // MARK: - Section header builder

    @ViewBuilder
    private func sectionHeader(
        icon: String,
        title: String,
        subtitle: String? = nil,
        isExpanded: Binding<Bool>
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { isExpanded.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.blue)

                if let subtitle {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.headline)
                        Text("(\(subtitle))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(title)
                        .font(.headline)
                }

                Spacer()

                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .rowPadding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
    }

    // MARK: - Save

    private func performSave() async {
        guard let token = await auth.validToken() else {
            saveError = "You are not signed in."
            return
        }

        isSaving = true
        defer { isSaving = false }

        let dateStr = isoDateString(from: expenseDate)
        let patch = ExpensePatch(
            name: originalExpense.name,
            date: dateStr,
            location: location,
            notes: notes.isEmpty ? nil : notes,
            payment_method: paymentMethod,
            is_draft: false
        )

        let client = CostAPIClient(accessToken: token)

        do {
            _ = try await client.patchExpense(id: originalExpense.id, patch: patch)

            for editCost in editCosts {
                guard let original = originalExpense.costs.first(where: { $0.id == editCost.id }) else { continue }
                let nameChanged = editCost.name != original.name
                let amountChanged = abs(editCost.amount - original.amount) > 0.001
                let categoryChanged = editCost.category_id != original.category_id
                guard nameChanged || amountChanged || categoryChanged else { continue }
                _ = try await client.patchCost(
                    id: editCost.id,
                    patch: CostPatch(
                        name: editCost.name,
                        amount: editCost.amount,
                        currency: editCost.currency,
                        category_id: editCost.category_id
                    )
                )
            }

            // Items removed locally (via swipe-to-delete) also need to be
            // deleted server-side — without this, "deleting" an item only
            // ever removed it from the on-screen list, and it would come
            // back the next time this receipt was loaded.
            // NOTE: `client.deleteCost(id:)` is assumed to match your
            // `CostAPIClient`'s naming — rename this call if your actual
            // delete method is named differently.
            let remainingIds = Set(editCosts.map(\.id))
            for original in originalExpense.costs where !remainingIds.contains(original.id) {
                try await client.deleteCost(id: original.id)
            }

            // NOTE: `charges` (tax/service) aren't persisted yet — see the
            // comment on `_charges` in `init`. Add the corresponding API
            // call here once the backend model supports it.

            // NOTE: `pickedThumbnail` (manual entry's optional attached
            // photo) isn't uploaded anywhere yet — there's no receipt-image
            // endpoint in `CostAPIClient` currently. Wire this up once the
            // backend supports attaching an image to an `Expense`.

            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func formatAmount(_ amount: Double, currency: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "id_ID")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }

    private func isoDateString(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func deleteCost(_ cost: EditableCost) {
        withAnimation {
            editCosts.removeAll { $0.id == cost.id }
        }
    }

    private func makeNewCostDraft() -> EditableCost {
        EditableCost(
            id: UUID().uuidString,
            name: "",
            amountText: "0",
            currency: editCosts.first?.currency ?? originalExpense.costs.first?.currency ?? "IDR",
            category_id: nil,
            category: nil
        )
    }
}

// MARK: - View modifiers

private extension View {
    func receiptCard() -> some View {
        self
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
    }

    func rowPadding() -> some View {
        self.padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// MARK: - Preview

#Preview {
    let sampleCosts: [Cost] = [
        Cost(id: "c1", name: "Venti Mocha Latte", amount: 50_000, currency: "IDR"),
        Cost(id: "c2", name: "Oat Milk",          amount: 50_000, currency: "IDR"),
        Cost(id: "c3", name: "Venti",              amount: 50_000, currency: "IDR"),
        Cost(id: "c4", name: "Gr White Mocha",     amount: 50_000, currency: "IDR")
    ]
    let expense = Expense(
        id: "e1",
        name: "Starbucks",
        date: "2026-05-25",
        location: "Jakarta, Indonesia",
        payment_method: "CREDIT_CARD",
        notes: "Meeting with client",
        is_draft: true,
        costs: sampleCosts
    )
    let extraction = BillExtraction(
        merchant: "Starbucks",
        transaction_date: "2026-05-25",
        location: "Jakarta, Indonesia",
        payment_method: "CREDIT_CARD",
        line_count: 4
    )
    EditReceiptDetailsView(
        expense: expense,
        extraction: extraction,
        thumbnail: UIImage(systemName: "doc.text.viewfinder")!,
        onRetake: {}
    )
    .environment(AuthController())
}

#Preview("Manual Entry") {
    let sampleCosts: [Cost] = [
        Cost(id: "c1", name: "Nasi Goreng", amount: 25_000, currency: "IDR")
    ]
    let expense = Expense(
        id: "e2",
        name: "Manual Expense",
        date: "2026-09-18",
        location: "",
        payment_method: nil,
        notes: nil,
        is_draft: true,
        costs: sampleCosts
    )
    EditReceiptDetailsView(
        expense: expense,
        extraction: nil,
        thumbnail: UIImage(systemName: "doc.text.viewfinder")!,
        onRetake: {},
        source: .manual
    )
    .environment(AuthController())
}

#Preview("Manual Entry, Read Only") {
    let sampleCosts: [Cost] = [
        Cost(id: "c1", name: "Nasi Goreng", amount: 25_000, currency: "IDR")
    ]
    let expense = Expense(
        id: "e3",
        name: "Manual Expense",
        date: "2026-09-18",
        location: "",
        payment_method: nil,
        notes: nil,
        is_draft: false,
        costs: sampleCosts
    )
    EditReceiptDetailsView(
        expense: expense,
        extraction: nil,
        thumbnail: UIImage(systemName: "doc.text.viewfinder")!,
        onRetake: {},
        source: .manual,
        isReadOnly: true
    )
    .environment(AuthController())
}
