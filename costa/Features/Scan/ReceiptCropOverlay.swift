//
//  ReceiptCropOverlay.swift
//  costa
//
//  A draggable rectangular crop frame shown over the captured receipt on
//  the Review screen, so the user can trim the frame before it's
//  uploaded. This is a straight (axis-aligned) rectangle crop, not a
//  perspective quad-warp — a reasonable middle ground between "no
//  adjustment at all" and a full Vision-framework corner-detection +
//  perspective-correction pipeline.
//

import SwiftUI

enum CropCorner: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

struct ReceiptCropOverlay: View {
    @Binding var rect: CGRect
    let containerSize: CGSize

    private let handleSize: CGFloat = 26
    private let minSize: CGFloat = 80

    var body: some View {
        ZStack {
            dimmedMask
            frameBorder
            ForEach(CropCorner.allCases, id: \.self) { corner in
                handle(for: corner)
            }
        }
    }

    // MARK: - Visuals

    private var dimmedMask: some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: containerSize))
            path.addRect(rect)
        }
        .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }

    private var frameBorder: some View {
        Rectangle()
            .stroke(Color.white, lineWidth: 2)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func handle(for corner: CropCorner) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .shadow(radius: 2)
            .position(point(for: corner))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in drag(corner: corner, to: value.location) }
            )
    }

    private func point(for corner: CropCorner) -> CGPoint {
        switch corner {
        case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    // MARK: - Dragging

    private func drag(corner: CropCorner, to location: CGPoint) {
        var newRect = rect
        let x = min(max(location.x, 0), containerSize.width)
        let y = min(max(location.y, 0), containerSize.height)

        switch corner {
        case .topLeft:
            newRect.origin.x = min(x, rect.maxX - minSize)
            newRect.origin.y = min(y, rect.maxY - minSize)
            newRect.size.width = rect.maxX - newRect.origin.x
            newRect.size.height = rect.maxY - newRect.origin.y
        case .topRight:
            newRect.origin.y = min(y, rect.maxY - minSize)
            newRect.size.width = max(x - rect.minX, minSize)
            newRect.size.height = rect.maxY - newRect.origin.y
        case .bottomLeft:
            newRect.origin.x = min(x, rect.maxX - minSize)
            newRect.size.width = rect.maxX - newRect.origin.x
            newRect.size.height = max(y - rect.minY, minSize)
        case .bottomRight:
            newRect.size.width = max(x - rect.minX, minSize)
            newRect.size.height = max(y - rect.minY, minSize)
        }

        rect = newRect
    }
}

// MARK: - Cropping helper

extension UIImage {
    /// Crops `self` given a rect expressed in the coordinate space of an
    /// on-screen container of size `containerSize`, where the image was
    /// displayed with `.scaledToFit()` inside that container (and so may
    /// be letterboxed). Returns `self` unchanged if the math doesn't work out.
    func cropped(toDisplayRect rect: CGRect, inContainer containerSize: CGSize) -> UIImage {
        guard let cgImage, containerSize.width > 0, containerSize.height > 0 else { return self }

        let imageSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let displayedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (containerSize.width - displayedSize.width) / 2,
            y: (containerSize.height - displayedSize.height) / 2
        )

        let relative = CGRect(
            x: (rect.minX - origin.x) / scale,
            y: (rect.minY - origin.y) / scale,
            width: rect.width / scale,
            height: rect.height / scale
        ).intersection(CGRect(origin: .zero, size: imageSize))

        guard !relative.isEmpty, let cropped = cgImage.cropping(to: relative) else { return self }
        return UIImage(cgImage: cropped, scale: self.scale, orientation: self.imageOrientation)
    }
}
