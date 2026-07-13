import CoreGraphics

enum SvSpacing {
    // MARK: - Scale (raw)
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32

    // MARK: - Semantic
    static let screenPadding:     CGFloat = 24
    static let formFieldSpacing:  CGFloat = 20
    static let sectionSpacing:    CGFloat = 24

    // MARK: - Component sizes
    static let inputHeight:  CGFloat = 55
    static let buttonHeight: CGFloat = 53
    static let buttonHeightSm : CGFloat = 48

    // MARK: - Radii
    static let inputRadius:  CGFloat = 10
    static let buttonRadius: CGFloat = 12
    static let cardRadius:   CGFloat = 16
    static let chipRadius:   CGFloat = 999  // pill
}
