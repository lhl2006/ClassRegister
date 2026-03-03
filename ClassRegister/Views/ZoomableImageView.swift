import SwiftUI
import UIKit

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = LayoutAwareScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .black
        scrollView.contentInsetAdjustmentBehavior = .always
        scrollView.maximumZoomScale = 4.0
        scrollView.minimumZoomScale = 1.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        let imageView = context.coordinator.imageView
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        scrollView.addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        context.coordinator.attach(scrollView: scrollView)
        scrollView.onLayout = { [weak coordinator = context.coordinator] in
            coordinator?.applyFitIfNeeded(force: false)
        }
        _ = context.coordinator.setImage(image)
        context.coordinator.applyFitIfNeeded(force: true)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let didChangeImage = context.coordinator.setImage(image)
        context.coordinator.applyFitIfNeeded(force: didChangeImage)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let imageView = UIImageView()
        private weak var scrollView: UIScrollView?
        private var hasAppliedInitialFit = false
        private var lastViewportSize: CGSize = .zero
        private var lastMinimumScale: CGFloat = 1

        private struct ViewportMetrics {
            let originX: CGFloat
            let originY: CGFloat
            let width: CGFloat
            let height: CGFloat
        }

        func attach(scrollView: UIScrollView) {
            self.scrollView = scrollView
        }

        @discardableResult
        func setImage(_ image: UIImage) -> Bool {
            let didChangeImage = imageView.image !== image
            if didChangeImage {
                imageView.image = image
                hasAppliedInitialFit = false
            }

            let imageSize = image.size
            imageView.frame = CGRect(origin: .zero, size: imageSize)
            scrollView?.contentSize = imageSize
            return didChangeImage
        }

        func applyFitIfNeeded(force: Bool) {
            guard let scrollView,
                  let image = imageView.image,
                  image.size.width > 0,
                  image.size.height > 0,
                  let viewport = viewportMetrics(for: scrollView) else {
                return
            }

            let viewportSize = CGSize(width: viewport.width, height: viewport.height)
            let widthScale = viewport.width / image.size.width
            let heightScale = viewport.height / image.size.height
            let minimumScale = min(widthScale, heightScale)
            let clampedMinimum = max(minimumScale, 0.01)
            let oldMinimum = max(scrollView.minimumZoomScale, lastMinimumScale)
            let nearOldMinimum = abs(scrollView.zoomScale - oldMinimum) < 0.02
            let boundsChanged = lastViewportSize != viewportSize

            scrollView.minimumZoomScale = clampedMinimum
            scrollView.maximumZoomScale = max(4.0, clampedMinimum * 4)

            if force || !hasAppliedInitialFit || (boundsChanged && nearOldMinimum) {
                scrollView.setZoomScale(clampedMinimum, animated: false)
                hasAppliedInitialFit = true
            } else if scrollView.zoomScale < clampedMinimum {
                scrollView.setZoomScale(clampedMinimum, animated: false)
            }

            lastMinimumScale = clampedMinimum
            lastViewportSize = viewportSize
            centerImage(in: scrollView)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
        }

        @objc
        func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }

            let minScale = scrollView.minimumZoomScale
            let maxScale = scrollView.maximumZoomScale

            if abs(scrollView.zoomScale - minScale) < 0.01 {
                let point = gesture.location(in: imageView)
                let zoomRect = zoomRectForScale(scale: maxScale, center: point, in: scrollView)
                scrollView.zoom(to: zoomRect, animated: true)
            } else {
                scrollView.setZoomScale(minScale, animated: true)
            }
        }

        private func centerImage(in scrollView: UIScrollView) {
            guard let viewport = viewportMetrics(for: scrollView) else { return }
            var frameToCenter = imageView.frame

            frameToCenter.origin.x = frameToCenter.size.width < viewport.width
                ? viewport.originX + (viewport.width - frameToCenter.size.width) / 2
                : viewport.originX
            frameToCenter.origin.y = frameToCenter.size.height < viewport.height
                ? viewport.originY + (viewport.height - frameToCenter.size.height) / 2
                : viewport.originY

            imageView.frame = frameToCenter
        }

        private func viewportMetrics(for scrollView: UIScrollView) -> ViewportMetrics? {
            let bounds = scrollView.bounds
            let insets = scrollView.adjustedContentInset

            let visibleWidth = max(bounds.width - insets.left - insets.right, 0)
            let visibleHeight = max(bounds.height - insets.top - insets.bottom, 0)

            guard visibleWidth > 0, visibleHeight > 0 else { return nil }

            return ViewportMetrics(
                originX: insets.left,
                originY: insets.top,
                width: visibleWidth,
                height: visibleHeight
            )
        }

        private func zoomRectForScale(scale: CGFloat, center: CGPoint, in scrollView: UIScrollView) -> CGRect {
            let size = CGSize(
                width: scrollView.bounds.size.width / scale,
                height: scrollView.bounds.size.height / scale
            )
            let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
            return CGRect(origin: origin, size: size)
        }
    }
}

private final class LayoutAwareScrollView: UIScrollView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}
