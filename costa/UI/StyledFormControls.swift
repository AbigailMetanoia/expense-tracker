//
//  StyledFormControls.swift
//  costa
//
//  All shared form-building blocks in one file: color hex parsing, the
//  pill-shaped text/select fields used across sheets, the glass filter
//  picker, and the small drag-handle + action-button pair used to close
//  out a form sheet. Kept together on purpose so there's one place to
//  tweak the shared look instead of hunting across several files.
//

import SwiftUI
import UIKit

// MARK: - Color+Hex

extension Color {
    /// Parses `#RGB`, `#RRGGBB`, or `#RRGGBBAA` (case-insensitive). Returns `nil` if invalid or empty.
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

    /// Best-effort `#RRGGBB` hex string, used to persist a color chosen via
    /// the native `ColorPicker` (which hands back a `Color`, not a hex string).
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return nil }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Shared field shape

/// Every field in the HiFi form (Name, Quantity, Unit Price, Category) is a
/// fully-rounded pill rather than a soft rounded-rect — this is the one
/// place that decides that, so all fields stay in sync.
private let fieldShape = Capsule(style: .continuous)
private let fieldFill = Color(uiColor: .secondarySystemFill)

// MARK: - StyledTextField

/// A reusable text-field block styled like the receipt detail form.
struct StyledTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    /// Optional short leading text rendered in its own pill (e.g. "IDR").
    var leadingText: String?
    /// Optional short trailing text rendered inside the field itself (e.g. "%").
    var trailingText: String?
    var keyboardType: UIKeyboardType = .default
    /// Renders a `SecureField` instead of `TextField` (for passwords).
    var isSecure: Bool = false
    /// These three exist as explicit params — not applied from outside —
    /// because modifiers chained onto this view from a call site land on
    /// the outer `VStack`, not the `TextField`/`SecureField` inside it, so
    /// they'd silently do nothing.
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
                        .background(fieldFill, in: fieldShape)
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
                .background(fieldFill, in: fieldShape)
            }
        }
    }
}

// MARK: - StyledSelectField

/// A reusable dropdown/select block matching the `StyledTextField` look.
/// The menu opens anchored to the trailing edge of the field.
/// When `onAddNew` is set, a trailing "Add new…" action appears; the parent presents any add UI (sheet, navigation, etc.).
/// Visual variant for `StyledSelectField`.
enum StyledSelectFieldStyle {
    /// Adaptive system fill — the default, used for regular form fields.
    case system
    /// Always-black pill with white text, regardless of light/dark mode —
    /// used for the receipt-level Category chip, which is meant to stand
    /// out as a prominent action rather than blend in like a normal field.
    case solidDark
}

struct StyledSelectField<Option: Hashable>: View {
    var title: String? = nil
    /// SF Symbol shown instead of `title` text — used when the field's
    /// label is an icon (e.g. the receipt-level Category field).
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
        .background(style == .solidDark ? Color.black : fieldFill, in: fieldShape)
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

/// UIButton subclass anchoring its menu to the trailing edge.
final class TrailingMenuButton: UIButton {
    override func menuAttachmentPoint(for configuration: UIContextMenuConfiguration) -> CGPoint {
        CGPoint(x: bounds.maxX, y: bounds.minY)
    }
}

// MARK: - GlassMenuPicker
//
// Used for the small filter chip pattern (e.g. "Last 7 days") that floats
// over colorful content — kept as `.ultraThinMaterial` on purpose, since
// that's a different surface than the form fields above (a floating
// control over a photo/gradient, not a field inside a flat sheet).

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

// MARK: - Sheet chrome: drag handle + action buttons
//
// New pieces the HiFi design needs that didn't exist yet: the top drag
// handle, and the bottom Cancel/Save pill pair (replacing navigation-bar
// toolbar buttons).

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
//
// One line in a receipt/cost summary (Subtotal, Tax, Service Charge,
// Total). `emphasized` bumps it to headline weight for the Total row;
// `infoText` adds a small info glyph with an accessibility hint for rows
// like "Tax (10%)" that could use a one-line explanation.

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
//
// Small pill used for status like "Auto-detected ✓". Kept generic so it
// can be reused for other one-word confirmations later (e.g. "Verified").

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
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12))
        .overlay(Capsule().stroke(tint, lineWidth: 1))
        .clipShape(.capsule)
    }
}

// MARK: - StyledDateField
//
// A pill field showing a formatted date (and optionally time) with a
// calendar glyph. Tapping it opens the system date picker. This overlays
// an invisible native `DatePicker` on top of the custom-styled label —
// the same trick apps like Calendar/Reminders use to keep native date
// picking behavior under a fully custom look. Test this on-device across
// iOS versions since the overlay/opacity approach can be sensitive to
// platform changes.
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
                .background(fieldFill, in: fieldShape)
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

/// A multi-line pill-cornered text area, used for free-form notes.
struct StyledTextArea: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(Color(uiColor: .placeholderText))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .foregroundStyle(.primary)
            }
            .frame(minHeight: minHeight)
            .background(fieldFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - StyledSegmentedToggle
//
// A two (or more)-way toggle rendered as separate pill buttons rather
// than one continuous segmented bar — matches the "Percentage / Fix
// Amount" control in the charge-editing sheet.
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
//
// The soft glowing-blob background used on Onboarding/Login. Built with a
// native RadialGradient + blur rather than an imported SVG/PNG — it's
// lighter, scales to any screen size, and the color/position can be
// tweaked per-screen without re-exporting an asset.
struct CostaAuroraBackground: View {
    var glowCenter: UnitPoint = .init(x: 0.5, y: 0.3)
    var glowColor: Color = .blue

    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [glowColor.opacity(0.55), glowColor.opacity(0.22), Color.clear],
                center: glowCenter,
                startRadius: 10,
                endRadius: 420
            )
            .blur(radius: 60)
        }
        .ignoresSafeArea()
    }
}

// MARK: - StyledGradientButton
//
// Primary CTA pill with the blue gradient fill used for "Get Started" and
// "Sign in". Separate from `CostaActionButtons` since that one is a plain
// solid-accent pill meant for Cancel/Save pairs, not a standalone hero CTA.
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
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.20, green: 0.40, blue: 0.95),
                        Color(red: 0.55, green: 0.60, blue: 0.98)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.6 : 1)
    }
}

// MARK: - CostaImageBackground
//
// Full-bleed background image (e.g. an exported PNG gradient/glow asset).
// Use this instead of `CostaAuroraBackground` when the design calls for a
// specific pre-rendered look that's easier to nail as an image than to
// recreate with native gradients.
struct CostaImageBackground: View {
    let imageName: String
    /// Which part of the (overflowing) image stays visible once it's
    /// scaled to fill and clipped — e.g. `.top` keeps the top of the
    /// image in view and crops from the bottom instead of both edges.
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
//
// A custom 3x4 numeric keypad (with a "000" quick-zeros key and a
// backspace key) for money-entry screens that want a fully custom look
// instead of the system keyboard.
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
//
// A quick-pick pill for preset amounts (e.g. "Rp 50.000") shown in a
// horizontal scroll row above a numeric keypad.
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

// MARK: - Previews

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
