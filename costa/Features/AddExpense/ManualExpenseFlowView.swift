//
//  ManualExpenseFlowView.swift
//  costa
//

import SwiftUI

enum ManualExpensePhase {
    case loading
    case edit(Expense)
    case failed(String)
}

struct ManualExpenseFlowView: View {
    @Environment(AuthController.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var phase: ManualExpensePhase
    /// When `true`, `.task` skips the real network call entirely — set
    /// automatically when `initialPhase` is provided via the init below,
    /// so Xcode Previews can jump straight to any phase without needing
    /// a signed-in `AuthController` or a live API.
    @State private var skipInitialization: Bool

    init(initialPhase: ManualExpensePhase? = nil) {
        _phase = State(initialValue: initialPhase ?? .loading)
        _skipInitialization = State(initialValue: initialPhase != nil)
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                loadingView
            case .edit(let expense):
                EditReceiptDetailsView(
                    expense: expense,
                    extraction: nil,
                    thumbnail: UIImage(systemName: "doc.text")!,
                    onRetake: {},
                    source: .manual
                )
            case .failed(let message):
                failedView(message: message)
            }
        }
        .task {
            guard !skipInitialization else { return }
            await initializeDraft()
        }
    }

    private var loadingView: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                Text("Setting up form…")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func failedView(message: String) -> some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    Button("Close") { dismiss() }
                        .buttonStyle(.bordered)
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func initializeDraft() async {
        guard let token = await auth.validToken() else {
            phase = .failed("You are not signed in.")
            return
        }

        do {
            let client = CostAPIClient(accessToken: token)
            
            let categories = try await client.listCategories()
            guard let firstCategory = categories.first else {
                phase = .failed("No expense categories available. Please set up categories first.")
                return
            }

            let today = Date()
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: today)

            let createRequest = CreateExpenseRequest(
                date: dateString,
                name: "New Expense",
                location: "",
                notes: nil,
                payment_method: "UNSPECIFIED",
                is_draft: true,
                costs: [
                    CreateExpenseCostInput(
                        name: "Item",
                        category_id: firstCategory.id ?? "",
                        amount: 0,
                        currency: "IDR"
                    )
                ]
            )

            let response = try await client.createExpense(request: createRequest)
            phase = .edit(response.expense)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Previews (no login/network needed)

#Preview("Edit form") {
    let sampleCost = Cost(
        id: "draft-1",
        user_id: nil,
        name: "Item",
        amount: 0,
        currency: "IDR",
        created_at: nil,
        updated_at: nil,
        category_id: "food",
        category: CostCategory(id: "food", emoji: "🍔", name: "Food", color: "#FF9500", is_generated_by_ai: false)
    )
    let sampleExpense = Expense(
        id: "draft-expense-1",
        name: "New Expense",
        date: "2026-09-17",
        location: "",
        payment_method: "UNSPECIFIED",
        notes: nil,
        is_draft: true,
        costs: [sampleCost]
    )

    return ManualExpenseFlowView(initialPhase: .edit(sampleExpense))
        .environment(AuthController())
}

#Preview("Loading") {
    ManualExpenseFlowView(initialPhase: .loading)
        .environment(AuthController())
}

#Preview("Failed") {
    ManualExpenseFlowView(initialPhase: .failed("No expense categories available. Please set up categories first."))
        .environment(AuthController())
}
