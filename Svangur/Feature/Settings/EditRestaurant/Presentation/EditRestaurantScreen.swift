import SwiftUI
import PhotosUI

struct EditRestaurantScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: EditRestaurantViewModel
    @State private var photoSelection: [PhotosPickerItem] = []

    init(viewModel: EditRestaurantViewModel) {
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
        .onChange(of: photoSelection) { _, newItems in
            Task {
                for item in newItems {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("jpg")
                    guard (try? data.write(to: url)) != nil else { continue }
                    viewModel.addImage(url)
                }
                photoSelection = []
            }
        }
        .sensoryFeedback(.success, trigger: viewModel.state == .saved)
        .onChange(of: viewModel.state) { _, newState in
            guard newState == .saved else { return }
            dismiss()
        }
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
            }
            descriptionSection

            openingHoursSection

            if case .error(let message) = viewModel.state {
                Text(message)
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svError)
            }

            SvPrimaryButton(
                title: "Save Changes",
                isLoading: viewModel.state == .saving,
                isEnabled: viewModel.canSubmit
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
            }
            if viewModel.isIcelandicNameSelected {
                pinkTextField(text: $viewModel.nameIs, autocapitalization: .words)
            }
        }
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
            }
            if viewModel.isIcelandicDescriptionSelected {
                pinkMultilineField(text: $viewModel.descriptionIs)
            }
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

    private func languageChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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
                    PhotosPicker(selection: $photoSelection, matching: .images) {
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
        }
    }

    // MARK: - Opening hours

    private var openingHoursSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.sm) {
            Text("Opening Hours")
                .font(SvFont.label)
                .foregroundStyle(Color.svOnBackground)

            VStack(spacing: SvSpacing.xs) {
                ForEach(Weekday.allCases) { day in
                    openingHourRow(for: day)
                }
            }
        }
    }

    @ViewBuilder
    private func openingHourRow(for day: Weekday) -> some View {
        let schedule = viewModel.openingHours[day] ?? EditDaySchedule(day: day)
        HStack(spacing: SvSpacing.sm) {
            Text(day.shortName)
                .font(SvFont.caption)
                .foregroundStyle(Color.svOnBackground)
                .frame(width: 35, alignment: .leading)

            if schedule.isClosed {
                Text("Closed")
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svSecondary)
                Spacer()
            } else {
                EditTimeChip(time: schedule.openTime) { viewModel.setOpenTime($0, for: day) }
                Text("to")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.svSecondary)
                EditTimeChip(time: schedule.closeTime) { viewModel.setCloseTime($0, for: day) }
                Spacer()
            }

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
                    .fill(isClosed ? Color.svPrimary : Color(red: 0.35, green: 0.76, blue: 0.42))
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
    let onChange: (String) -> Void
    @State private var isPickerVisible = false

    var body: some View {
        Button {
            isPickerVisible = true
        } label: {
            Text(time)
                .font(.system(size: 12))
                .foregroundStyle(Color.svOnBackground)
                .frame(width: 60, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.svFieldBackground)
                )
        }
        .buttonStyle(.plain)
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
            .presentationCompactAdaptation(.popover)
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
