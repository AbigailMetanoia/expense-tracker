//
//  StyledFormControls.swift
//  costa
//

import SwiftUI
import UIKit

// MARK: - Color+Hex

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("#") else { return nil }
        s.removeFirst()
        if s.count == 3 {
            s = s.map { String(repeating: $0, count: 2) }.joined()
        }
        guard let n = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((n >> 24) & 0xFF) / 255
            g = Double((n >> 16) & 0xFF) / 255
            b = Double((n >> 8) & 0xFF) / 255
            a = Double(n & 0xFF) / 255
        } else if s.count == 6 {
            r = Double((n >> 16) & 0xFF) / 255
            g = Double((n >> 8) & 0xFF) / 255
            b = Double(n & 0xFF) / 255
            a = 1
        } else {
            return nil
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return nil }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

private let fieldShape = Capsule(style: .continuous)
private let fieldFill = Color(uiColor: .secondarySystemFill)

// MARK: - StyledTextField

struct StyledTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var leadingText: String?
    var trailingText: String?
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrectionDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)

            HStack(spacing: 10) {
                if let leadingText {
                    Text(leadingText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(CostaColors.sheetFieldFill, in: fieldShape)
                        .fixedSize(horizontal: true, vertical: false)
                }

                HStack(spacing: 6) {
                    Group {
                        if isSecure {
                            SecureField(placeholder, text: $text)
                        } else {
                            TextField(placeholder, text: $text)
                        }
                    }
                    .font(.body)
                    .foregroundStyle(.primary)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(autocorrectionDisabled)

                    if let trailingText {
                        Text(trailingText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .frame(height: 48)
                .frame(maxWidth: .infinity)
                .background(CostaColors.sheetFieldFill, in: fieldShape)
            }
        }
    }
}

// MARK: - StyledSelectField

enum StyledSelectFieldStyle {
    case system
    case solidDark
}

struct StyledSelectField<Option: Hashable>: View {
    var title: String? = nil
    var titleIcon: String? = nil
    @Binding var selection: Option
    let options: [Option]
    let optionLabel: (Option) -> String
    var onAddNew: (() -> Void)?
    var style: StyledSelectFieldStyle = .system

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let titleIcon {
                Image(systemName: titleIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
            } else if let title {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            ZStack {
                selectLabel(text: optionLabel(selection))
                    .allowsHitTesting(false)

                SelectMenuControl(
                    selection: $selection,
                    options: options,
                    optionLabel: optionLabel,
                    onAddNew: onAddNew
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
    }

    @ViewBuilder
    private func selectLabel(text: String) -> some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.body)
                .foregroundStyle(style == .solidDark ? .white : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.down")
                .font(.title3.weight(.semibold))
                .foregroundStyle(style == .solidDark ? .white : .primary)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(style == .solidDark ? Color.black : CostaColors.sheetFieldFill, in: fieldShape)
    }
}

private struct SelectMenuControl<Option: Hashable>: UIViewRepresentable {
    @Binding var selection: Option
    let options: [Option]
    let optionLabel: (Option) -> String
    var onAddNew: (() -> Void)?

    func makeUIView(context: Context) -> TrailingMenuButton {
        let button = TrailingMenuButton(type: .system)
        button.backgroundColor = .clear
        button.showsMenuAsPrimaryAction = true
        return button
    }

    func updateUIView(_ button: TrailingMenuButton, context: Context) {
        var actions: [UIMenuElement] = options.map { option in
            UIAction(
                title: optionLabel(option),
                image: selection == option
                    ? UIImage(systemName: "checkmark")
                    : nil
            ) { _ in
                selection = option
            }
        }

        if let onAddNew {
            actions.append(
                UIAction(
                    title: "Add new…",
                    image: UIImage(systemName: "plus.circle.fill"),
                    attributes: []
                ) { _ in
                    onAddNew()
                }
            )
        }

        button.menu = UIMenu(children: actions)
    }
}

final class TrailingMenuButton: UIButton {
    override func menuAttachmentPoint(for configuration: UIContextMenuConfiguration) -> CGPoint {
        CGPoint(x: bounds.maxX, y: bounds.minY)
    }
}

// MARK: - GlassMenuPicker

struct GlassMenuPicker<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String

    var body: some View {
        ZStack {
            GlassMenuLabel(text: label(selection))
                .allowsHitTesting(false)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selection = option
                        }
                    } label: {
                        Label(
                            label(option),
                            systemImage: selection == option ? "checkmark" : ""
                        )
                    }
                }
            } label: {
                GlassMenuLabel(text: label(selection))
                    .opacity(0)
            }
            .menuStyle(.borderlessButton)
            .tint(.primary)
        }
        .fixedSize()
    }
}

struct GlassMenuLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.45), Color.white.opacity(0.10)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.7), Color(uiColor: .separator).opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Sheet chrome

struct CostaDragHandle: View {
    var body: some View {
        Capsule()
            .fill(Color(uiColor: .tertiaryLabel))
            .frame(width: 36, height: 5)
    }
}

struct CostaActionButtons: View {
    let cancelTitle: String
    let saveTitle: String
    var isSaveDisabled: Bool = false
    let cancelAction: () -> Void
    let saveAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: cancelAction) {
                Text(cancelTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(fieldFill, in: fieldShape)
            }
            .buttonStyle(.plain)

            Button(action: saveAction) {
                Text(saveTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor.opacity(isSaveDisabled ? 0.4 : 1), in: fieldShape)
            }
            .buttonStyle(.plain)
            .disabled(isSaveDisabled)
        }
    }
}

// MARK: - StyledSummaryRow

struct StyledSummaryRow: View {
    let label: String
    let value: String
    var infoText: String?
    var emphasized: Bool = false
    var tint: Color = .primary

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(label)
                .font(emphasized ? .headline : .subheadline)
                .foregroundStyle(emphasized ? .primary : .secondary)

            if let infoText {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(infoText)
            }

            Spacer()

            Text(value)
                .font(emphasized ? .headline : .subheadline)
                .foregroundStyle(tint)
        }
    }
}

// MARK: - StyledStatusBadge

struct StyledStatusBadge: View {
    let text: String
    var systemImage: String = "checkmark"
    var tint: Color = .green

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption.weight(.semibold))
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12))
        .overlay(Capsule().stroke(tint, lineWidth: 1))
        .clipShape(.capsule)
    }
}

// MARK: - StyledDateField

struct StyledDateField: View {
    let title: String
    @Binding var date: Date
    var displayedComponents: DatePickerComponents = [.date, .hourAndMinute]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)

            ZStack {
                HStack {
                    Text(formatted)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .frame(height: 48)
                .background(CostaColors.sheetFieldFill, in: fieldShape)
                .allowsHitTesting(false)

                DatePicker("", selection: $date, displayedComponents: displayedComponents)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .blendMode(.destinationOver)
                    .opacity(0.011)
            }
            .frame(height: 48)
        }
    }

    private var formatted: String {
        if displayedComponents.contains(.hourAndMinute) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - StyledTextArea

struct StyledTextArea: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(Color(uiColor: .placeholderText))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 25)
                    .foregroundStyle(.primary)
            }
            .frame(minHeight: minHeight)
            .background(CostaColors.sheetFieldFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - StyledSegmentedToggle

struct StyledSegmentedToggle<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Text(label(option))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selection == option ? fieldFill : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - CostaAuroraBackground

struct CostaAuroraBackground: View {
    var glowCenter: UnitPoint = .init(x: 0.5, y: 0.3)
    var glowColor: Color = .blue

    var body: some View {
        ZStack {
            CostaColors.appBackground
            RadialGradient(
                colors: [glowColor.opacity(0.20), glowColor.opacity(0.20), Color.clear],
                center: glowCenter,
                startRadius: 10,
                endRadius: 220
            )
            .blur(radius: 60)
        }
        .ignoresSafeArea()
    }
}

// MARK: - StyledGradientButton

struct StyledGradientButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(CostaColors.gradient, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.6 : 1)
    }
}

// MARK: - CostaImageBackground

struct CostaImageBackground: View {
    let imageName: String
    var alignment: Alignment = .center

    var body: some View {
        GeometryReader { proxy in
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: alignment)
                .clipped()
        }
        .ignoresSafeArea()
    }
}

// MARK: - StyledNumericKeypad

struct StyledNumericKeypad: View {
    let onDigit: (String) -> Void
    let onBackspace: () -> Void

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["000", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        Button {
            if key == "⌫" {
                onBackspace()
            } else {
                onDigit(key)
            }
        } label: {
            Group {
                if key == "⌫" {
                    Image(systemName: "delete.left")
                } else {
                    Text(key)
                }
            }
            .font(.title2.weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - StyledAmountChip

struct StyledAmountChip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - StyledTransactionRow

struct StyledTransactionRow: View {
    let emoji: String
    let colorHex: String?
    let title: String
    let subtitle: String
    let amountText: String
    var date: Date? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(CostaColors.circleContainer)
                    .frame(width: 50, height: 50)
                Text(emoji)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                if let date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            Text(amountText)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primary)
        }
        .padding(14)
        .background(CostaColors.containerBackground.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - StyledCategoryAmountRow

struct StyledCategoryAmountRow: View {
    let emoji: String
    let title: String
    let amountText: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(CostaColors.circleContainer)
                    .frame(width: 44, height: 44)
                Text(emoji)
                    .font(.title3)
            }

            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            Text(amountText)
                .font(.body.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(16)
        .background(CostaColors.containerBackground.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - StyledPillMenuPicker

struct StyledPillMenuPicker<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(label(option)) {
                    selection = option
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(label(selection))
                    .font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(CostaColors.containerBackground.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CostaColors

enum CostaColors {
    static let appBackground = Color(hex: "#00071F")!
    static let containerBackground = Color(hex: "#A5C2FF")!
    static let containerFill = containerBackground.opacity(0.12)
    static let red = Color(hex: "#FF0004")!
    static let green = Color(hex: "#155728")!
    static let circleContainer = Color(hex: "#0C111C")!
    /// Fill for text fields / dropdowns inside sheets (StyledTextField,
    /// StyledSelectField, StyledDateField, StyledTextArea) — a light
    /// lavender at low opacity, distinct from the bluish `containerFill`
    /// used for page-level cards/lists.
    static let sheetFieldFill = Color(hex: "#E8DEF8")!.opacity(0.08)
    static let gradientStart = Color(hex: "#0055FF")!
    static let gradientEnd = Color(hex: "#7E91FF")!
    static let gradient = LinearGradient(
        colors: [gradientStart, gradientEnd],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let mainBlue = Color(hex: "#0B5AFE")!
    static let blueShades: [Color] = [
        Color(hex: "#0B5AFE")!,
        Color(hex: "#3D7DFF")!,
        Color(hex: "#6F9FFF")!,
        Color(hex: "#9DBBFF")!,
        Color(hex: "#C6D8FF")!,
        Color(hex: "#083FB8")!
    ]
}

#Preview("CostaAuroraBackground") {
    CostaAuroraBackground(glowCenter: UnitPoint(x: 0.5, y: 0.05), glowColor: .blue)
}

#Preview("Gallery — Form Components") {
    enum Category: String, CaseIterable { case food = "Food", transport = "Transport", utilities = "Utilities" }
    enum AmountMode: String, CaseIterable, Hashable { case percentage = "Percentage", fixed = "Fix Amount" }

    struct Demo: View {
        @State private var name = "Venti Mocha Latte"
        @State private var password = ""
        @State private var unitPrice = "50.000"
        @State private var category: Category = .food
        @State private var date = Date()
        @State private var notes = ""
        @State private var mode: AmountMode = .percentage

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CostaDragHandle().frame(maxWidth: .infinity)

                    StyledTextField(title: "Name", placeholder: "Enter item name", text: $name)
                    StyledTextField(title: "Password", placeholder: "Password", text: $password, isSecure: true)
                    StyledTextField(title: "Unit Price", placeholder: "0", text: $unitPrice, leadingText: "IDR", trailingText: "IDR")

                    StyledSelectField(
                        title: "Category",
                        selection: $category,
                        options: Category.allCases,
                        optionLabel: { $0.rawValue },
                        onAddNew: {}
                    )

                    StyledDateField(title: "Date", date: $date)

                    StyledSegmentedToggle(selection: $mode, options: AmountMode.allCases) { $0.rawValue }

                    StyledTextArea(title: "Notes", placeholder: "Add Notes here....", text: $notes)

                    VStack(spacing: 10) {
                        StyledSummaryRow(label: "Subtotal", value: "Rp 150.000")
                        StyledSummaryRow(label: "Tax (10%)", value: "Rp 15.000", infoText: "Calculated from subtotal.")
                        Divider()
                        StyledSummaryRow(label: "Total", value: "Rp 165.000", emphasized: true)
                    }

                    StyledStatusBadge(text: "Auto-detected", tint: .green)

                    CostaActionButtons(cancelTitle: "Cancel", saveTitle: "Save", cancelAction: {}, saveAction: {})
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    return Demo()
}

#Preview("Gallery — Dark / Brand Components") {
    enum Filter: String, CaseIterable, Hashable { case week = "Last 7 days", month = "Last 30 days", all = "All time" }

    struct Demo: View {
        @State private var filter: Filter = .week
        @State private var digits = "50000"

        var body: some View {
            ZStack {
                CostaAuroraBackground(glowCenter: UnitPoint(x: 0.5, y: 0.05), glowColor: .blue)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 12) {
                            GlassMenuPicker(selection: $filter, options: Filter.allCases) { $0.rawValue }
                            StyledPillMenuPicker(selection: $filter, options: Filter.allCases) { $0.rawValue }
                        }

                        StyledTransactionRow(
                            emoji: "🍔",
                            colorHex: "#C62828",
                            title: "Hamburger",
                            subtitle: "Food",
                            amountText: "-Rp40.000",
                            date: Date()
                        )

                        HStack(spacing: 10) {
                            StyledAmountChip(title: "Rp 50.000") {}
                            StyledAmountChip(title: "Rp 100.000") {}
                            StyledAmountChip(title: "Rp 500.000") {}
                        }

                        StyledNumericKeypad(onDigit: { digits += $0 }, onBackspace: { if !digits.isEmpty { digits.removeLast() } })

                        StyledGradientButton(title: "Get Started") {}

                        HStack(spacing: 10) {
                            Circle().fill(CostaColors.appBackground).frame(width: 32, height: 32)
                                .overlay(Circle().strokeBorder(.white.opacity(0.3)))
                            Circle().fill(CostaColors.containerBackground).frame(width: 32, height: 32)
                            Circle().fill(CostaColors.red).frame(width: 32, height: 32)
                            Circle().fill(CostaColors.green).frame(width: 32, height: 32)
                            Capsule().fill(CostaColors.gradient).frame(width: 60, height: 32)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
    return Demo()
}

#Preview("StyledTextField") {
    struct Demo: View {
        @State private var name = "Venti Mocha Latte"
        @State private var quantity = "1"
        @State private var unitPrice = "50.000"

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    StyledTextField(title: "Name", placeholder: "Enter item name", text: $name)
                    StyledTextField(title: "Quantity", placeholder: "0", text: $quantity, keyboardType: .numberPad)
                    StyledTextField(title: "Unit Price", placeholder: "0", text: $unitPrice, leadingText: "IDR", keyboardType: .numberPad)
                    CostaActionButtons(cancelTitle: "Cancel", saveTitle: "Save", cancelAction: {}, saveAction: {})
                }
                .padding(18)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    return Demo()
}

#Preview("StyledSelectField") {
    enum Category: String, CaseIterable { case food = "Food", transport = "Transport", utilities = "Utilities" }

    struct Demo: View {
        @State private var category: Category = .food
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                StyledSelectField(
                    title: "Category",
                    selection: $category,
                    options: Category.allCases,
                    optionLabel: { $0.rawValue },
                    onAddNew: {}
                )
            }
            .padding(18)
            .background(Color(.systemGroupedBackground))
        }
    }
    return Demo()
}

#Preview("GlassMenuPicker") {
    enum Filter: String, CaseIterable, Hashable { case week = "Last 7 days", month = "Last 30 days", all = "All time" }

    struct Demo: View {
        @State private var selection: Filter = .week
        var body: some View {
            ZStack {
                LinearGradient(colors: [.teal.opacity(0.3), .blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                GlassMenuPicker(selection: $selection, options: Filter.allCases) { $0.rawValue }
            }
        }
    }
    return Demo()
}
