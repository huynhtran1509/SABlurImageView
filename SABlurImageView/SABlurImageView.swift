//
//  UIImageView+BlurEffect.swift
//  SABlurImageView
//
//  Created by 鈴木大貴 on 2015/03/27.
//  Copyright (c) 2015年 鈴木大貴. All rights reserved.
//

import UIKit
import Foundation
import QuartzCore

public class SABlurImageView: UIImageView {
    
    private typealias AnimationFunction = Void -> ()
    
    //MARK: - Static Properties
    private struct Const {
        static let fadeAnimationKey = "FadeAnimationKey"
        static let maxImageCount: Int = 10
        static let contentsAnimationKey = "contents"
    }
        
    //MARK: - Instance Properties
    private var cgImages: [CGImage] = [CGImage]()
    private var nextBlurLayer: CALayer?
    private var previousImageIndex: Int = -1
    private var previousPercentage: CGFloat = 0.0
    public private(set) var isBlurAnimating: Bool = false
    
    deinit {
        clearMemory()
    }

    //MARK: - Life Cycle
    public override func layoutSubviews() {
        super.layoutSubviews()
        nextBlurLayer?.frame = bounds
    }
    
    public func configrationForBlurAnimation(boxSize: CGFloat = 100) {
        guard let image = image else { return }
        let baseBoxSize = max(min(boxSize, 200), 0)
        let baseNumber = sqrt(CGFloat(baseBoxSize)) / CGFloat(Const.maxImageCount)
        let baseCGImages = [image].flatMap { $0.CGImage }
        cgImages = bluredCGImages(baseCGImages, sourceImage: image, at: 0, to: Const.maxImageCount, baseNumber: baseNumber)
    }
    
    private func bluredCGImages(images: [CGImage], sourceImage: UIImage?, at index: Int, to limit: Int, baseNumber: CGFloat) -> [CGImage] {
        guard index < limit else { return images }
        let newImage = sourceImage?.blurEffect(pow(CGFloat(index) * baseNumber, 2))
        let newImages = images + [newImage].flatMap { $0?.CGImage }
        return bluredCGImages(newImages, sourceImage: newImage, at: index + 1, to: limit, baseNumber: baseNumber)
    }
    
    public func clearMemory() {
        cgImages.removeAll(keepCapacity: false)
        nextBlurLayer?.removeFromSuperlayer()
        nextBlurLayer = nil
        previousImageIndex = -1
        previousPercentage = 0.0
        layer.removeAllAnimations()
    }

    //MARK: - Add single blur
    public func addBlurEffect(boxSize: CGFloat, times: UInt = 1) {
        guard let image = image else { return }
        self.image = addBlurEffectTo(image, boxSize: boxSize, remainTimes: times)
    }
    
    private func addBlurEffectTo(image: UIImage, boxSize: CGFloat, remainTimes: UInt) -> UIImage {
        guard let blurImage = image.blurEffect(boxSize) else { return image }
        return remainTimes > 0 ? addBlurEffectTo(blurImage, boxSize: boxSize, remainTimes: remainTimes - 1) : image
    }

    //MARK: - Percentage blur
    public func blur(percentage: CGFloat) {
        let percentage = min(max(percentage, 0.0), 0.99)
        if previousPercentage - percentage  > 0 {
            let index = Int(floor(percentage * 10)) + 1
            if index > 0 {
                setLayers(index, percentage: percentage, currentIndex: index - 1, nextIndex: index)
            }
        } else {
            let index = Int(floor(percentage * 10))
            if index < cgImages.count - 1 {
                setLayers(index, percentage: percentage, currentIndex: index, nextIndex: index + 1)
            }
        }
        previousPercentage = percentage
    }
    
    private func setLayers(index: Int, percentage: CGFloat, currentIndex: Int, nextIndex: Int) {
        if index != previousImageIndex {
            CATransaction.animationWithDuration(0) { layer.contents = self.cgImages[currentIndex] }
            
            if nextBlurLayer == nil {
                let nextBlurLayer = CALayer()
                nextBlurLayer.frame = bounds
                layer.addSublayer(nextBlurLayer)
                self.nextBlurLayer = nextBlurLayer
            }
            
            CATransaction.animationWithDuration(0) {
                self.nextBlurLayer?.contents = self.cgImages[nextIndex]
                self.nextBlurLayer?.opacity = 1.0
            }
        }
        previousImageIndex = index
        
        let minPercentage = percentage * 100.0
        let alpha = min(max((minPercentage - CGFloat(Int(minPercentage / 10.0)  * 10)) / 10.0, 0.0), 1.0)
        CATransaction.animationWithDuration(0) { self.nextBlurLayer?.opacity = Float(alpha) }
    }
}

//MARK: - Animation blur
extension SABlurImageView: CAAnimationDelegate {
    public func startBlurAnimation(duration duration: NSTimeInterval) {
        if isBlurAnimating { return }
        isBlurAnimating = true
        let count = cgImages.count
        let group = CAAnimationGroup()
        group.animations = cgImages.enumerate().flatMap {
            guard $0.index < count - 1 else { return nil }
            let anim = CABasicAnimation(keyPath: Const.contentsAnimationKey)
            anim.fromValue = $0.element
            anim.toValue = cgImages[$0.index + 1]
            anim.fillMode = kCAFillModeForwards
            anim.removedOnCompletion = false
            anim.duration = duration / NSTimeInterval(count)
            anim.beginTime = anim.duration * NSTimeInterval($0.index)
            return anim
        }
        group.duration = duration
        group.delegate = self
        group.removedOnCompletion = false
        group.fillMode = kCAFillModeForwards
        layer.addAnimation(group, forKey: Const.fadeAnimationKey)
        cgImages = cgImages.reverse()
    }
    
    public func animationDidStop(anim: CAAnimation, finished flag: Bool) {
        guard let _ = anim as? CAAnimationGroup else { return }
        layer.removeAnimationForKey(Const.fadeAnimationKey)
        isBlurAnimating = false
        guard let cgImage = cgImages.first else { return }
        image = UIImage(CGImage: cgImage)
    }
}
