//
//  KitoMarkerContentView.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import UIKit

/// A UIKit view showing a rendered pin, with the same spring, pop-in and pulse as the SwiftUI
/// pins. Google Maps uses it as a marker's `iconView`; MapLibre puts it in an annotation view.
@_spi(KitoMapsProvider)
@MainActor
public final class KitoMarkerContentView: UIView {
    public private(set) var rendered: KitoPinImage?
    private let imageView = UIImageView()
    private var pulseLayer: CAShapeLayer?

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    public init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        clipsToBounds = false
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Whether the breathing halo is showing (the view then changes continuously).
    public var isPulsing: Bool { pulseLayer != nil }

    /// The image size; the view is exactly this big.
    public var imageSize: CGSize { rendered?.image.size ?? .zero }

    /// Shows a pin image. With `bounce`, it springs from its previous size to the new one.
    /// `pulseColor` adds a breathing halo of `pulseDiameter` points at the anchor.
    public func show(_ rendered: KitoPinImage, bounce: Bool = false, pulseColor: UIColor? = nil, pulseDiameter: CGFloat = 34) {
        let previous = self.rendered?.image.size
        self.rendered = rendered
        let size = rendered.image.size
        frame.size = size
        imageView.image = rendered.image
        imageView.transform = .identity
        imageView.layer.anchorPoint = rendered.anchor
        imageView.bounds = CGRect(origin: .zero, size: size)
        imageView.layer.position = CGPoint(x: rendered.anchor.x * size.width, y: rendered.anchor.y * size.height)
        updatePulse(color: pulseColor, diameter: pulseDiameter)

        guard bounce, let previous, previous.width > 0, size.width > 0, previous != size, !reduceMotion else { return }
        let start = previous.width / size.width
        imageView.transform = CGAffineTransform(scaleX: start, y: start)
        UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.6,
                       options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.imageView.transform = .identity
        }
    }

    /// Scales in from small with a spring.
    public func popIn(delay: TimeInterval = 0) {
        guard !reduceMotion else {
            alpha = 0
            UIView.animate(withDuration: 0.2, delay: delay) { self.alpha = 1 }
            return
        }
        alpha = 0
        imageView.transform = CGAffineTransform(scaleX: 0.35, y: 0.35)
        UIView.animate(withDuration: 0.6, delay: delay, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.4,
                       options: [.allowUserInteraction]) {
            self.alpha = 1
            self.imageView.transform = .identity
        }
    }

    /// Shrinks and fades out, then calls `completion`.
    public func shrinkAway(completion: @escaping () -> Void) {
        UIView.animate(withDuration: reduceMotion ? 0.15 : 0.25, delay: 0, options: [.curveEaseIn]) {
            self.alpha = 0
            if !self.reduceMotion { self.imageView.transform = CGAffineTransform(scaleX: 0.4, y: 0.4) }
        } completion: { _ in
            completion()
        }
    }

    private func updatePulse(color: UIColor?, diameter: CGFloat) {
        guard let color, !reduceMotion, let rendered else {
            pulseLayer?.removeFromSuperlayer()
            pulseLayer = nil
            return
        }
        let layer = pulseLayer ?? CAShapeLayer()
        if pulseLayer == nil {
            self.layer.insertSublayer(layer, below: imageView.layer)
            pulseLayer = layer
        }
        let size = rendered.image.size
        let center = CGPoint(x: rendered.anchor.x * size.width, y: rendered.anchor.y * size.height)
        layer.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        layer.position = center
        layer.path = UIBezierPath(ovalIn: layer.bounds).cgPath
        layer.fillColor = color.withAlphaComponent(0.35).cgColor
        guard layer.animation(forKey: "pulse") == nil else { return }
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = 2.8
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 1.7
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(group, forKey: "pulse")
    }
}

extension KitoMapPin {
    /// The halo size for `.pulse` pins, `nil` for other styles.
    @_spi(KitoMapsProvider) public var pulseDiameter: CGFloat? {
        style == .pulse ? (systemImage == nil ? 18 : 34) : nil
    }
}
