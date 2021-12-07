//
//  AudioTcpClient.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/29.
//

import Foundation
import Accelerate
import NIO

class AudioTcpClient {
    var messages: [String] = []
    var isConnected: Bool = false
    var packetBuf: RingBuffer<UInt8>?
    var h16D320Handler = H16D320Ch1ClientHandler()
    var h80D320Handler = H80D320Ch1ClientHandler()
    var host: String = "192.168.1.10"
    var port: Int = 12345
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var channel: Channel?
    private lazy var clientBootstrap = ClientBootstrap(group: group)
        .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        .channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
        .channelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        .channelInitializer { channel in
            channel.pipeline.addHandler(self.h80D320Handler)
        }

    
    deinit {
        do {
            try group.syncShutdownGracefully()
        } catch let error {
            print("Could not shutdown gracefully - forcing exit (\(error.localizedDescription))!")
            exit(0)
        }
    }
    
    func setBuffer(_ buf: RingBuffer<Int16>) {
        h80D320Handler.ringBuf = buf
    }
    
    func start() {
        do {
            channel = try clientBootstrap.connect(host: self.host, port: self.port).wait()
            isConnected = true
            messages.append("Connected to \(host):\(port).")
            try channel?.closeFuture.wait()
        } catch let error {
            isConnected = false
            messages.append("Failed to connect! (\(error.localizedDescription)")
        }
    }
    
    func AsyncStart() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.start()
        }
    }
    
    func stop() {
        channel?.close(mode: .all, promise: nil)
        isConnected = false
        messages.append("Disconnected from \(host):\(port).")
    }
}


class H16D320Ch1ClientHandler: H16D320Ch1, ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer
    
    func channelActive(context: ChannelHandlerContext) {
        let message = "AudioStreamAirpods"
        var buffer = context.channel.allocator.buffer(capacity: message.utf8.count)
        buffer.writeString(message)
        context.writeAndFlush(wrapOutboundOut(buffer), promise: nil)
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        let ptr = buffer.withUnsafeMutableReadableBytes{ $0 }.baseAddress!
        readH16D320Ch1(from: ptr)
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: \(error.localizedDescription)")
        context.close(promise: nil)
    }
}


class H80D320Ch1ClientHandler: H80D320Ch1, ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private let packetSize = 1024 // 512 // 400
    lazy var packetBuf = RingBuffer<UInt8>(repeating: 0, count: packetSize * 10)
    weak var ringBuf: RingBuffer<Int16>?
    private var soundData = Array<Int16>(repeating: 0, count: 160)

    
    func channelActive(context: ChannelHandlerContext) {
        let message = "AudioStreamAirpods"
        var buffer = context.channel.allocator.buffer(capacity: message.utf8.count)
        buffer.writeString(message)
        context.writeAndFlush(wrapOutboundOut(buffer), promise: nil)
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        packetBuf.pushBack(buffer.readBytes(length: buffer.readableBytes)!)
        if packetBuf.count >= packetSize {
            readH80D320Ch1()
//            self.ringBuf!.pushBack(soundData48k)
            ringBuf!.pushBack(soundData)
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: \(error.localizedDescription)")
        context.close(promise: nil)
    }
    
    func readH80D320Ch1() {
        let packet = packetBuf.popFront(packetSize)
        let movingPtr = packet.withUnsafeBytes{ $0 }.baseAddress! + headerSize
        let sndDataPtr = soundData.withUnsafeMutableBytes{ $0 }.baseAddress!
        memcpy(sndDataPtr, movingPtr, (soundData.count) * MemoryLayout<Int16>.size)
    }
    
    // upsampling
    //        let stride1 = vDSP_Stride(1)
    //        let indices = Array<Float32>(stride(from: 0, through: 481, by: 3))
    //        var soundData48k = Array<Int16>(repeating: 0, count: 480)
    //        // added 1 for upsampling
    //        private var soundData = Array<Int16>(repeating: 0, count: 161)
    //        private var soundDataUpsampled = Array<Float32>(repeating: 0, count: 481)
    //        for i in 0..<(soundData.count - 1) {
    //            let oneThirdDiff = (soundData[i + 1] - soundData[i]) / 3
    //            soundData48k[i] = soundData[i] + oneThirdDiff
    //            soundData48k[i + 1] = soundData[i + 1] - oneThirdDiff
    //            soundData48k[i + 2] = soundData[i + 1]
    //        }
    //        vDSP_vgenp(soundData.map{Float32($0)}, stride1, indices, stride1, &soundDataUpsampled, stride1,
    //                   vDSP_Length(soundData48k.count), vDSP_Length(indices.count))
    //        soundData48k = soundDataUpsampled.dropFirst().map{ Int16($0) }
    //        soundData[0] = soundData.last!
    
//    @inlinable
//    func readH80D320Ch1(from ptr: UnsafeMutableRawPointer, imuTo imuData: inout ContiguousArray<Float32>) {
//        var movingPtr = ptr
//
//        if sktHeader == nil {
//            sktHeader = H80D320Ch1Header()
//        }
//        sktHeader!.unixTime = UnsafeMutablePointer<Int32>(movingPtr.assumingMemoryBound(to: Int32.self)).pointee
//        movingPtr += MemoryLayout<Int32>.size
//        sktHeader!.ms = UnsafeMutablePointer<Int16>(movingPtr.assumingMemoryBound(to: Int16.self)).pointee
//        movingPtr += MemoryLayout<Int16>.size
//        sktHeader!.pktID = UnsafeMutablePointer<Int32>(movingPtr.assumingMemoryBound(to: Int32.self)).pointee
//        movingPtr += MemoryLayout<Int32>.size
//        sktHeader!.humanID = UnsafeMutablePointer<Int32>(movingPtr.assumingMemoryBound(to: Int32.self)).pointee
//        movingPtr += MemoryLayout<Int32>.size
//        sktHeader!.isAntitarget = UnsafeMutablePointer<Int8>(movingPtr.assumingMemoryBound(to: Int8.self)).pointee
//        movingPtr += MemoryLayout<Int8>.size
//        sktHeader!.speechActivity = UnsafeMutablePointer<Int8>(movingPtr.assumingMemoryBound(to: Int8.self)).pointee
//        movingPtr += MemoryLayout<Int8>.size
//
//        for i in 0 ..< imuData.count {
//            imuData[i] = UnsafeMutablePointer<Float32>(movingPtr.assumingMemoryBound(to: Float32.self)).pointee
//            movingPtr += MemoryLayout<Float32>.size
//        }
//        
//        let sndDataPtr = soundData.withUnsafeMutableBytes{ $0 }
//        memcpy(sndDataPtr.baseAddress, movingPtr, soundData.count * MemoryLayout<Int16>.size)
//        var soundDataFloat = Array<Float32>(repeating: 0, count: soundData48k.count)
//        vDSP_vgenp(soundData.map{Float32($0)}, stride1, indices, stride1, &soundDataFloat, stride1,
//                   vDSP_Length(soundData48k.count), vDSP_Length(indices.count))
//        soundData48k = soundDataFloat.map{ Int16($0) }
//        var dataPtr = UnsafeMutablePointer<Int16>((movingPtr + MemoryLayout<Int8>.size).assumingMemoryBound(to: Int16.self))
//        for index in 0 ..< 160 {
//            soundData[index] = dataPtr.pointee
//            dataPtr += 1
//        }
//    }
}
