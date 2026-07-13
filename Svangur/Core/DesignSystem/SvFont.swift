import SwiftUI

// Typography tokens, matched 1:1 to Figma styles.
// Sizes scale with Dynamic Type via `.relativeTo`.
//
// Figma weight mapping (verified against the Add New Offer screen):
// - SemiBold 600 → Poppins-SemiBold (page titles)
// - Medium 500   → Poppins-Medium  (form labels, button text, day chips)
// - Regular 400  → Poppins-Regular (body, time values, descriptions)
enum SvFont {
    // Display & headings
    static let displayLarge   = Font.custom("Poppins-Bold",     size: 32, relativeTo: .largeTitle)
    static let heading        = Font.custom("Poppins-SemiBold", size: 24, relativeTo: .title)
    static let title          = Font.custom("Poppins-SemiBold", size: 20, relativeTo: .title3)
    static let titleSmall     = Font.custom("Poppins-SemiBold", size: 18, relativeTo: .title3)
    static let labelTitle     = Font.custom("Poppins-SemiBold", size: 14, relativeTo: .title3)
    static let mainLabel      = Font.custom("Poppins-SemiBold", size: 16, relativeTo: .title3)
    static let labelTitleSmall      = Font.custom("Poppins-SemiBold", size: 12, relativeTo: .title3)

    // Body & labels
    static let label          = Font.custom("Poppins-Medium",   size: 16, relativeTo: .callout)
    static let body           = Font.custom("Poppins-Regular",  size: 16, relativeTo: .callout)
    static let bodySmall      = Font.custom("Poppins-Regular",  size: 14, relativeTo: .subheadline)
    static let bodySmallStrong = Font.custom("Poppins-Medium",  size: 14, relativeTo: .subheadline)

    // Captions
    static let caption        = Font.custom("Poppins-Regular",  size: 12, relativeTo: .caption)
    static let captionStrong  = Font.custom("Poppins-Medium",   size: 12, relativeTo: .caption)

    // Buttons (Figma uses Medium 500, NOT SemiBold)
    static let buttonLabel    = Font.custom("Poppins-Medium",   size: 16, relativeTo: .callout)
    static let buttonText     = Font.custom("Poppins-Medium",   size: 13, relativeTo: .callout)

    // Special
    static let timeValue      = Font.custom("Poppins-Regular",  size: 15, relativeTo: .subheadline)
    static let tagline        = Font.custom("Poppins-Regular",  size: 28, relativeTo: .title2)
    
    static let titleMedium     = Font.custom("Poppins-Medium",   size: 22, relativeTo: .title2)
    static let sectionLabel    = Font.custom("Poppins-Medium",   size: 18, relativeTo: .title3)
    static let editLink        = Font.custom("Poppins-Regular",  size: 13, relativeTo: .footnote) 
}
