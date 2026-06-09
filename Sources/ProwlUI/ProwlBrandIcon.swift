//
//  ProwlBrandIcon.swift
//  Prowl
//
//  Created by Elmee on 05/06/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum ProwlBrandVariant {
    case colored
    case white

    var resourceName: String {
        switch self {
        case .colored: "prowlKit"
        case .white: "prowlKitWhite"
        }
    }
}

enum ProwlBrandIcon {
    private static let fallbackAspectRatio: CGFloat = 1021.0 / 274.0

    static func aspectRatio(variant: ProwlBrandVariant = .white, bundle: Bundle = .module) -> CGFloat {
        guard let url = bundle.url(forResource: variant.resourceName, withExtension: "png") else {
            return fallbackAspectRatio
        }
        #if canImport(UIKit)
        if let image = UIImage(contentsOfFile: url.path), image.size.height > 0 {
            return image.size.width / image.size.height
        }
        #elseif os(macOS)
        if let image = NSImage(contentsOf: url), image.size.height > 0 {
            return image.size.width / image.size.height
        }
        #endif
        return fallbackAspectRatio
    }

    static func image(variant: ProwlBrandVariant = .white, bundle: Bundle = .module) -> Image {
        #if canImport(UIKit)
        if let uiImage = uiImage(variant: variant, bundle: bundle) {
            return Image(uiImage: uiImage)
        }
        #elseif os(macOS)
        if let nsImage = nsImage(variant: variant, targetHeight: 22, bundle: bundle) {
            return Image(nsImage: nsImage)
        }
        #endif
        return Image(systemName: "antenna.radiowaves.left.and.right")
    }

    #if canImport(UIKit)
    private static func uiImage(
        variant: ProwlBrandVariant,
        bundle: Bundle = .module
    ) -> UIImage? {
        guard let url = bundle.url(forResource: variant.resourceName, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        return image
    }
    #endif

    #if os(macOS)
    static func nsImage(
        variant: ProwlBrandVariant = .white,
        targetHeight: CGFloat,
        bundle: Bundle = .module
    ) -> NSImage? {
        guard let url = bundle.url(forResource: variant.resourceName, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        let aspect = image.size.width / max(image.size.height, 1)
        image.size = NSSize(width: targetHeight * aspect, height: targetHeight)
        image.isTemplate = false
        return image
    }
    #endif
}

struct ProwlBrandIconView: View {
    var height: CGFloat = 20
    var variant: ProwlBrandVariant = .white

    var body: some View {
        ProwlBrandIcon.image(variant: variant)
            .resizable()
            .interpolation(.high)
            .aspectRatio(ProwlBrandIcon.aspectRatio(variant: variant), contentMode: .fit)
            .frame(height: height)
            .accessibilityLabel("Prowl")
    }
}
