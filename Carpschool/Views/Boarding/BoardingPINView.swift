import SwiftUI
import CoreLocation

/**
 * BoardingPINView
 * 
 * Role-Adapted Boarding Verification & Discrete GPS Snapshotting:
 * - Riders: Displays 4-digit Boarding PIN in monospaced security badge.
 * - Drivers: Keypad/Input to enter passenger's PIN, capturing a single discrete GPS snapshot.
 * - Zero continuous GPS tracking. Zero payment transactions.
 */
struct BoardingPINView: View {
    @Environment(AppState.self) private var appState
    
    // Driver Mode State
    @State private var pin: String = ""
    @State private var isBoarded: Bool = false
    @State private var isRideCompleted: Bool = false
    @State private var statusMessage: String = ""
    @State private var isCapturingLocation: Bool = false
    @State private var capturedBoardingCoord: CLLocationCoordinate2D?
    @State private var capturedArrivalCoord: CLLocationCoordinate2D?

    // Rider Mode State
    @State private var riderSafetyPin: String = "4829"

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if appState.activeRole == .driver {
                    driverBoardingView
                } else {
                    riderBoardingView
                }
                
                // Privacy & Safety Assurance Banner
                safetyAssuranceBanner
            }
            .padding()
        }
        .navigationTitle("Boarding")
    }

    // MARK: - Driver View
    
    private var driverBoardingView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)

                Text("Passenger Boarding")
                    .font(.title2.bold())

                Text("Enter the passenger's 4-digit Boarding PIN when they enter your vehicle. A single discrete GPS snapshot records the pickup spot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 14) {
                TextField("• • • •", text: $pin)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                    .onChange(of: pin) { _, newPin in
                        if newPin.count > 4 {
                            pin = String(newPin.prefix(4))
                        }
                    }

                Button {
                    verifyAndBoardPassenger()
                } label: {
                    HStack {
                        if isCapturingLocation { ProgressView().padding(.trailing, 4) }
                        Image(systemName: "person.crop.circle.badge.checkmark")
                        Text("Verify and Board Passenger")
                    }
                    .frame(maxWidth: 260)
                    .bold()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(pin.count != 4 || isCapturingLocation || isBoarded)
            }

            if isBoarded, let coord = capturedBoardingCoord {
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Passenger Boarded")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                    Text("Discrete GPS snapshot: [\(String(format: "%.5f", coord.latitude)), \(String(format: "%.5f", coord.longitude))]")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Divider()
                .padding(.vertical, 8)

            // Arrival Snapshot / End Ride
            VStack(spacing: 10) {
                Text("Arrival at Campus")
                    .font(.headline)

                Text("When you reach campus, record the arrival snapshot to complete the carpool.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    endRide()
                } label: {
                    HStack {
                        Image(systemName: "flag.checkered")
                        Text(isRideCompleted ? "Ride Completed" : "Complete Ride (Arrival Snapshot)")
                    }
                    .frame(maxWidth: 260)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .controlSize(.large)
                .disabled(!isBoarded || isRideCompleted || isCapturingLocation)

                if isRideCompleted, let coord = capturedArrivalCoord {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.orange)
                        Text("Arrival recorded at [\(String(format: "%.5f", coord.latitude)), \(String(format: "%.5f", coord.longitude))]")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    // MARK: - Rider View
    
    private var riderBoardingView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text("Your Boarding PIN")
                    .font(.title2.bold())

                Text("Share this 4-digit PIN with your driver when entering the vehicle. Do not share it until you verify the car model and license plate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // PIN Security Badge
            VStack(spacing: 8) {
                Text("BOARDING PIN")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .tracking(2)

                Text(riderSafetyPin)
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.accentColor)
                    .tracking(8)

                Label("Valid for today's commute", systemImage: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
            )

            // Vehicle & Driver Confirmation Checklist
            VStack(alignment: .leading, spacing: 10) {
                Text("Boarding Checklist")
                    .font(.headline)

                safetyCheckItem("Confirm vehicle make, model, and color")
                safetyCheckItem("Check that the license plate matches your matched driver")
                safetyCheckItem("Confirm driver name")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func safetyCheckItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.top, 2)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var safetyAssuranceBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "location.slash.fill")
                    .foregroundStyle(Color.accentColor)
                Text("Discrete Location Guarantee")
                    .font(.caption.bold())
            }
            Text("Carpschool records location only at the moment of boarding and campus arrival. Continuous background GPS is never used.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions
    
    private func verifyAndBoardPassenger() {
        isCapturingLocation = true
        Task {
            do {
                let coord = try await LocationSnapshotService.shared.captureDiscreteSnapshot()
                self.capturedBoardingCoord = coord
                _ = try? await NetworkService.shared.submitBoardingPin(
                    carpoolId: "carpool_sample_1",
                    riderId: "rider_sam",
                    pin: pin,
                    lat: coord.latitude,
                    lng: coord.longitude
                )
                self.isBoarded = true
            } catch {
                self.statusMessage = "Could not record location: \(error.localizedDescription)"
            }
            self.isCapturingLocation = false
        }
    }

    private func endRide() {
        isCapturingLocation = true
        Task {
            do {
                let coord = try await LocationSnapshotService.shared.captureDiscreteSnapshot()
                self.capturedArrivalCoord = coord
                _ = try? await NetworkService.shared.endRide(
                    carpoolId: "carpool_sample_1",
                    lat: coord.latitude,
                    lng: coord.longitude
                )
                self.isRideCompleted = true
            } catch {
                self.statusMessage = "Could not record location: \(error.localizedDescription)"
            }
            self.isCapturingLocation = false
        }
    }
}
