#if os(iOS)

import SwiftUI

struct ZoomableModifier: ViewModifier {
    let minZoomScale: CGFloat
    let doubleTapZoomScale: CGFloat

    @State private var lastTransform: CGAffineTransform = .identity
    @State private var transform: CGAffineTransform = .identity
    @State private var contentSize: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .background(alignment: .topLeading) {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            contentSize = proxy.size
                        }
			.onChange(of: proxy.size.height) { _ in
                            if proxy.size != contentSize {
                                contentSize = proxy.size
                            }
                        }
                }
        	.frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
            }
            .animatableTransformEffect(transform)
            .gesture(combinedGestures)
    }

    private var combinedGestures: some Gesture {
        SimultaneousGesture(
            magnificationGesture,
            dragGesture
        )
        .simultaneously(with: doubleTapGesture)
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let scale = value
                transform = lastTransform.scaledBy(x: scale, y: scale)
            }
            .onEnded { _ in
                onEndGesture()
            }
    }

    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                let newTransform: CGAffineTransform =
                    if transform.isIdentity {
                        .anchoredScale(scale: doubleTapZoomScale, anchor: CGPoint(x: contentSize.width / 2, y: contentSize.height / 2))
                    } else {
                        .identity
                    }

                withAnimation(.linear(duration: 0.15)) {
                    transform = newTransform
                    lastTransform = newTransform
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                withAnimation(.interactiveSpring) {
                    transform = lastTransform.translatedBy(
                        x: value.translation.width / transform.scaleX,
                        y: value.translation.height / transform.scaleY
                    )
                }
            }
            .onEnded { _ in
                onEndGesture()
            }
    }

    private func onEndGesture() {
        let newTransform = limitTransform(transform)

        withAnimation(.snappy(duration: 0.1)) {
            transform = newTransform
            lastTransform = newTransform
        }
    }

    private func limitTransform(_ transform: CGAffineTransform) -> CGAffineTransform {
        let scaleX = transform.scaleX
        let scaleY = transform.scaleY

        if scaleX < minZoomScale
            || scaleY < minZoomScale
        {
            return .identity
        }

        let maxX = contentSize.width * (scaleX - 1)
        let maxY = contentSize.height * (scaleY - 1)

        if transform.tx > 0
            || transform.tx < -maxX
            || transform.ty > 0
            || transform.ty < -maxY
        {
            let tx = min(max(transform.tx, -maxX), 0)
            let ty = min(max(transform.ty, -maxY), 0)
            var transform = transform
            transform.tx = tx
            transform.ty = ty
            return transform
        }

        return transform
    }
}

public extension View {
    @ViewBuilder
    func zoomable(
        minZoomScale: CGFloat = 1,
        doubleTapZoomScale: CGFloat = 3
    ) -> some View {
        modifier(ZoomableModifier(
            minZoomScale: minZoomScale,
            doubleTapZoomScale: doubleTapZoomScale
        ))
    }

    @ViewBuilder
    func zoomable(
        minZoomScale: CGFloat = 1,
        doubleTapZoomScale: CGFloat = 3,
        outOfBoundsColor: Color = .clear
    ) -> some View {
        GeometryReader { proxy in
            ZStack {
                outOfBoundsColor
                self.zoomable(
                    minZoomScale: minZoomScale,
                    doubleTapZoomScale: doubleTapZoomScale
                )
            }
        }
        .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
    }
}

private extension View {
    @ViewBuilder
    func animatableTransformEffect(_ transform: CGAffineTransform) -> some View {
        scaleEffect(
            x: transform.scaleX,
            y: transform.scaleY,
            anchor: .zero
        )
        .offset(x: transform.tx, y: transform.ty)
    }
}

private extension UnitPoint {
    func scaledBy(_ size: CGSize) -> CGPoint {
        .init(
            x: x * size.width,
            y: y * size.height
        )
    }
}

private extension CGAffineTransform {
    static func anchoredScale(scale: CGFloat, anchor: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: anchor.x, y: anchor.y)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -anchor.x, y: -anchor.y)
    }

    var scaleX: CGFloat {
        sqrt(a * a + c * c)
    }

    var scaleY: CGFloat {
        sqrt(b * b + d * d)
    }
}

#endif
