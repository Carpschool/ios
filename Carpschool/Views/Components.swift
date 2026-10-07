import SwiftUI
import MapKit

/// Ticket-style card used for rides, requests and drives.
struct TicketCard<Content: View>: View {
    var accent: Color = .brand
    var stubTop: String? = nil
    var stubValue: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(accent).frame(width: 5)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
            if let stubValue {
                VStack(spacing: 2) {
                    if let stubTop { Text(stubTop).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).tracking(1) }
                    Text(stubValue).font(.title3.monospacedDigit().weight(.bold)).minimumScaleFactor(0.6).lineLimit(1)
                }
                .frame(width: 92)
                .padding(.vertical, 14)
                .overlay(alignment: .leading) {
                    Rectangle().fill(.clear).frame(width: 1)
                        .overlay(Line().stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundStyle(.separator))
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .clipShape(.rect(cornerRadius: 16))
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path { Path { p in p.move(to: .init(x: rect.midX, y: rect.minY)); p.addLine(to: .init(x: rect.midX, y: rect.maxY)) } }
}

struct StatusBadge: View {
    let text: String
    var color: Color = .secondary
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: .capsule)
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack {
            Text(title).font(.title3.weight(.semibold))
            Spacer()
            trailing
        }
    }
}
extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) { self.title = title; self.trailing = EmptyView() }
}

struct InitialsAvatar: View {
    let id: String
    var size: CGFloat = 40
    var body: some View {
        Text(Fmt.shortId(id).prefix(2))
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.brand.gradient, in: .circle)
            .accessibilityHidden(true)
    }
}

struct ErrorBanner: View {
    let message: String
    var retry: (() -> Void)? = nil
    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry { Button("Try Again", action: retry).buttonStyle(.bordered) }
        }
    }
}

/// Small static map with a pin, for cards.
struct PinMap: View {
    let coordinate: CLLocationCoordinate2D
    var title = "Pickup"
    var height: CGFloat = 150
    var body: some View {
        Map(initialPosition: .region(.init(center: coordinate, latitudinalMeters: 350, longitudinalMeters: 350)), interactionModes: []) {
            Marker(title, systemImage: "figure.wave", coordinate: coordinate).tint(.highlight)
        }
        .frame(height: height)
        .accessibilityLabel("\(title) location map")
    }
}

extension View {
    func cardStyle() -> some View {
        background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }
}

/// Lightweight toast.
struct Toast: Equatable { var text: String; var isError = false }

struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast {
                Label(toast.text, systemImage: toast.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(toast.isError ? Color.red : Color.primary)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: .capsule)
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast) {
                        try? await Task.sleep(for: .seconds(2.6))
                        withAnimation { self.toast = nil }
                    }
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.snappy, value: toast)
        .sensoryFeedback(trigger: toast) { _, new in new.map { $0.isError ? .error : .success } }
    }
}
extension View {
    func toast(_ t: Binding<Toast?>) -> some View { modifier(ToastModifier(toast: t)) }
}
