import SwiftUI
import PhotosUI
import UIKit

struct EditRestaurantScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: EditRestaurantViewModel
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var showPhotoSourceSheet = false
    @State private var pendingPhotoSource: PhotoSource?

    private enum PhotoSource {
        case camera, library
    }

    init(viewModel: EditRestaurantViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        switch hSizeClass {
        case .regular: compactLayout()
        default:       compactLayout()
        }
    }

    @ViewBuilder
    private func compactLayout() -> some View {
        VStack(spacing: 0) {
            header
            switch viewModel.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .idle, .saving, .saved, .error:
                ScrollView {
                    form
                }
            }
        }
        .background(Color.svBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.onAppear() }
        .onChange(of: photoSelection) { newItems in
            Task {
                for item in newItems {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                    saveImageData(data)
                }
                photoSelection = []
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(isPresented: $showCamera) { image in
                guard let data = image.jpegData(compressionQuality: 0.9) else { return }
                saveImageData(data)
            }
            .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $showLibraryPicker,
            selection: $photoSelection,
            matching: .images
        )
        .sheet(isPresented: $showPhotoSourceSheet, onDismiss: presentPendingPhotoSource) {
            PhotoSourcePickerSheet(
                showCameraOption: UIImagePickerController.isSourceTypeAvailable(.camera),
                onTakePhoto: {
                    pendingPhotoSource = .camera
                    showPhotoSourceSheet = false
                },
                onChooseFromGallery: {
                    pendingPhotoSource = .library
                    showPhotoSourceSheet = false
                }
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .svPresentationCornerRadius(24)
        }
        .svSuccessFeedback(trigger: viewModel.state == .saved)
        .onChange(of: viewModel.state) { newState in
            guard newState == .saved else { return }
            dismiss()
        }
        .svErrorBanner(editRestaurantErrorMessage)
    }

    /// Server/API errors surface as a banner over the top of the screen — distinct from
    /// per-field validation. `.error` is also reachable from a failed *initial* load (before
    /// `apply(_:)` has populated the form), but the dedicated `.loading` state already owns the
    /// true "nothing to show yet" moment (a blocking `ProgressView`, no form), so surfacing this
    /// as a banner here doesn't remove any distinct empty/retry experience.
    private var editRestaurantErrorMessage: String? {
        guard case .error(let message) = viewModel.state else { return nil }
        return message
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: SvSpacing.sm) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.svOnBackground)
                    .frame(width: 15, height: 44, alignment: .leading)
            }
            .accessibilityLabel("Back")

            Text("Edit Restaurant")
                .font(SvFont.titleSmall)
                .foregroundStyle(Color.svOnBackground)

            Spacer()
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.top, SvSpacing.sm)
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: SvSpacing.formFieldSpacing) {
            photosSection

            restaurantNameSection
            fieldSection(heading: "Admin Email") {
                Text(viewModel.adminEmail)
                    .font(SvFont.timeValue)
                    .foregroundStyle(Color.svOnBackground)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: SvSpacing.inputHeight)
                    .background(pinkFieldBackground)
            }
            fieldSection(heading: "Phone Number") {
                pinkTextField(text: $viewModel.phoneNumber, keyboard: .phonePad, contentType: .telephoneNumber)
                    .onChange(of: viewModel.phoneNumber) { newValue in
                        let clamped = newValue.clampedToMaxDigits(ValidateCredentialsUseCase.phoneMaxLength)
                        if clamped != newValue { viewModel.phoneNumber = clamped }
                    }
            }
            locationSection
            descriptionSection

            openingHoursSection

            SvPrimaryButton(
                title: "Save Changes",
                isLoading: viewModel.state == .saving
            ) {
                Task { await viewModel.save() }
            }
            .padding(.top, SvSpacing.sm)
            .padding(.bottom, SvSpacing.xxl)
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.top, SvSpacing.lg)
    }

    // MARK: - Restaurant Name (with language chips)

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
                pinkTextField(text: $viewModel.nameEn, autocapitalization: .words)
                    .onChange(of: viewModel.nameEn) { newValue in
                        let filtered = newValue.filteredToLettersAndSpaces(
                            maxLength: ValidateCredentialsUseCase.restaurantNameMaxLength
                        )
                        if filtered != newValue { viewModel.nameEn = filtered }
                    }
                fieldErrorText(
                    viewModel.validation.nameEn,
                    emptyMessage: "Please enter restaurant name",
                    tooShortMessage: "Name must be at least 3 characters."
                )
            }
            if viewModel.isIcelandicNameSelected {
                pinkTextField(text: $viewModel.nameIs, autocapitalization: .words)
                    .onChange(of: viewModel.nameIs) { newValue in
                        let filtered = newValue.filteredToLettersAndSpaces(
                            maxLength: ValidateCredentialsUseCase.restaurantNameMaxLength
                        )
                        if filtered != newValue { viewModel.nameIs = filtered }
                    }
                fieldErrorText(
                    viewModel.validation.nameIs,
                    emptyMessage: "Please enter restaurant name",
                    tooShortMessage: "Name must be at least 3 characters."
                )
            }
        }
    }

    // MARK: - Location (address search, Google Places Autocomplete)

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.sm) {
            fieldSection(heading: "Location") {
                pinkTextField(text: $viewModel.address, autocapitalization: .words)
                    .submitLabel(.search)
                    .onSubmit { viewModel.searchAddressNow() }
            }

            if !viewModel.addressSuggestions.isEmpty {
                addressSuggestionsList
            }
        }
    }

    private var addressSuggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.addressSuggestions) { suggestion in
                Button {
                    viewModel.selectAddressSuggestion(suggestion)
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
                .stroke(Color.svDivider, lineWidth: 1)
        )
    }

    // MARK: - Description (with language chips)

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
                pinkMultilineField(text: $viewModel.descriptionEn)
                fieldErrorText(viewModel.validation.descriptionEn, emptyMessage: "Please enter a description")
            }
            if viewModel.isIcelandicDescriptionSelected {
                pinkMultilineField(text: $viewModel.descriptionIs)
                fieldErrorText(viewModel.validation.descriptionIs, emptyMessage: "Please enter a description")
            }
        }
    }

    private func presentPendingPhotoSource() {
        guard let source = pendingPhotoSource else { return }
        pendingPhotoSource = nil
        Task { @MainActor in
            // Presenting the next cover/sheet synchronously inside `onDismiss` races the
            // "Add photo" sheet's own dismiss transition — the camera/library picker can
            // render with the outgoing sheet's dimming still blended in. Give the dismiss
            // animation time to fully settle first.
            try? await Task.sleep(for: .milliseconds(350))
            switch source {
            case .camera: showCamera = true
            case .library: showLibraryPicker = true
            }
        }
    }

    private func saveImageData(_ data: Data) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        guard (try? data.write(to: url)) != nil else { return }
        viewModel.addImage(url)
    }

    @ViewBuilder
    private func fieldErrorText(
        _ error: ValidationError?,
        emptyMessage: LocalizedStringKey,
        tooShortMessage: LocalizedStringKey? = nil
    ) -> some View {
        if let key = errorKey(for: error, emptyMessage: emptyMessage, tooShortMessage: tooShortMessage) {
            Text(key)
                .font(.caption)
                .foregroundStyle(Color.svError)
        }
    }

    private func errorKey(
        for error: ValidationError?,
        emptyMessage: LocalizedStringKey,
        tooShortMessage: LocalizedStringKey? = nil
    ) -> LocalizedStringKey? {
        guard let error else { return nil }
        switch error {
        case .empty:            return emptyMessage
        case .tooShort(let m):  return tooShortMessage ?? "Must be at least \(m) characters"
        case .tooLong(let m):   return "Must be \(m) characters or fewer"
        case .invalidFormat:    return "Please enter a valid value"
        case .custom(let key):  return LocalizedStringKey(key)
        }
    }

    // MARK: - Field primitives

    private func fieldSection<Content: View>(
        heading: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.sm) {
            Text(heading)
                .font(SvFont.label)
                .foregroundStyle(Color.svOnBackground)
            content()
        }
    }

    private var pinkFieldBackground: some View {
        RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
            .fill(Color.svFieldBackground)
    }

    private func pinkTextField(
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .never
    ) -> some View {
        TextField("", text: text)
            .font(SvFont.timeValue)
            .foregroundStyle(Color.svOnBackground)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled(true)
            .padding(.horizontal, 18)
            .frame(height: SvSpacing.inputHeight)
            .background(pinkFieldBackground)
    }

    private func pinkMultilineField(text: Binding<String>) -> some View {
        TextField("", text: text, axis: .vertical)
            .font(SvFont.timeValue)
            .foregroundStyle(Color.svOnBackground)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(true)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(height: 100, alignment: .topLeading)
            .background(pinkFieldBackground)
            .clipped()
    }

    // MARK: - Language chip (mirrors RegisterRestaurantScreen's chip styling)

    private func languageChip(_ title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
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
                    .fill(isSelected
                        ? Color(red: 0.35, green: 0.76, blue: 0.42).opacity(0.1)
                        : Color(red: 1.0, green: 0.596, blue: 0.0).opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)\(isSelected ? ", selected" : "")")
    }

    // MARK: - Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.sm) {
            Text("Restaurant Images")
                .font(SvFont.label)
                .foregroundStyle(Color.svOnBackground)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SvSpacing.md) {
                    Button {
                        showPhotoSourceSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.svPrimary)
                            .frame(width: 90, height: 90)
                            .background(
                                RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                                    .fill(Color.svImagePlaceholder)
                            )
                    }
                    .accessibilityLabel("Add restaurant image")

                    ForEach(Array(viewModel.existingImageURLs.enumerated()), id: \.offset) { index, url in
                        ZStack(alignment: .topTrailing) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.svImagePlaceholder
                            }
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: SvSpacing.inputRadius))

                            Button {
                                viewModel.removeExistingImage(at: index)
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

                    ForEach(Array(viewModel.newImageRefs.enumerated()), id: \.offset) { index, url in
                        ZStack(alignment: .topTrailing) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.svImagePlaceholder
                            }
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: SvSpacing.inputRadius))

                            Button {
                                viewModel.removeNewImage(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.svError)
                            }
                            .offset(x: 6, y: -6)
                            .accessibilityLabel("Remove new image \(index + 1)")
                        }
                    }
                }
                .padding(.top, 6)
                .padding(.trailing, 6)
            }

            if let error = viewModel.validation.images {
                fieldErrorText(error, emptyMessage: "Please add at least one image.")
            }
        }
    }

    // MARK: - Opening hours

    private var openingHoursSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.sm) {
            Text("Opening Hours")
                .font(SvFont.label)
                .foregroundStyle(Color.svOnBackground)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: SvSpacing.sm) {
                    ForEach(Weekday.allCases) { day in
                        openingHourRow(for: day)
                    }
                }
            }

            if let openingHoursError = viewModel.openingHoursError {
                Text(openingHoursError)
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svError)
            }
        }
    }

    @ViewBuilder
    private func openingHourRow(for day: Weekday) -> some View {
        let schedule = viewModel.openingHours[day] ?? EditDaySchedule(day: day)
        let isOpen = !schedule.isClosed
        HStack(spacing: SvSpacing.sm) {
            Text(day.shortName)
                .font(SvFont.caption)
                .foregroundStyle(Color.svOnBackground)
                .frame(width: 35, alignment: .leading)
                .fixedSize()

            EditTimeChip(time: schedule.openTime, isEnabled: isOpen) {
                viewModel.setOpenTime($0, for: day)
            }
            Text("to")
                .font(SvFont.caption)
                .foregroundStyle(Color.svSecondary)
                .fixedSize()
            EditTimeChip(time: schedule.closeTime, isEnabled: isOpen) {
                viewModel.setCloseTime($0, for: day)
            }

            Text("Closed")
                .font(SvFont.caption)
                .foregroundStyle(Color.svSecondary)
                .fixedSize()

            DayOpenToggle(isClosed: schedule.isClosed) {
                viewModel.toggleDayOpen(day)
            }
            .accessibilityLabel("\(day.shortName) is \(schedule.isClosed ? "closed" : "open")")
        }
        .padding(.horizontal, SvSpacing.md)
        .padding(.vertical, SvSpacing.sm)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                .stroke(Color.svDivider, lineWidth: 1)
        )
    }
}

// MARK: - Day-open toggle (pink = closed, green = open)

private struct DayOpenToggle: View {
    let isClosed: Bool
    let onToggle: () -> Void

    private let trackWidth: CGFloat = 36
    private let trackHeight: CGFloat = 22
    private let thumbSize: CGFloat = 18
    private let trackPadding: CGFloat = 2

    private var thumbOffset: CGFloat {
        let travel = (trackWidth - thumbSize) / 2 - trackPadding
        return isClosed ? travel : -travel
    }

    var body: some View {
        Button(action: onToggle) {
            ZStack {
                Capsule()
                    .fill(isClosed ? Color.svPrimary : Color.svDivider)
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .offset(x: thumbOffset)
            }
            .frame(width: trackWidth, height: trackHeight)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Time chip ("HH:mm" string, wheel picker popover)

private struct EditTimeChip: View {
    let time: String
    var isEnabled: Bool = true
    let onChange: (String) -> Void
    @State private var isPickerVisible = false

    var body: some View {
        Button {
            isPickerVisible = true
        } label: {
            Text(isEnabled ? time : "–")
                .font(SvFont.captionStrong)
                .foregroundStyle(isEnabled ? Color.svOnBackground : Color.svSecondary)
                .frame(width: 78, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.svFieldBackground)
                )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isEnabled)
        .popover(isPresented: $isPickerVisible) {
            DatePicker(
                "Select time",
                selection: Binding(
                    get: { Self.date(from: time) },
                    set: { onChange(Self.string(from: $0)) }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding()
            .svPopoverCompactAdaptation()
        }
    }

    private static func date(from hhmm: String) -> Date {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        let hour = parts.first ?? 9
        let minute = parts.count > 1 ? parts[1] : 0
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private static func string(from date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }
}

// MARK: - Previews

#Preview("Edit Restaurant - Loaded") {
    NavigationStack {
        EditRestaurantScreen(viewModel: .previewInstance())
    }
}

#Preview("Edit Restaurant - Loading") {
    NavigationStack {
        EditRestaurantScreen(viewModel: .previewInstance(state: .loading))
    }
}

#Preview("Edit Restaurant - Saving") {
    NavigationStack {
        EditRestaurantScreen(viewModel: .previewInstance(state: .saving))
    }
}

#Preview("Edit Restaurant - Error") {
    NavigationStack {
        EditRestaurantScreen(viewModel: .previewInstance(state: .error("Something went wrong")))
    }
}
