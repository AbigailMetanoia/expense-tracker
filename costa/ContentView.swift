//
//  ContentView.swift
//  costa
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthController.self) private var auth

    var body: some View {
        if auth.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

// MARK: - Main tab shell

struct MainTabView: View {
    enum Tab: Int, CaseIterable {
        case home, spending, wallet

        var icon: String {
            switch self {
            case .home:     "house.fill"
            case .spending: "doc.text.fill"
            case .wallet:   "wallet.bifold.fill"
            }
        }

        var label: String {
            switch self {
            case .home:     "Home"
            case .spending: "Spending"
            case .wallet:   "Wallet"
            }
        }
    }

    @State private var selected: Tab = .home
    @State private var showAddExpenseOptions = false
    @State private var showReceiptCapture = false
    @State private var showManualEntry = false
    @State private var selectedCost: Cost?
    /// Bump after editing a cost from the home sheet so lists and chart reload.
    @State private var homeCostsRefreshToken = 0
    @Namespace private var pillNS

    /// What to present once `AddExpenseOptionsSheet` has FULLY dismissed.
    /// Setting `showReceiptCapture`/`showManualEntry` directly from inside
    /// the sheet's button action races with the sheet's own dismiss
    /// animation (both are triggered in the same tick), which is what
    /// caused the ghosted/overlapping-sheet visual glitch. Routing through
    /// `.sheet(onDismiss:)` guarantees the old sheet is completely gone
    /// before the next presentation starts.
    private enum PendingAction { case receiptCapture, manualEntry }
    @State private var pendingAction: PendingAction?

    var body: some View {
        // Stable ZStack keeps all views in the tree so the safeAreaInset
        // never re-layouts and the tab bar never flickers on switch.
        ZStack {
            HomeView(selectedCost: $selectedCost, refreshCostsToken: homeCostsRefreshToken)
                .opacity(selected == .home ? 1 : 0)
                .allowsHitTesting(selected == .home)
            SpendingView()
                .opacity(selected == .spending ? 1 : 0)
                .allowsHitTesting(selected == .spending)
            WalletView()
                .opacity(selected == .wallet ? 1 : 0)
                .allowsHitTesting(selected == .wallet)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(
                selected: $selected,
                showAddSheet: $showAddExpenseOptions,
                namespace: pillNS
            )
        }
        .sheet(isPresented: $showAddExpenseOptions, onDismiss: {
            switch pendingAction {
            case .receiptCapture: showReceiptCapture = true
            case .manualEntry: showManualEntry = true
            case nil: break
            }
            pendingAction = nil
        }) {
            AddExpenseOptionsSheet(
                isPresented: $showAddExpenseOptions,
                onSnapReceipt: { pendingAction = .receiptCapture },
                onEnterManually: { pendingAction = .manualEntry }
            )
            .presentationDetents([.height(440), .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showReceiptCapture) {
            ReceiptCaptureFlowView()
        }
        .fullScreenCover(isPresented: $showManualEntry) {
            ManualExpenseFlowView()
        }
        .sheet(item: $selectedCost) { cost in
            EditCostDetailSheet(cost: cost, onSaved: { _ in
                homeCostsRefreshToken += 1
            })
        }
    }
}

// MARK: - Tab bar

private struct TabBar: View {
    @Binding var selected: MainTabView.Tab
    @Binding var showAddSheet: Bool
    var namespace: Namespace.ID

    /// Tint tipis di atas material blur — turunin/naikin `opacity` di sini
    /// untuk atur seberapa "tembus pandang" glass effect-nya ke background.
    private let barTint = Color(red: 0.07, green: 0.09, blue: 0.13).opacity(0.35)
    private let barStroke = Color.white.opacity(0.08)

    var body: some View {
        HStack(spacing: 12) {
            // Sliding pill group
            HStack(spacing: 4) {
                ForEach(MainTabView.Tab.allCases, id: \.self) { tab in
                    TabPill(tab: tab, selected: selected, namespace: namespace) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                            selected = tab
                        }
                    }
                }
            }
            .padding(6)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(barTint))
            }
            .overlay(Capsule().strokeBorder(barStroke, lineWidth: 1))

            // FAB
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().fill(barTint))
                    }
                    .overlay(Circle().strokeBorder(barStroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }
}

// MARK: - Individual pill button

private struct TabPill: View {
    let tab: MainTabView.Tab
    let selected: MainTabView.Tab
    let namespace: Namespace.ID
    let onTap: () -> Void

    private var isSelected: Bool { tab == selected }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .semibold))
                if isSelected {
                    Text(tab.label)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, isSelected ? 16 : 14)
            .background {
                // The pill is ALWAYS in the view tree for all tabs;
                // opacity drives which one is visible so matchedGeometryEffect
                // can smoothly interpolate position/size between any two tabs.
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .matchedGeometryEffect(id: "pill", in: namespace, isSource: isSelected)
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isSelected)
    }
}

#Preview {
    ContentView()
        .environment(AuthController())
}
