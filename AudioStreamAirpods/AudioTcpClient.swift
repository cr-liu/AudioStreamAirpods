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
    weak var viewModel: SensorViewModel?
    var isConnected: Bool = false
    var packetBuf: RingBuffer<UInt8>?
    var h80D10ms16kHandler = H80D10ms16kTcpClientHandler()
    var host: String = ""
    var port: Int = 0
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
            DispatchQueue.main.async {
                self.viewModel?.addMessage("Could not shutdown gracefully - forcing exit (\(error.localizedDescription))!")
            }
            exit(0)
        }
    }
    
    func setBuffer(_ buf: RingBuffer<Int16>) {
        h80D10ms16kHandler.ringBuf = buf
    }
    
    func start() {
        do {
            DispatchQueue.main.async {
                self.viewModel?.addMessage("Try connect to \(self.host):\(self.port)")
            }
            channel = try clientBootstrap.connect(host: self.host, port: self.port).wait()
            isConnected = true
            DispatchQueue.main.async {
                self.viewModel?.isReceiving = true
                self.viewModel?.addMessage("Connected to \(self.host):\(self.port).")
            }
//            try channel?.closeFuture.wait()
        } catch let error {
            DispatchQueue.main.async {
                self.viewModel?.addMessage("Failed to connect! (\(error.localizedDescription)")
            }
        }
    }
    
    func AsyncStart() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.start()
        }
    }
    
    func stop() {
        if !isConnected {
            return
        }
        channel?.close(mode: .all, promise: nil)
        isConnected = false
        DispatchQueue.main.async {
            self.viewModel?.isReceiving = false
            self.viewModel?.addMessage("Disconnected from \(self.host):\(self.port).")
        }
    }
}


class H80D10ms16kTcpClientHandler: H80D10ms16k, ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private let packetSize = 1024 // 512 // 400
    lazy var packetBuf = RingBuffer<UInt8>(repeating: 0, count: packetSize * 60)
    weak var ringBuf: RingBuffer<Int16>?
    weak var viewModel: SensorViewModel?
    
    func channelActive(context: ChannelHandlerContext) {
        let message = "AudioStreamAirpods"
        var buffer = context.channel.allocator.buffer(capacity: message.utf8.count)
        buffer.writeString(message)
        context.writeAndFlush(wrapOutboundOut(buffer), promise: nil)
    }
    
    public func channelInactive(context: ChannelHandlerContext) {
        context.close(mode: .all, promise: nil)
        DispatchQueue.main.async {
            self.viewModel?.isReceiving = false
            self.viewModel?.addMessage("Connection closed by server.")
        }
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
//        print(buffer.readableBytes)
        packetBuf.pushBack(buffer.readBytes(length: buffer.readableBytes)!)
        let nPackets: Int = packetBuf.count / packetSize
        for _ in 0 ..< nPackets {
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
