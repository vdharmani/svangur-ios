import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct RegisterRestaurantScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @State var viewModel: RegisterRestaurantViewModel
    
    @FocusState private var focusedField: Field?
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    @State private var currentStep: RegistrationStep = .basicInfo
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    
    private enum Field: Hashable {
        case restaurantName, restaurantNameIcelandic, email, password, confirmPassword, phone,
             description, descriptionIcelandic, address
    }
    
    private enum RegistrationStep {
        case basicInfo, businessDetails
    }
    
    init(viewModel: RegisterRestaurantViewModel) {
        self._viewModel = State(wrappedValue: viewModel)
    }
    
    var body: some View {
        switch hSizeClass {
        case .regular: compactLayout()
        default:       compactLayout()
        }
    }
    
    @ViewBuilder
    private func compactLayout() -> some View {
        ZStack {
            Color.svBackground.ignoresSafeArea()
            form
        }
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: viewModel.state == .submitted)
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.jpeg, .pdf],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.setDocument(url)
            }
        }
        .onChange(of: photoSelection) { _, items in
            Task { await loadSelectedPhotos(items) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(isPresented: $showCamera) { image in
                handleCapturedImage(image)
            }
            .ignoresSafeArea()
        }
        .overlay {
            if viewModel.state == .submitted {
                SvConfirmationDialog(
                    iconName: "checkmark",
                    title: "Registration Submitted",
                    message: "Your restaurant details have been sent to our admin team. Upon approval, your deals will be listed on the platform.",
                    primaryTitle: "Back to Home",
                    onPrimary: {
                        router.popToRoot()
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.state == .submitted)
        .task {
            await viewModel.onAppear()
        }
        .svErrorBanner(registerErrorMessage)
    }

    /// Server/API errors (e.g. a failed submission) surface as a banner over the top of the
    /// screen — distinct from per-field validation errors, which stay inline under each field.
    private var registerErrorMessage: String? {
        guard case .error(let message) = viewModel.state else { return nil }
        return message
    }

    // MARK: - Form
    
    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            
            ScrollView {
                VStack(alignment: .leading, spacing: SvSpacing.formFieldSpacing) {
                    switch currentStep {
                    case .basicInfo:
                        basicInfoStep
                    case .businessDetails:
                        businessDetailsStep
                    }
                }
                .padding(.horizontal, SvSpacing.screenPadding)
                .padding(.top, SvSpacing.md)
                .padding(.bottom, SvSpacing.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    // MARK: - Step 1: Basic Info
    
    @ViewBuilder
    private var basicInfoStep: some View {
        imagesSection
        
        restaurantNameSection
        
        textField(label: "Admin Email",
                  placeholder: "Enter email address",
                  text: $viewModel.email,
                  error: viewModel.validation.email,
                  emptyMessage: "Please enter email address",
                  keyboard: .emailAddress,
                  capitalization: .never,
                  contentType: .emailAddress,
                  field: .email,
                  next: .password)

        textField(label: "Password",
                  placeholder: "Enter password",
                  text: $viewModel.password,
                  error: viewModel.validation.password,
                  emptyMessage: "Please enter password.",
                  keyboard: .default,
                  capitalization: .never,
                  contentType: .newPassword,
                  field: .password,
                  next: .confirmPassword,
                  isSecure: true,
                  isRevealed: $isPasswordVisible)

        textField(label: "Confirm Password",
                  placeholder: "Enter password again",
                  text: $viewModel.confirmPassword,
                  error: viewModel.validation.confirmPassword,
                  emptyMessage: "Please enter password again.",
                  keyboard: .default,
                  capitalization: .never,
                  contentType: .newPassword,
                  field: .confirmPassword,
                  next: .phone,
                  isSecure: true,
                  isRevealed: $isConfirmPasswordVisible)

        textField(label: "Phone Number",
                  placeholder: "Enter phone number",
                  text: $viewModel.phoneNumber,
                  error: viewModel.validation.phoneNumber,
                  emptyMessage: "Please enter phone number.",
                  keyboard: .phonePad,
                  capitalization: .never,
                  contentType: .telephoneNumber,
                  field: .phone,
                  next: viewModel.isEnglishDescriptionSelected ? .description : .descriptionIcelandic)
            .onChange(of: viewModel.phoneNumber) { _, newValue in
                let clamped = newValue.clampedToMaxDigits(ValidateCredentialsUseCase.phoneMaxLength)
                if clamped != newValue { viewModel.phoneNumber = clamped }
            }

        descriptionSection

        SvPrimaryButton(title: "Continue") {
            guard viewModel.validateBasicInfoStep() else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = .businessDetails
            }
        }
        .padding(.top, SvSpacing.sm)
    }
    
    // MARK: - Step 2: Business Details
    
    @ViewBuilder
    private var businessDetailsStep: some View {
        textField(label: "Address",
                  placeholder: "Enter address",
                  text: $viewModel.address,
                  error: viewModel.validation.address,
                  emptyMessage: "Please enter an address.",
                  keyboard: .default,
                  capitalization: .words,
                  contentType: .streetAddressLine1,
                  field: .address,
                  next: nil,
                  submitLabel: .search,
                  onSubmitAction: { viewModel.searchAddressNow() })

        if !viewModel.addressSuggestions.isEmpty {
            addressSuggestionsList
        }

        openingHoursSection

        documentSection

        SvPrimaryButton(
            title: "Submit for Approval",
            isLoading: viewModel.state == .submitting
        ) {
            Task { await viewModel.submit() }
        }
        .padding(.top, SvSpacing.sm)
    }
    
    // MARK: - Header
    
    private var headerBar: some View {
        VStack(spacing: 16) {
            // Title and back button
            HStack(spacing: 8) {
                Button {
                    if currentStep == .businessDetails {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = .basicInfo
                        }
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.svOnBackground)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
                
                Text(viewModel.isEditing ? "Edit Restaurant" : "Register Restaurant")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.svOnBackground)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Step indicator
            StepIndicator(
                currentStep: currentStep == .basicInfo ? 1 : 2,
                totalSteps: 2,
                step1Label: "Basic Info",
                step2Label: "Business Details"
            )
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 12)
        .background(Color.white)
    }
    
    // MARK: - Images section
    
    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.sm) {
            Text("Restaurant Images")
                .font(SvFont.label)
                .foregroundStyle(Color.svPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SvSpacing.md) {
                    if viewModel.imageRefs.count < ValidateCredentialsUseCase.maxImageCount {
                        Menu {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    showCamera = true
                                } label: {
                                    Label("Take Photo", systemImage: "camera")
                                }
                            }
                            PhotosPicker(selection: $photoSelection,
                                         maxSelectionCount: ValidateCredentialsUseCase.maxImageCount - viewModel.imageRefs.count,
                                         matching: .images) {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                            }
                        } label: {
                            Image("AddImages")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 118, height: 118)
                                .background(
                                    RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                                        .fill(Color.svImagePlaceholder)
                                )
                        }
                        .accessibilityLabel("Add restaurant image")
                    }
                    ForEach(Array(viewModel.imageRefs.enumerated()), id: \.offset) { index, url in
                        ZStack(alignment: .topTrailing) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    Color.svImagePlaceholder
                                }
                            }
                            .frame(width: 118, height: 118)
                            .clipShape(RoundedRectangle(cornerRadius: SvSpacing.inputRadius))
                            .accessibilityLabel("Image \(index + 1)")
                            
                            Button {
                                viewModel.removeImage(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.svError)
                            }
                            .offset(x: 6, y: -6)
                            .accessibilityLabel("Remove image \(index + 1)")
                        }
                    }
                }
                .padding(.top, 6)
                .padding(.trailing, 6)
            }
            
            if let imagesError = viewModel.validation.images,
               let key = errorKey(for: imagesError, emptyMessage: "Please add at least one image.") {
                Text(key)
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svError)
            }

            if let sizeError = viewModel.imageSizeErrorMessage {
                Text(sizeError)
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svError)
            }
        }
    }

    // MARK: - Restaurant Name section (with language chips)
    
    private var restaurantNameSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.sm) {
            HStack {
                Text("Restaurant Name")
                    .font(SvFont.label)
                    .foregroundStyle(Color.svOnBackground)
                Spacer()
                languageChip("English", isSelected: viewModel.isEnglishNameSelected) {
                    viewModel.toggleEnglishNameSelected()
                }
                languageChip("Icelandic", isSelected: viewModel.isIcelandicNameSelected) {
                    viewModel.toggleIcelandicNameSelected()
                }
            }

            if viewModel.isEnglishNameSelected {
                TextField("Enter restaurant name", text: $viewModel.restaurantName)
                    .font(SvFont.timeValue)
                    .foregroundStyle(Color.svOnBackground)
                    .textInputAutocapitalization(.words)
                    .textContentType(.organizationName)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .restaurantName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = viewModel.isIcelandicNameSelected ? .restaurantNameIcelandic : .email }
                    .padding(.horizontal, 18)
                    .frame(height: SvSpacing.inputHeight)
                    .background(fieldBackground)
                    .onChange(of: viewModel.restaurantName) { _, newValue in
                        let filtered = newValue.filteredToLettersAndSpaces(
                            maxLength: ValidateCredentialsUseCase.restaurantNameMaxLength
                        )
                        if filtered != newValue { viewModel.restaurantName = filtered }
                    }

                if let error = viewModel.validation.restaurantName,
                   let key = errorKey(for: error, emptyMessage: "Please enter a name.") {
                    Text(key)
                        .font(SvFont.caption)
                        .foregroundStyle(Color.svError)
                }
            }

            if viewModel.isIcelandicNameSelected {
                TextField("Enter restaurant name (Icelandic)", text: $viewModel.restaurantNameIcelandic)
                    .font(SvFont.timeValue)
                    .foregroundStyle(Color.svOnBackground)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .restaurantNameIcelandic)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }
                    .padding(.horizontal, 18)
                    .frame(height: SvSpacing.inputHeight)
                    .background(fieldBackground)
                    .onChange(of: viewModel.restaurantNameIcelandic) { _, newValue in
                        let filtered = newValue.filteredToLettersAndSpaces(
                            maxLength: ValidateCredentialsUseCase.restaurantNameMaxLength
                        )
                        if filtered != newValue { viewModel.restaurantNameIcelandic = filtered }
                    }

                if let error = viewModel.validation.restaurantNameIcelandic,
                   let key = errorKey(for: error, emptyMessage: "Please enter a name.") {
                    Text(key)
                        .font(SvFont.caption)
                        .foregroundStyle(Color.svError)
                }
            }
        }
    }
    
    // MARK: - Description section (with language chips + multiline)
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.sm) {
            HStack {
                Text("Description")
                    .font(SvFont.label)
                    .foregroundStyle(Color.svOnBackground)
                Spacer()
                languageChip("English", isSelected: viewModel.isEnglishDescriptionSelected) {
                    viewModel.toggleEnglishDescriptionSelected()
                }
                languageChip("Icelandic", isSelected: viewModel.isIcelandicDescriptionSelected) {
                    viewModel.toggleIcelandicDescriptionSelected()
                }
            }

            if viewModel.isEnglishDescriptionSelected {
                TextField("Enter description", text: $viewModel.description, axis: .vertical)
                    .font(SvFont.timeValue)
                    .foregroundStyle(Color.svOnBackground)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .description)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(height: 120, alignment: .topLeading)
                    .background(fieldBackground)
                    .clipped()

                if let error = viewModel.validation.description,
                   let key = errorKey(for: error, emptyMessage: "Please enter a description.") {
                    Text(key)
                        .font(SvFont.caption)
                        .foregroundStyle(Color.svError)
                }
            }

            if viewModel.isIcelandicDescriptionSelected {
                TextField("Enter description (Icelandic)", text: $viewModel.descriptionIcelandic, axis: .vertical)
                    .font(SvFont.timeValue)
                    .foregroundStyle(Color.svOnBackground)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .descriptionIcelandic)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(height: 120, alignment: .topLeading)
                    .background(fieldBackground)
                    .clipped()

                if let error = viewModel.validation.descriptionIcelandic,
                   let key = errorKey(for: error, emptyMessage: "Please enter a description.") {
                    Text(key)
                        .font(SvFont.caption)
                        .foregroundStyle(Color.svError)
                }
            }
        }
    }
    
    // MARK: - Language chip

    @ViewBuilder
    private func languageChip(_ title: String, isSelected: Bool, action: (() -> Void)? = nil) -> some View {
        let content = HStack(spacing: 4) {
            Text(title)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .font(SvFont.captionStrong)
        .foregroundStyle(isSelected ? Color(red: 0.35, green: 0.76, blue: 0.42) : Color(red: 1.0, green: 0.596, blue: 0.0))
        .padding(.horizontal, 15)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? Color(red: 0.35, green: 0.76, blue: 0.42).opacity(0.1) : Color(red: 1.0, green: 0.596, blue: 0.0).opacity(0.1))
        )

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title)\(isSelected ? ", selected" : "")")
        } else {
            content
        }
    }
    
    // MARK: - Address suggestions (Google Places Autocomplete)

    private var addressSuggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.addressSuggestions) { suggestion in
                Button {
                    viewModel.selectAddressSuggestion(suggestion)
                    focusedField = nil
                } label: {
                    Text(suggestion.description)
                        .font(SvFont.timeValue)
                        .foregroundStyle(Color.svOnBackground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if suggestion.id != viewModel.addressSuggestions.last?.id {
                    Divider()
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                .stroke(Color(red: 0.93, green: 0.93, blue: 0.93), lineWidth: 1)
        )
    }

    // MARK: - Opening Hours section

    private var openingHoursSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Opening Hours")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.svOnBackground)
            
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Weekday.allCases) { day in
                        openingHourRow(for: day)
                    }
                }
            }

            if let openingHoursError = viewModel.openingHoursError {
                Text(openingHoursError)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.svError)
            }
        }
    }

    @ViewBuilder
    private func openingHourRow(for day: Weekday) -> some View {
        let schedule = viewModel.openingHours[day] ?? .standardOpen
        HStack(spacing: 12) {
            Text(day.shortName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.svOnBackground)
                .frame(width: 35, alignment: .leading)
                .fixedSize()

            TimeChip(time: schedule.openTime, isEnabled: schedule.isOpen) { newTime in
                viewModel.setOpenTime(newTime, for: day)
            }

            Text("to")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.svSecondary)
                .fixedSize()

            TimeChip(time: schedule.closeTime, isEnabled: schedule.isOpen) { newTime in
                viewModel.setCloseTime(newTime, for: day)
            }

            Text("Closed")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.svSecondary)
                .fixedSize()

            SvCompactToggle(isOn: Binding(
                get: { !schedule.isOpen },
                set: { _ in viewModel.toggleDayOpen(day) }
            ))
            .accessibilityLabel("\(day.shortName) is \(schedule.isOpen ? "open" : "closed")")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.93, green: 0.93, blue: 0.93), lineWidth: 1)
        )
    }
    
    // MARK: - Document section
    
    private var documentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upload Document")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.svOnBackground)
            
            Button {
                showDocumentPicker = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(red: 0.6, green: 0.6, blue: 0.6))
                    
                    Text(viewModel.documentRef?.lastPathComponent ?? "Tap to upload document")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.svOnBackground)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Text("JPG, PDF up to 5MB")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.svSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(red: 0.9, green: 0.9, blue: 0.9), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.documentRef == nil ? "Upload document" : "Replace document")
            
            if let error = viewModel.validation.document,
               let key = errorKey(for: error, emptyMessage: "Please upload a document.") {
                Text(key)
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svError)
            }
        }
    }
    
    // MARK: - Reusable text field
    
    @ViewBuilder
    private func textField(
        label: LocalizedStringKey,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        error: ValidationError?,
        emptyMessage: LocalizedStringKey,
        keyboard: UIKeyboardType,
        capitalization: TextInputAutocapitalization,
        contentType: UITextContentType?,
        field: Field,
        next: Field?,
        isSecure: Bool = false,
        isRevealed: Binding<Bool>? = nil,
        submitLabel: SubmitLabel? = nil,
        onSubmitAction: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.sm) {
            Text(label)
                .font(SvFont.label)
                .foregroundStyle(Color.svOnBackground)

            HStack(spacing: 8) {
                Group {
                    if isSecure && !(isRevealed?.wrappedValue ?? false) {
                        SecureField(placeholder, text: text)
                    } else {
                        TextField(placeholder, text: text)
                    }
                }
                .font(SvFont.timeValue)
                .foregroundStyle(Color.svOnBackground)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .textContentType(contentType)
                .autocorrectionDisabled(true)
                .focused($focusedField, equals: field)
                .submitLabel(submitLabel ?? (next == nil ? .done : .next))
                .onSubmit {
                    if let onSubmitAction {
                        onSubmitAction()
                    } else {
                        focusedField = next
                    }
                }

                if isSecure, let isRevealed {
                    Button {
                        isRevealed.wrappedValue.toggle()
                    } label: {
                        Image(systemName: isRevealed.wrappedValue ? "eye" : "eye.slash")
                            .foregroundStyle(Color.svSecondary)
                    }
                    .accessibilityLabel(isRevealed.wrappedValue ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, 18)
            .frame(height: SvSpacing.inputHeight)
            .background(fieldBackground)

            if let error, let key = errorKey(for: error, emptyMessage: emptyMessage) {
                Text(key)
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svError)
            }
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
            .fill(Color.svFieldBackground)
    }
    
    // MARK: - Error mapping
    
    private func errorKey(for error: ValidationError?, emptyMessage: LocalizedStringKey) -> LocalizedStringKey? {
        guard let error else { return nil }
        switch error {
        case .empty:            return emptyMessage
        case .tooShort(let m):  return "Must be at least \(m) characters"
        case .tooLong(let m):   return "Must be \(m) characters or fewer"
        case .invalidFormat:    return "Please enter valid email address"
        case .custom(let key):  return LocalizedStringKey(key)
        }
    }
    
    // MARK: - Photo loader
    
    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        viewModel.clearImageSizeError()
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            guard data.count <= ValidateCredentialsUseCase.maxImageSizeBytes else {
                viewModel.flagOversizedImage()
                continue
            }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")
            do {
                try data.write(to: url, options: .atomic)
                viewModel.addImage(url)
            } catch {
                continue
            }
        }
        photoSelection.removeAll()
    }

    private func handleCapturedImage(_ image: UIImage) {
        viewModel.clearImageSizeError()
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        guard data.count <= ValidateCredentialsUseCase.maxImageSizeBytes else {
            viewModel.flagOversizedImage()
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        guard (try? data.write(to: url, options: .atomic)) != nil else { return }
        viewModel.addImage(url)
    }
}

// MARK: - Step Indicator Component

private struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let step1Label: String
    let step2Label: String
    
    var body: some View {
        Image(currentStep == 1 ? "registerStep1" : "registerStep2")
            .resizable()
            .scaledToFit()
            .frame(height: 60)
    }
}

// MARK: - Compact toggle (Figma node 11080:4610) — 36×22, pink ON / gray OFF

private struct SvCompactToggle: View {
    @Binding var isOn: Bool
    
    private let trackWidth: CGFloat = 36
    private let trackHeight: CGFloat = 22
    private let thumbSize: CGFloat = 18
    private let trackPadding: CGFloat = 2
    
    private var thumbOffset: CGFloat {
        let travel = (trackWidth - thumbSize) / 2 - trackPadding
        return isOn ? travel : -travel
    }
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isOn.toggle()
            }
        } label: {
            ZStack {
                Capsule()
                    .fill(isOn ? Color.svPrimary : Color.svDivider)

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .offset(x: thumbOffset)
            }
            .frame(width: trackWidth, height: trackHeight)
            .frame(width: 44, height: 44)        // 44pt tap target (HIG)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Time chip (Figma node 11080:4571)

private struct TimeChip: View {
    let time: HourMinute
    var isEnabled: Bool = true
    let onChange: (HourMinute) -> Void
    @State private var isPickerVisible = false
    
    var body: some View {
        Button {
            isPickerVisible = true
        } label: {
            Text(isEnabled ? time.formattedString : "—")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(isEnabled ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color.svSecondary)
                .frame(width: 78, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.98, green: 0.98, blue: 0.98))
                )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isEnabled)
        .popover(isPresented: $isPickerVisible) {
            DatePicker(
                "Select time",
                selection: Binding(
                    get: { time.toDate() },
                    set: { onChange(HourMinute(date: $0)) }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding()
            .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - HourMinute <-> Date

private extension HourMinute {
    init(date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        self.init(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
    }
    
    func toDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }
}

// MARK: - Previews

#Preview("Register - Empty") {
    NavigationStack {
        RegisterRestaurantScreen(viewModel: .previewInstance())
    }
    .environment(AppRouter())
}

#Preview("Register - Submitting") {
    NavigationStack {
        RegisterRestaurantScreen(viewModel: .previewInstance(state: .submitting))
    }
    .environment(AppRouter())
}

#Preview("Register - Submitted") {
    NavigationStack {
        RegisterRestaurantScreen(viewModel: .previewInstance(state: .submitted))
    }
    .environment(AppRouter())
}

#Preview("Register - Error") {
    NavigationStack {
        RegisterRestaurantScreen(viewModel: .previewInstance(state: .error("Email already registered")))
    }
    .environment(AppRouter())
}
