//
//  LightRaysMetalView.swift
//  fullmoon
//
//  Animating light rays background using Metal (exact shader from reference).
//

import SwiftUI
#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import Metal
import MetalKit

// MARK: - Parameters

enum LightRaysOrigin {
    case topCenter
    case topLeft
    case topRight
    case left
    case right
    case bottomLeft
    case bottomCenter
    case bottomRight
}

struct LightRaysParameters {
    var raysOrigin: LightRaysOrigin
    var raysColor: Color
    var raysSpeed: Float
    var lightSpread: Float
    var rayLength: Float
    var noiseAmount: Float
    var distortion: Float
    var pulsating: Bool
    var fadeDistance: Float
    var saturation: Float

    static let `default` = LightRaysParameters(
        raysOrigin: .topCenter,
        raysColor: .white,
        raysSpeed: 2.0,
        lightSpread: 0.5,
        rayLength: 3.0,
        noiseAmount: 0.0,
        distortion: 0.0,
        pulsating: false,
        fadeDistance: 1.0,
        saturation: 1.0
    )

    func rayPosAndDir(w: Float, h: Float) -> (pos: SIMD2<Float>, dir: SIMD2<Float>) {
        let outside: Float = 0.2
        switch raysOrigin {
        case .topLeft:
            return (SIMD2(0, -outside * h), SIMD2(0, 1))
        case .topRight:
            return (SIMD2(w, -outside * h), SIMD2(0, 1))
        case .topCenter:
            return (SIMD2(0.5 * w, -outside * h), SIMD2(0, 1))
        case .left:
            return (SIMD2(-outside * w, 0.5 * h), SIMD2(1, 0))
        case .right:
            return (SIMD2((1 + outside) * w, 0.5 * h), SIMD2(-1, 0))
        case .bottomLeft:
            return (SIMD2(0, (1 + outside) * h), SIMD2(0, -1))
        case .bottomCenter:
            return (SIMD2(0.5 * w, (1 + outside) * h), SIMD2(0, -1))
        case .bottomRight:
            return (SIMD2(w, (1 + outside) * h), SIMD2(0, -1))
        }
    }

    func raysColorFloat3() -> SIMD3<Float> {
        #if os(macOS)
        let nsColor = NSColor(raysColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD3<Float>(Float(r), Float(g), Float(b))
        #else
        let uiColor = UIColor(raysColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD3<Float>(Float(r), Float(g), Float(b))
        #endif
    }
}

// MARK: - Renderer

final class LightRaysRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    let vertexBuffer: MTLBuffer
    var startTime: CFTimeInterval

    init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        self.startTime = CACurrentMediaTime()

        let vertices: [SIMD2<Float>] = [
            SIMD2(-1, -1), SIMD2(1, -1), SIMD2(-1, 1),
            SIMD2(-1, 1), SIMD2(1, -1), SIMD2(1, 1),
        ]
        guard let buf = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<SIMD2<Float>>.stride,
            options: .storageModeShared
        ) else { return nil }
        self.vertexBuffer = buf

        guard let library = device.makeDefaultLibrary(),
              let vertexFn = library.makeFunction(name: "vertex_light_rays"),
              let fragmentFn = library.makeFunction(name: "fragment_light_rays") else {
            return nil
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFn
        pipelineDescriptor.fragmentFunction = fragmentFn
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            return nil
        }

        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let lightRaysView = view as? LightRaysMTKView,
              let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        let params = lightRaysView.parameters
        let time = Float(CACurrentMediaTime() - startTime)
        let w = Float(view.drawableSize.width)
        let h = Float(view.drawableSize.height)
        let (rayPos, rayDir) = params.rayPosAndDir(w: w, h: h)
        var raysColor = params.raysColorFloat3()

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        var timeVal = time
        var resolutionVal = SIMD2<Float>(w, h)
        var rayPosVal = rayPos
        var rayDirVal = rayDir
        var raysColorVal = raysColor
        var raysSpeed = params.raysSpeed
        var lightSpread = params.lightSpread
        var rayLength = params.rayLength
        var pulsating: Float = params.pulsating ? 1.0 : 0.0
        var fadeDistance = params.fadeDistance
        var saturation = params.saturation
        var noiseAmount = params.noiseAmount
        var distortion = params.distortion

        encoder.setFragmentBytes(&timeVal, length: MemoryLayout<Float>.stride, index: 0)
        encoder.setFragmentBytes(&resolutionVal, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
        encoder.setFragmentBytes(&rayPosVal, length: MemoryLayout<SIMD2<Float>>.stride, index: 2)
        encoder.setFragmentBytes(&rayDirVal, length: MemoryLayout<SIMD2<Float>>.stride, index: 3)
        encoder.setFragmentBytes(&raysColorVal, length: MemoryLayout<SIMD3<Float>>.stride, index: 4)
        encoder.setFragmentBytes(&raysSpeed, length: MemoryLayout<Float>.stride, index: 5)
        encoder.setFragmentBytes(&lightSpread, length: MemoryLayout<Float>.stride, index: 6)
        encoder.setFragmentBytes(&rayLength, length: MemoryLayout<Float>.stride, index: 7)
        encoder.setFragmentBytes(&pulsating, length: MemoryLayout<Float>.stride, index: 8)
        encoder.setFragmentBytes(&fadeDistance, length: MemoryLayout<Float>.stride, index: 9)
        encoder.setFragmentBytes(&saturation, length: MemoryLayout<Float>.stride, index: 10)
        encoder.setFragmentBytes(&noiseAmount, length: MemoryLayout<Float>.stride, index: 11)
        encoder.setFragmentBytes(&distortion, length: MemoryLayout<Float>.stride, index: 12)

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - MTKView

#if os(iOS) || os(visionOS)
final class LightRaysMTKView: MTKView {
    var renderer: LightRaysRenderer?
    var parameters: LightRaysParameters = .default

    override init(frame: CGRect, device: MTLDevice?) {
        let dev = device ?? MTLCreateSystemDefaultDevice()!
        super.init(frame: frame, device: dev)
        commonInit(device: dev)
    }

    required init(coder: NSCoder) {
        let dev = MTLCreateSystemDefaultDevice()!
        super.init(coder: coder)
        device = dev
        commonInit(device: dev)
    }

    private func commonInit(device: MTLDevice) {
        framebufferOnly = true
        clearColor = MTLClearColor(red: 0.08, green: 0.06, blue: 0.1, alpha: 1)
        preferredFramesPerSecond = 60
        enableSetNeedsDisplay = false
        isPaused = false
        if let r = LightRaysRenderer(device: device) {
            renderer = r
            delegate = r
        }
    }
}

struct LightRaysMetalView: UIViewRepresentable {
    var raysOrigin: LightRaysOrigin = .topCenter
    var raysColor: Color = .white
    var raysSpeed: Float = 2.0
    var lightSpread: Float = 0.5
    var rayLength: Float = 3.0
    var noiseAmount: Float = 0.0
    var distortion: Float = 0.0
    var pulsating: Bool = false
    var fadeDistance: Float = 1.0
    var saturation: Float = 1.0

    func makeUIView(context: Context) -> LightRaysMTKView {
        let dev = MTLCreateSystemDefaultDevice()!
        let v = LightRaysMTKView(frame: .zero, device: dev)
        v.parameters = LightRaysParameters(
            raysOrigin: raysOrigin,
            raysColor: raysColor,
            raysSpeed: raysSpeed,
            lightSpread: lightSpread,
            rayLength: rayLength,
            noiseAmount: noiseAmount,
            distortion: distortion,
            pulsating: pulsating,
            fadeDistance: fadeDistance,
            saturation: saturation
        )
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return v
    }

    func updateUIView(_ uiView: LightRaysMTKView, context: Context) {
        uiView.parameters = LightRaysParameters(
            raysOrigin: raysOrigin,
            raysColor: raysColor,
            raysSpeed: raysSpeed,
            lightSpread: lightSpread,
            rayLength: rayLength,
            noiseAmount: noiseAmount,
            distortion: distortion,
            pulsating: pulsating,
            fadeDistance: fadeDistance,
            saturation: saturation
        )
    }
}
#elseif os(macOS)
final class LightRaysMTKView: MTKView {
    var renderer: LightRaysRenderer?
    var parameters: LightRaysParameters = .default

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        let dev = device ?? MTLCreateSystemDefaultDevice()!
        super.init(frame: frameRect, device: dev)
        commonInit(device: dev)
    }

    required init(coder: NSCoder) {
        let dev = MTLCreateSystemDefaultDevice()!
        super.init(coder: coder)
        device = dev
        commonInit(device: dev)
    }

    private func commonInit(device: MTLDevice) {
        framebufferOnly = true
        clearColor = MTLClearColor(red: 0.08, green: 0.06, blue: 0.1, alpha: 1)
        preferredFramesPerSecond = 60
        isPaused = false
        if let r = LightRaysRenderer(device: device) {
            renderer = r
            delegate = r
        }
    }
}

struct LightRaysMetalView: NSViewRepresentable {
    var raysOrigin: LightRaysOrigin = .topCenter
    var raysColor: Color = .white
    var raysSpeed: Float = 2.0
    var lightSpread: Float = 0.5
    var rayLength: Float = 3.0
    var noiseAmount: Float = 0.0
    var distortion: Float = 0.0
    var pulsating: Bool = false
    var fadeDistance: Float = 1.0
    var saturation: Float = 1.0

    func makeNSView(context: Context) -> LightRaysMTKView {
        let dev = MTLCreateSystemDefaultDevice()!
        let v = LightRaysMTKView(frame: .zero, device: dev)
        v.parameters = LightRaysParameters(
            raysOrigin: raysOrigin,
            raysColor: raysColor,
            raysSpeed: raysSpeed,
            lightSpread: lightSpread,
            rayLength: rayLength,
            noiseAmount: noiseAmount,
            distortion: distortion,
            pulsating: pulsating,
            fadeDistance: fadeDistance,
            saturation: saturation
        )
        v.autoresizingMask = [.width, .height]
        return v
    }

    func updateNSView(_ nsView: LightRaysMTKView, context: Context) {
        nsView.parameters = LightRaysParameters(
            raysOrigin: raysOrigin,
            raysColor: raysColor,
            raysSpeed: raysSpeed,
            lightSpread: lightSpread,
            rayLength: rayLength,
            noiseAmount: noiseAmount,
            distortion: distortion,
            pulsating: pulsating,
            fadeDistance: fadeDistance,
            saturation: saturation
        )
    }
}
#endif
