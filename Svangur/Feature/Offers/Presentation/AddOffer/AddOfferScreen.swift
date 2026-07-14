import SwiftUI
import PhotosUI

struct AddOfferScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(LanguageService.self) private var languageService
    @State var viewModel: AddOfferViewModel

    @State private var showCategorySheet = false
    @State private var showDiscountSheet = false
    @State private var photoSelection: [PhotosPickerItem] = []

    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case title, description }

    init(viewModel: AddOfferViewModel) {
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
        Group {
            switch viewModel.loadState {
            case .loadingExisting:
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .ready, .saving:
                form

            case .error(let message):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.svBackground.ignoresSafeArea())
        .task { await viewModel.onAppear(lang: languageService.current.rawValue) }
        .onChange(of: viewModel.effect) { _, effect in
            guard case .saved = effect else { return }
            viewModel.consumeEffect()
            router.popToRoot()
            router.navigate(to: .dashboard)
        }
        .onChange(of: photoSelection) { _, items in
            Task { await loadSelectedPhotos(items) }
        }
        .sheet(isPresented: $showCategorySheet) {
            CategoryPickerSheet(
                categories: viewModel.categories,
                language: languageService.current,
                selectedId: viewModel.draft.categoryId.map(String.init),
                onSelect: { categoryId in
                    viewModel.markTouched(.category)
                    viewModel.draft.categoryId = Int64(categoryId)
                    showCategorySheet = false
                }
            )
        }
        .sheet(isPresented: $showDiscountSheet) {
            DiscountPickerSheet(
                options: viewModel.discountOptions,
                selectedId: viewModel.draft.discountId,
                selectedCustomText: viewModel.draft.customDiscountText,
                onSelect: { discountId, customText in
                    viewModel.markTouched(.discount)
                    viewModel.draft.discountId = discountId
                    viewModel.draft.customDiscountText = customText
                    showDiscountSheet = false
                }
            )
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.showPreview },
            set: { if !$0 { viewModel.dismissPreview() } }
        )) {
            NavigationStack {
                OfferPreviewScreen(
                    draft: viewModel.draft,
                    categoryName: categoryDisplayName(for: viewModel.draft.categoryId),
                    isSaving: viewModel.loadState == .saving,
                    onConfirm: { Task { await viewModel.save() } },
                    onBack: { viewModel.dismissPreview() }
                )
            }
        }
    }

    @ViewBuilder
    private var form: some View {
        VStack(spacing: 0) {
            customHeader
            ScrollView {
                VStack(alignment: .leading, spacing: SvSpacing.sectionSpacing) {
                    imagesSection
                    titleSection
                    descriptionSection
                    categorySection
                    discountSection
                    validDaysSection
                    validTimeSection
                    Spacer(minLength: SvSpacing.xxxl)
                }
                .padding(.horizontal, SvSpacing.screenPadding)
                .padding(.top, SvSpacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            saveBar
        }
    }

    private var customHeader: some View {
        HStack(spacing: SvSpacing.sm) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.svOnBackground)
                    .frame(width: 18, height: 44, alignment: .leading)
            }
            .accessibilityLabel("Back")

            Text(viewModel.mode.isEdit ? "Edit Offer" : "Add New Offer")
                .font(SvFont.title)
                .foregroundStyle(Color.svOnBackground)
            Spacer()
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.bottom, SvSpacing.sm)
    }

    // MARK: - Sections

    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.sm) {
            Text("Offer Images")
                .font(SvFont.label)
                .foregroundStyle(Color.svPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SvSpacing.md) {
                    if viewModel.displayImageUrls.count < ValidateOfferDraftUseCase.maxImageCount {
                        PhotosPicker(
                            selection: $photoSelection,
                            maxSelectionCount: ValidateOfferDraftUseCase.maxImageCount - viewModel.displayImageUrls.count,
                            matching: .images
                        ) {
                            Image("AddImages")
                                .resizable()
                                .scaledToFill()
                                .foregroundStyle(Color.svSecondary)
                                .frame(width: 118, height: 118)
                                .background(
                                    RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                                        .fill(Color.svImagePlaceholder)
                                )
                        }
                        .accessibilityLabel("Add offer image")
                    }

                    ForEach(Array(viewModel.displayImageUrls.enumerated()), id: \.offset) { index, url in
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
                            .accessibilityLabel("Offer image \(index + 1)")

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
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionLabel("Offer Title")
            TextField("e.g. 30% off all pizzas", text: $viewModel.draft.title)
                .textFieldStyle(SvFieldStyle())
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit { focusedField = .description }
                .textInputAutocapitalization(.sentences)
                .onChange(of: viewModel.draft.title) { _, new in
                    viewModel.markTouched(.title)
                    if new.count > ValidateOfferDraftUseCase.titleMaxLength {
                        viewModel.draft.title = String(new.prefix(ValidateOfferDraftUseCase.titleMaxLength))
                    }
                }
            HStack {
                FieldErrorText(error: viewModel.displayError(for: .title))
                Spacer()
            }
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionLabel("Offer Description")
            TextField(
                "Describe what's included…",
                text: $viewModel.draft.description,
                axis: .vertical
            )
            .lineLimit(3...6)
            .textFieldStyle(SvFieldStyle())
            .focused($focusedField, equals: .description)
            .textInputAutocapitalization(.sentences)
            .onChange(of: viewModel.draft.description) { _, new in
                viewModel.markTouched(.description)
                if new.count > ValidateOfferDraftUseCase.descriptionMaxLength {
                    viewModel.draft.description = String(new.prefix(ValidateOfferDraftUseCase.descriptionMaxLength))
                }
            }
            HStack {
                FieldErrorText(error: viewModel.displayError(for: .description))
                Spacer()
            }
        }
        .padding(.top, -12)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionLabel("Category")
            DropdownButton(
                placeholder: "Select category",
                value: categoryDisplayName(for: viewModel.draft.categoryId),
                onTap: { showCategorySheet = true }
            )
            FieldErrorText(error: viewModel.displayError(for: .category))
        }
        .padding(.top, -12)
    }

    private var discountSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionLabel("Discount")
            DropdownButton(
                placeholder: "Select discount",
                value: discountDisplayValue,
                onTap: { showDiscountSheet = true }
            )
            FieldErrorText(error: viewModel.displayError(for: .discount))
        }
    }

    private var validDaysSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.lg) {
            sectionLabel("Valid Days")
            HStack(spacing: SvSpacing.sm) {
                ForEach(Weekday.allCases) { day in
                    DayChip(
                        day: day,
                        isSelected: viewModel.draft.validDays.contains(day),
                        onTap: { viewModel.toggleValidDay(day) }
                    )
                }
            }
            FieldErrorText(error: viewModel.displayError(for: .validDays))
        }
    }

    private var validTimeSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.lg) {
            sectionLabel("Valid Time")
            HStack(spacing: SvSpacing.md) {
                TimePickerField(time: Binding(
                    get: { viewModel.draft.validTimeStart },
                    set: {
                        viewModel.markTouched(.validTime)
                        viewModel.draft.validTimeStart = $0
                    }
                ))
                Text("–")
                    .font(SvFont.title)
                    .foregroundStyle(Color.svOnBackground)
                TimePickerField(time: Binding(
                    get: { viewModel.draft.validTimeEnd },
                    set: {
                        viewModel.markTouched(.validTime)
                        viewModel.draft.validTimeEnd = $0
                    }
                ))
            }
            FieldErrorText(error: viewModel.displayError(for: .validTime))
        }
    }

    private var saveBar: some View {
        SvPrimaryButton(
            title: viewModel.mode.isEdit ? "Update Offer" : "Save Offer",
            isLoading: viewModel.loadState == .saving,
            isEnabled: viewModel.isValid && viewModel.loadState != .saving
        ) {
            viewModel.onTapPreview()
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.top, SvSpacing.xs)
        .padding(.bottom, SvSpacing.xl)
        .background(Color.svBackground)
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
    }

    // MARK: - Display formatting

    private func categoryDisplayName(for categoryId: Int64?) -> String? {
        guard let categoryId else { return nil }
        guard let category = viewModel.categories.first(where: { $0.id == String(categoryId) }) else {
            return "Category #\(categoryId)"
        }
        return category.localizedName(for: languageService.current)
    }

    /// Looks up the human-readable label from the real, dynamic discount options
    /// (`viewModel.discountOptions`, backed by `GET /discount-options`). A raw-value fallback
    /// covers the brief window before `onAppear`'s fetch resolves.
    private var discountDisplayValue: String? {
        guard let discountId = viewModel.draft.discountId, !discountId.isEmpty else { return nil }
        if discountId == "custom" {
            let text = viewModel.draft.customDiscountText ?? ""
            return text.isEmpty ? "Custom" : text
        }
        if let match = viewModel.discountOptions.first(where: { $0.value == discountId }) {
            return match.label
        }
        if discountId == "bogo" { return "2 for 1" } // legacy sentinel from offline/mock data
        return "\(discountId)% off"
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
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
}

// MARK: - Reusable Form Components

private struct SvFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(SvFont.body)
            .foregroundStyle(Color.svOnBackground)
            .padding(.horizontal, SvSpacing.lg)
            .padding(.vertical, SvSpacing.lg)
            .background(Color.svFieldBackground, in: RoundedRectangle(cornerRadius: SvSpacing.inputRadius))
    }
}

private struct DropdownButton: View {
    let placeholder: LocalizedStringKey
    let value: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                if let value {
                    Text(value)
                        .font(SvFont.body)
                        .foregroundStyle(Color.svOnBackground)
                } else {
                    Text(placeholder)
                        .font(SvFont.body)
                        .foregroundStyle(Color.svSecondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.footnote)
                    .foregroundStyle(Color.svSecondary)
            }
            .padding(.horizontal, SvSpacing.lg)
            .frame(height: SvSpacing.inputHeight)
            .background(Color.svFieldBackground, in: RoundedRectangle(cornerRadius: SvSpacing.inputRadius))
        }
        .buttonStyle(.plain)
    }
}

private struct DayChip: View {
    let day: Weekday
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(shortName)
                .font(SvFont.bodySmallStrong)
                .foregroundStyle(isSelected ? Color.svOnPrimary : Color.svOnBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                        .fill(isSelected
                              ? LinearGradient(
                                    colors: [.svPrimaryGradientStart, .svPrimaryGradientEnd],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                              : LinearGradient(
                                    colors: [Color.svFieldBackground, Color.svFieldBackground],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(longName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var shortName: String {
        switch day {
        case .monday:    return "Mon"
        case .tuesday:   return "Tue"
        case .wednesday: return "Wed"
        case .thursday:  return "Thu"
        case .friday:    return "Fri"
        case .saturday:  return "Sat"
        case .sunday:    return "Sun"
        }
    }

    private var longName: String {
        switch day {
        case .monday:    return "Monday"
        case .tuesday:   return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday:  return "Thursday"
        case .friday:    return "Friday"
        case .saturday:  return "Saturday"
        case .sunday:    return "Sunday"
        }
    }
}

private struct TimePickerField: View {
    @Binding var time: TimeOfDay
    @State private var showSheet = false

    var body: some View {
        Button { showSheet = true } label: {
            Text(String(format: "%02d:%02d", time.hour, time.minute))
                .font(SvFont.body)
                .foregroundStyle(Color.svOnBackground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SvSpacing.lg)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                        .fill(Color.svFieldBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                        .stroke(Color.svPrimary, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            NavigationStack {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { Self.dateFromTime(time) },
                        set: { time = Self.timeFromDate($0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .padding(.top, SvSpacing.lg)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showSheet = false }
                    }
                }
            }
            .presentationDetents([.fraction(0.4)])
        }
    }

    private static func dateFromTime(_ t: TimeOfDay) -> Date {
        Calendar.current.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: Date()) ?? Date()
    }

    private static func timeFromDate(_ date: Date) -> TimeOfDay {
        let comp = Calendar.current.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: comp.hour ?? 0, minute: comp.minute ?? 0)
    }
}

private struct FieldErrorText: View {
    let error: ValidationError?

    var body: some View {
        if let error {
            Text(message(for: error))
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private func message(for error: ValidationError) -> LocalizedStringKey {
        switch error {
        case .empty:                return "form.error.empty"
        case .tooShort(let min):    return "Must be at least \(min) characters"
        case .tooLong(let max):     return "Must be \(max) characters or fewer"
        case .invalidFormat:        return "form.error.invalid_format"
        case .custom(let key):      return LocalizedStringKey(key)
        }
    }
}

// MARK: - Category sheet

/// Backed by the real, dynamic `DealCategory` list (`DealRepositoryProtocol.listOwnerCategories()`)
/// injected into `AddOfferViewModel` — NOT the old closed-set `OfferCategory` enum. Selection is
/// tracked by `DealCategory.id` (a `String`) rather than the whole struct, since `DealCategory`
/// isn't `Hashable` (it lives in `Feature/Deals`, out of scope to modify here) and SwiftUI's
/// `Picker(selection:)` requires a `Hashable` binding value.
private struct CategoryPickerSheet: View {
    let categories: [DealCategory]
    let language: AppLanguage
    let onSelect: (String) -> Void

    @State private var tempSelectedId: String

    init(
        categories: [DealCategory],
        language: AppLanguage,
        selectedId: String?,
        onSelect: @escaping (String) -> Void
    ) {
        self.categories = categories
        self.language = language
        self.onSelect = onSelect
        _tempSelectedId = State(initialValue: selectedId ?? categories.first?.id ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Done") {
                    onSelect(tempSelectedId)
                }
                .foregroundStyle(.pink)
                .fontWeight(.medium)
                .padding(.trailing, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)
            }

            if categories.isEmpty {
                Spacer()
                Text("No categories available")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                Picker("Category", selection: $tempSelectedId) {
                    ForEach(categories, id: \.id) { category in
                        Text(category.localizedName(for: language)).tag(category.id)
                    }
                }
                .pickerStyle(.wheel)
                .padding(.horizontal)
                Spacer()
            }
        }
        .presentationDetents([.fraction(0.4)])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Discount sheet

/// Backed by the real, dynamic `DiscountOwnerOption` list (`DealRepositoryProtocol
/// .listOwnerDiscountOptions()`, `GET /discount-options`) injected into `AddOfferViewModel` —
/// NOT a hardcoded percentage stride. `option.value` is the wire-faithful `discount_value` sent
/// to the backend verbatim (e.g. `"10"`, `"2_for_1"`, `"custom"`); selecting `"custom"` reveals
/// a free-text field for `custom_discount_text`.
private struct DiscountPickerSheet: View {
    let options: [DiscountOwnerOption]
    let onSelect: (String, String?) -> Void

    @State private var selectedValue: String
    @State private var customText: String

    init(
        options: [DiscountOwnerOption],
        selectedId: String?,
        selectedCustomText: String?,
        onSelect: @escaping (String, String?) -> Void
    ) {
        self.options = options
        self.onSelect = onSelect
        _selectedValue = State(initialValue: options.first { $0.value == selectedId }?.value ?? options.first?.value ?? "")
        _customText = State(initialValue: selectedCustomText ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Done") {
                    onSelect(selectedValue, selectedValue == "custom" ? customText : nil)
                }
                .foregroundStyle(.pink)
                .fontWeight(.medium)
                .padding(.trailing, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)
            }

            if options.isEmpty {
                Spacer()
                Text("No discount options available")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                Picker("Discount", selection: $selectedValue) {
                    ForEach(options, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .pickerStyle(.wheel)
                .padding(.horizontal)

                if selectedValue == "custom" {
                    TextField("Custom discount text", text: $customText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        .padding(.top, SvSpacing.sm)
                }

                Spacer()
            }
        }
        .presentationDetents([.fraction(0.5)])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Previews

#Preview("Add - Empty") {
    NavigationStack {
        AddOfferScreen(viewModel: .previewInstance(mode: .create))
    }
    .environment(AppRouter())
    .environment(LanguageService())
}

#Preview("Add - Filled") {
    NavigationStack {
        AddOfferScreen(viewModel: .previewInstance(
            mode: .create,
            prefilledDraft: OfferDraft(from: MockOfferRepository.seed[0])
        ))
    }
    .environment(AppRouter())
    .environment(LanguageService())
}

#Preview("Edit") {
    NavigationStack {
        AddOfferScreen(viewModel: .previewInstance(
            mode: .edit(offerId: 1),
            prefilledDraft: OfferDraft(from: MockOfferRepository.seed[0])
        ))
    }
    .environment(AppRouter())
    .environment(LanguageService())
}

#Preview("Add - Wide (no break)") {
    NavigationStack {
        AddOfferScreen(viewModel: .previewInstance(
            mode: .create,
            prefilledDraft: OfferDraft(from: MockOfferRepository.seed[0])
        ))
        .frame(width: 1024, height: 1366)
    }
    .environment(AppRouter())
    .environment(LanguageService())
}
