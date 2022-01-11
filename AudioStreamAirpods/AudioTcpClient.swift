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
    var h80D10ms16kHandler = H80D10ms16kClientHandler()
    var host: String = "192.168.1.10"
    var port: Int = 12345
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var channel: Channel?
    private lazy var clientBootstrap = ClientBootstrap(group: group)
        .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        .channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
        .channelOption(ChannelOptions.recvAllocator,
                       value: AdaptiveRecvByteBufferAllocator())
        .channelInitializer { channel in
            channel.pipeline.addHandler(self.h80D10ms16kHandler)
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
        h80D10ms16kHandler.ringBuf = buf
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


class H80D10ms16kClientHandler: H80D10ms16k, ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private let packetSize = 1024 // 512 // 400
    lazy var packetBuf = RingBuffer<UInt8>(repeating: 0, count: packetSize * 60)
    weak var ringBuf: RingBuffer<Int16>?
    
    func channelActive(context: ChannelHandlerContext) {
        let message = "AudioStreamAirpods"
        var buffer = context.channel.allocator.buffer(capacity: message.utf8.count)
        buffer.writeString(message)
        context.writeAndFlush(wrapOutboundOut(buffer), promise: nil)
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
//        print(buffer.readableBytes)
        packetBuf.pushBack(buffer.readBytes(length: buffer.readableBytes)!)
        if packetBuf.count >= packetSize {
            readPacket()
            ringBuf!.pushBack(stereoData)
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: \(error.localizedDescription)")
        context.close(promise: nil)
    }
    
    func readPacket() {
        let packet = packetBuf.popFront(packetSize)
        let movingPtr = packet.withUnsafeBytes{ $0 }.baseAddress! + headerSize
        if audioChannels == 2 {
            let stereoDataPtr = stereoData.withUnsafeMutableBytes{ $0 }
            memcpy(stereoDataPtr.baseAddress, movingPtr, stereoData.count * MemoryLayout<Int16>.size)
        } else {
            let monoDataPtr = monoData.withUnsafeMutableBytes{ $0 }
            memcpy(monoDataPtr.baseAddress, movingPtr, monoData.count * MemoryLayout<Int16>.size)
            for i in 0 ..< monoData.count {
                stereoData[i * 2] = monoData[i]
                stereoData[i * 2 + 1] = monoData[i]
            }
        }
    }
}
