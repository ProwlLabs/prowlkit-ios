//
//  ProwlBrandIcon.swift
//  Prowl
//
//  Created by Elmee on 05/06/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

enum ProwlBrandIcon {
    static let resourceName = "prowlKitWhite"

    #if os(macOS)
    static func nsImage(targetHeight: CGFloat, bundle: Bundle = .module) -> NSImage? {
        guard let url = bundle.url(forResource: resourceName, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        let aspect = image.size.width / max(image.size.height, 1)
        image.size = NSSize(width: targetHeight * aspect, height: targetHeight)
        image.isTemplate = false
        return image
    }

    static var aspectRatio: CGFloat {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png"),
              let image = NSImage(contentsOf: url),
              image.size.height > 0 else {
            return 1021.0 / 274.0
        }
        return image.size.width / image.size.height
    }
    #endif

    static var image: Image {
        #if os(macOS)
        if let nsImage = nsImage(targetHeight: 22) {
            return Image(nsImage: nsImage)
        }
        #endif
        return Image(systemName: "antenna.radiowaves.left.and.right")
    }
}

struct ProwlBrandIconView: View {
    var height: CGFloat = 20

    var body: some View {
        ProwlBrandIcon.image
            .resizable()
            .interpolation(.high)
            #if os(macOS)
            .aspectRatio(ProwlBrandIcon.aspectRatio, contentMode: .fit)
            #else
            .aspectRatio(contentMode: .fit)
            #endif
            .frame(height: height)
            .accessibilityLabel("Prowl")
    }
}
