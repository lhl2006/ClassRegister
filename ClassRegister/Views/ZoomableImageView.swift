import SwiftUI
import UIKit

struct ZoomableImageView: View {
    let image: UIImage

    @State private var baseScale: CGFloat = 1
    @GestureState private var pinchScale: CGFloat = 1
    @State private var baseOffset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero

    private var currentScale: CGFloat {
        min(max(baseScale * pinchScale, 1), 4)
    }

    private var currentOffset: CGSize {
        CGSize(width: baseOffset.width + dragOffset.width, height: baseOffset.height + dragOffset.height)
    }

    var body: some View {
        let magnification = MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                baseScale = min(max(baseScale * value, 1), 4)
                if baseScale == 1 {
                    baseOffset = .zero
                }
            }

        let dragging = DragGesture()
            .updating($dragOffset) { value, state, _ in
                if currentScale > 1 {
                    state = value.translation
                }
            }
            .onEnded { value in
                guard baseScale > 1 else {
                    baseOffset = .zero
                    return
                }
                baseOffset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }

        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(currentScale)
            .offset(currentOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(SimultaneousGesture(magnification, dragging))
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut) {
                    if baseScale > 1 {
                        baseScale = 1
                        baseOffset = .zero
                    } else {
                        baseScale = 2
                    }
                }
            }
    }
}
