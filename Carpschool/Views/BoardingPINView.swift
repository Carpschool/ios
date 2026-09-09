import SwiftUI

struct BoardingPINView: View {
    @State private var pin: String = ""
    @State private var isBoarded = false
    @State private var statusMessage = ""

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Boarding Verification")
                    .font(.title2)
                    .bold()

                Text("Enter the passenger's 4-digit Boarding Safety PIN. A single discrete GPS snapshot is captured to record boarding location.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                TextField("4-Digit PIN", text: $pin)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Button("Verify & Board Passenger") {
                    Task {
                        do {
                            // Single discrete GPS read
                            let coord = try await LocationSnapshotService.shared.captureDiscreteSnapshot()
                            // TODO: Submit to School Server: POST /api/v1/carpools/:id/board-passenger
                            statusMessage = "Passenger boarded at [\(String(format: "%.4f", coord.latitude)), \(String(format: "%.4f", coord.longitude))]"
                            isBoarded = true
                        } catch {
                            statusMessage = "Failed to capture GPS snapshot: \(error.localizedDescription)"
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(pin.count != 4)
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(isBoarded ? .green : .red)
            }

            Spacer()

            Button("End Ride (Arrival Snapshot)") {
                Task {
                    do {
                        let coord = try await LocationSnapshotService.shared.captureDiscreteSnapshot()
                        // TODO: Submit to School Server: POST /api/v1/carpools/:id/end-ride
                        statusMessage = "Ride completed at [\(String(format: "%.4f", coord.latitude)), \(String(format: "%.4f", coord.longitude))]"
                    } catch {
                        statusMessage = "Error: \(error.localizedDescription)"
                    }
                }
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .padding(.bottom)
        }
        .padding()
        .navigationTitle("Boarding")
    }
}
