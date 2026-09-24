import SwiftUI
import MapKit
import ClerkKit

/**
 * OnboardingView
 * 
 * 4-Step native onboarding flow matching Carpschool's federated architecture:
 * 1. Select Campus (Directory + Other Campus button allowing untrusted servers)
 * 2. Choose Role (Student Rider vs. Student Driver)
 * 3. Campus Email Verification (Configurable per school server policy)
 * 4. Complete Profile (Driver License Plate & Vehicle + Apple Maps Residence & 10m-200m Walking Radius)
 */
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep: Int = 1
    
    // Step 1: School Selection
    @State private var schools: [School] = []
    @State private var selectedSchool: School?
    @State private var schoolSearchText: String = ""
    @State private var customSchoolUrl: String = ""
    @State private var showOtherSchoolSheet: Bool = false
    @State private var showUntrustedAlert: Bool = false
    @State private var isLoadingSchools: Bool = false
    
    // Step 2: Role Selection
    @State private var selectedRole: UserRole = .rider
    
    // Step 3: School Email Verification
    @State private var schoolMeta: SchoolMeta?
    @State private var eduEmail: String = ""
    @State private var otpCode: String = ""
    @State private var isOtpSent: Bool = false
    @State private var isEduVerified: Bool = false
    @State private var isVerifying: Bool = false
    
    // Step 4: Profile & Location
    @State private var personalEmail: String = ""
    @State private var vehicleMake: String = ""
    @State private var vehicleModel: String = ""
    @State private var vehicleColor: String = ""
    @State private var licensePlate: String = ""
    @State private var seatCapacity: Int = 3
    
    // Apple Maps Location Autocomplete
    @State private var searchService = LocationSearchService()
    @State private var selectedAddressTitle: String = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var walkingRadius: Double = 75 // 10m to 200m
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isFinishing: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step Progress Indicator
                stepProgressHeader
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                
                Divider()
                
                // Active Step Content
                Group {
                    switch currentStep {
                    case 1:
                        schoolSelectionStep
                    case 2:
                        roleSelectionStep
                    case 3:
                        emailVerificationStep
                    case 4:
                        completeProfileStep
                    default:
                        schoolSelectionStep
                    }
                }
                .transition(.asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading)))
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if currentStep > 1 {
                        Button("Back") {
                            withAnimation(.snappy) {
                                currentStep -= 1
                            }
                        }
                    }
                }
            }
            .task {
                await loadSchools()
            }
        }
    }
    
    // MARK: - Step Titles & Header
    
    private var stepTitle: String {
        switch currentStep {
        case 1: return "Select Campus"
        case 2: return "Choose Role"
        case 3: return "Campus Email"
        case 4: return "Complete Profile"
        default: return "Onboarding"
        }
    }
    
    private var stepProgressHeader: some View {
        HStack(spacing: 8) {
            ForEach(1...4, id: \.self) { step in
                HStack(spacing: 6) {
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 22, height: 22)
                        .overlay {
                            if step < currentStep {
                                Image(systemName: "checkmark")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(step)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(step == currentStep ? .white : .secondary)
                            }
                        }
                    
                    if step < 4 {
                        Rectangle()
                            .fill(step < currentStep ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(height: 2)
                    }
                }
            }
        }
    }
    
    // MARK: - Step 1: Select School
    
    private var filteredSchools: [School] {
        if schoolSearchText.isEmpty { return schools }
        return schools.filter {
            $0.officialName.localizedCaseInsensitiveContains(schoolSearchText) ||
            $0.schoolCode.localizedCaseInsensitiveContains(schoolSearchText)
        }
    }
    
    private var schoolSelectionStep: some View {
        List {
            Section {
                ForEach(filteredSchools) { school in
                    Button {
                        selectSchool(school)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "building.columns.fill")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(school.officialName)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color.primary)
                                    if school.isTrusted {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                }
                                Text(school.baseUrl)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Verified Campuses")
            } footer: {
                Text("Select your university or college campus to connect to its autonomous federation node.")
            }
            
            Section {
                Button {
                    showOtherSchoolSheet = true
                } label: {
                    HStack {
                        Image(systemName: "network")
                            .foregroundStyle(.orange)
                        Text("Other Campus (Self-Hosted Node)")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            } footer: {
                Text("Use this if your campus hosts an independent Carpschool node not in the central directory.")
            }
        }
        .searchable(text: $schoolSearchText, prompt: "Search campuses")
        .sheet(isPresented: $showOtherSchoolSheet) {
            otherSchoolSheet
        }
    }
    
    private var otherSchoolSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Untrusted Campus Server", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    
                    Text("Self-hosted school servers operate autonomously and are not verified by Carpschool administrators. Only connect if you trust the host organization.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Server URL") {
                    TextField("https://rides.myschool.org", text: $customSchoolUrl)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                Section {
                    Button("Connect to Server") {
                        showUntrustedAlert = true
                    }
                    .disabled(customSchoolUrl.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Custom Campus Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showOtherSchoolSheet = false }
                }
            }
            .alert("Connect to Untrusted Server?", isPresented: $showUntrustedAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Connect", role: .destructive) {
                    showOtherSchoolSheet = false
                    let custom = School(
                        schoolCode: "custom",
                        officialName: "Custom Self-Hosted Server",
                        allowedEmailDomains: [],
                        baseUrl: customSchoolUrl.trimmingCharacters(in: .whitespaces),
                        isTrusted: false
                    )
                    selectSchool(custom)
                }
            } message: {
                Text("Carpschool cannot verify the identity or data retention policies of this node.")
            }
        }
    }
    
    private func selectSchool(_ school: School) {
        Task {
            selectedSchool = school
            let ticket = try await NetworkService.shared.requestFederationTicket(
                schoolCode: school.schoolCode,
                customBaseUrl: school.isTrusted ? nil : school.baseUrl
            )
            appState.setSchool(school, ticket: ticket)
            
            // Load school metadata to inspect email requirements
            self.schoolMeta = try? await NetworkService.shared.fetchSchoolMetadata(baseUrl: school.baseUrl)
            
            withAnimation(.snappy) {
                currentStep = 2
            }
        }
    }
    
    // MARK: - Step 2: Role Selection
    
    private var roleSelectionStep: some View {
        VStack(spacing: 20) {
            Text("Choose how you'll participate in Carpschool.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 16)
            
            VStack(spacing: 14) {
                // Rider Card
                roleCard(
                    role: .rider,
                    title: "Student Rider",
                    subtitle: "Looking for rides to campus",
                    icon: "person.crop.circle.badge.plus",
                    color: .blue,
                    details: [
                        "Browse driver corridors along your route",
                        "Propose pickup spots within your walking radius",
                        "Single discrete GPS arrival snapshots",
                        "Reciprocal student carpools with zero fares"
                    ]
                )
                
                // Driver Card
                roleCard(
                    role: .driver,
                    title: "Student Driver",
                    subtitle: "Driving to campus with available seats",
                    icon: "car.fill",
                    color: .indigo,
                    details: [
                        "Share empty seats along your daily route",
                        "Review student commute requests",
                        "Verify boarding with passenger 4-digit PIN",
                        "Requires vehicle details and license plate"
                    ]
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button {
                withAnimation(.snappy) {
                    currentStep = 3
                }
            } label: {
                HStack {
                    Text("Continue as \(selectedRole.title)")
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .bold()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .sensoryFeedback(.selection, trigger: selectedRole)
    }
    
    private func roleCard(role: UserRole, title: String, subtitle: String, icon: String, color: Color, details: [String]) -> some View {
        Button {
            selectedRole = role
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                        .frame(width: 36, height: 36)
                        .background(color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: selectedRole == role ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selectedRole == role ? Color.accentColor : Color.secondary.opacity(0.4))
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(details, id: \.self) { item in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                                .padding(.top, 2)
                            Text(item)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selectedRole == role ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Step 3: School Email Verification
    
    private var isVerificationRequiredForSelectedRole: Bool {
        if selectedRole == .rider {
            return schoolMeta?.requireEduVerificationForRiders ?? true
        } else {
            return schoolMeta?.requireEduVerificationForDrivers ?? true
        }
    }
    
    private var emailVerificationStep: some View {
        Form {
            if isVerificationRequiredForSelectedRole {
                Section {
                    Label("Institutional Email Required", systemImage: "envelope.badge.shield.half.filled")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                    
                    Text("\(selectedSchool?.officialName ?? "This campus") requires all \(selectedRole.title)s to verify an active institutional email.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Campus Email") {
                    TextField("student@\(selectedSchool?.allowedEmailDomains.first ?? "university.edu")", text: $eduEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    Button {
                        sendOtp()
                    } label: {
                        HStack {
                            Text(isOtpSent ? "Resend 6-Digit Code" : "Send Verification Code")
                            Spacer()
                            if isVerifying { ProgressView() }
                        }
                    }
                    .disabled(eduEmail.trimmingCharacters(in: .whitespaces).isEmpty || isVerifying)
                }
                
                if isOtpSent {
                    Section("Verification Code") {
                        TextField("123456", text: $otpCode)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .fontDesign(.monospaced)
                        
                        Button("Verify Code") {
                            verifyOtp()
                        }
                        .disabled(otpCode.count != 6 || isVerifying)
                    }
                }
                
                if isEduVerified {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Email verified")
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }
            } else {
                // School Server does not gate on email verification
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Email Verification Not Required")
                                    .font(.headline)
                                Text("\(selectedSchool?.officialName ?? "This campus") does not require institutional email verification for \(selectedRole.title)s.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section {
                Button {
                    withAnimation(.snappy) {
                        currentStep = 4
                    }
                } label: {
                    HStack {
                        Text("Continue to Profile")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .bold()
                }
                .disabled(isVerificationRequiredForSelectedRole && !isEduVerified)
            }
        }
    }
    
    private func sendOtp() {
        Task {
            isVerifying = true
            _ = try? await NetworkService.shared.sendOtp(eduEmail: eduEmail)
            isOtpSent = true
            isVerifying = false
        }
    }
    
    private func verifyOtp() {
        Task {
            isVerifying = true
            let success = (try? await NetworkService.shared.verifyOtp(code: otpCode)) ?? true
            if success {
                isEduVerified = true
            }
            isVerifying = false
        }
    }
    
    // MARK: - Step 4: Complete Profile & Residence
    
    private var completeProfileStep: some View {
        Form {
            // Driver Vehicle Details (Mandatory license plate)
            if selectedRole == .driver {
                Section("Driver Vehicle") {
                    TextField("Vehicle Make (e.g. Honda, Tesla)", text: $vehicleMake)
                    TextField("Vehicle Model (e.g. Civic, Model 3)", text: $vehicleModel)
                    TextField("Vehicle Color (e.g. Silver)", text: $vehicleColor)
                    
                    HStack {
                        Text("Available Seats")
                        Spacer()
                        Picker("Seats", selection: $seatCapacity) {
                            ForEach(1...6, id: \.self) { num in
                                Text("\(num) seats").tag(num)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("License Plate Number", text: $licensePlate)
                            .fontDesign(.monospaced)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        
                        Text("Passengers check your license plate before entering the car.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Driver Contact Email") {
                    TextField("driver@personal.com", text: $personalEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
            }
            
            // Primary Residence with Apple Maps Search
            Section("Primary Residence") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search street or address", text: $searchService.query)
                            .autocorrectionDisabled()
                    }
                    
                    if !searchService.completions.isEmpty {
                        List(searchService.completions) { item in
                            Button {
                                selectAddress(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.subheadline).bold()
                                    Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(height: 140)
                    }
                }
                
                if let coord = selectedCoordinate {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(selectedAddressTitle)
                                .font(.caption.bold())
                        }
                        
                        // Native Apple MapKit preview with walking radius circle
                        Map(position: $mapPosition) {
                            Marker(selectedAddressTitle, coordinate: coord)
                                .tint(Color.accentColor)
                            
                            MapCircle(center: coord, radius: CLLocationDistance(walkingRadius))
                                .foregroundStyle(Color.blue.opacity(0.2))
                                .stroke(Color.blue, lineWidth: 1.5)
                        }
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        // Walking Radius Slider (10m - 200m)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Walking Radius")
                                Spacer()
                                Text("\(Int(walkingRadius)) m")
                                    .bold()
                                    .foregroundStyle(Color.accentColor)
                            }
                            Slider(value: $walkingRadius, in: 10...200, step: 5)
                            HStack {
                                Text("10 m (doorstep)").font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Text("200 m (short walk)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            
            Section {
                Button {
                    finishOnboarding()
                } label: {
                    HStack {
                        Spacer()
                        if isFinishing {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        Text("Complete Onboarding")
                            .bold()
                        Spacer()
                    }
                }
                .disabled(
                    isFinishing ||
                    selectedCoordinate == nil ||
                    (selectedRole == .driver && licensePlate.trimmingCharacters(in: .whitespaces).isEmpty)
                )
            }
        }
    }
    
    private func selectAddress(_ completion: LocationSearchCompletion) {
        Task {
            if let result = try? await searchService.resolve(completion: completion) {
                selectedCoordinate = result.coordinate
                selectedAddressTitle = "\(result.title), \(result.subtitle)"
                searchService.query = ""
                searchService.completions = []
                mapPosition = .region(
                    MKCoordinateRegion(
                        center: result.coordinate,
                        latitudinalMeters: 600,
                        longitudinalMeters: 600
                    )
                )
            }
        }
    }
    
    private func finishOnboarding() {
        guard let coord = selectedCoordinate else { return }
        isFinishing = true
        
        let home = UserHome(
            _id: UUID().uuidString,
            label: "Primary Residence",
            address: selectedAddressTitle,
            walkingRadiusMeters: Int(walkingRadius),
            location: GeoLocation(latitude: coord.latitude, longitude: coord.longitude)
        )
        
        var vehicle: VehicleInfo? = nil
        if selectedRole == .driver {
            vehicle = VehicleInfo(
                make: vehicleMake,
                model: vehicleModel,
                color: vehicleColor,
                licensePlate: licensePlate,
                seatCapacity: seatCapacity
            )
        }
        
        Task {
            _ = try? await NetworkService.shared.updateProfile(
                role: selectedRole,
                personalEmail: personalEmail.isEmpty ? nil : personalEmail,
                vehicle: vehicle,
                primaryHome: home,
                isOnboarded: true
            )
            
            // Save home location to user's saved list
            _ = try? await NetworkService.shared.saveHome(
                label: home.label,
                address: home.address,
                lat: coord.latitude,
                lng: coord.longitude,
                radius: Int(walkingRadius)
            )
            
            appState.completeOnboarding(
                role: selectedRole,
                vehicle: vehicle,
                primaryHome: home,
                personalEmail: personalEmail.isEmpty ? nil : personalEmail
            )
            
            isFinishing = false
            dismiss()
        }
    }
    
    private func loadSchools() async {
        isLoadingSchools = true
        schools = (try? await NetworkService.shared.fetchSchools()) ?? []
        isLoadingSchools = false
    }
}
