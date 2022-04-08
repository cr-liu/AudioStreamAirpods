//
//  AudioUdpServer.swift
//  AudioStreamAirpods
//
//  Created by liu on 2022/04/05.
//

import Foundation
import NIO

class AudioUdpServer {
    weak var viewModel: SensorViewModel?
    var isReceiving: Bool = false
    var packetBuf: RingBuffer<UInt8>?
    var h80D10ms16kHandler = H80D10ms16kUdpServerHandler()
    var host: String = "0.0.0.0"
    var port: Int = 12345
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var channel: Channel?
    private lazy var serverBootstrap = DatagramBootstrap(group: group)
        .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR),
                       value: 1)
        .channelOption(ChannelOptions.recvAllocator,
                       value: FixedSizeRecvByteBufferAllocator(capacity: 2048))
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
            if h80D10ms16kHandler.viewModel == nil {
                h80D10ms16kHandler.viewModel = viewModel
            }
            channel = try serverBootstrap.bind(to: .init(ipAddress: host, port: port)).wait()
            isReceiving = true
            DispatchQueue.main.async {
                self.viewModel?.isReceiving = true
                self.viewModel?.addMessage("UDP server started and listen on port: \(self.port).")
            }
            try channel?.closeFuture.wait()
        } catch let error {
            DispatchQueue.main.async {
                self.viewModel?.addMessage("Failed to start UDP server! (\(error.localizedDescription)")
            }
        }
    }
    
    func AsyncStart() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.start()
        }
    }
    
    func stop() {
        if !isReceiving {
            return
        }
        channel?.close(mode: .all, promise: nil)
        isReceiving = false
        DispatchQueue.main.async {
            self.viewModel?.isReceiving = false
            self.viewModel?.addMessage("UDP receiver closed.")
        }
    }
}

final class H80D10ms16kUdpServerHandler: H80D10ms16k, ChannelInboundHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    typealias OutboundOut = AddressedEnvelope<ByteBuffer>

    weak var viewModel: SensorViewModel?
    private let packetSize = 1024 // 512 // 400
    lazy var packetBuf = RingBuffer<UInt8>(repeating: 0, count: packetSize * 60)
    weak var ringBuf: RingBuffer<Int16>?
    
//    public func channelActive(context: ChannelHandlerContext) {
//        DispatchQueue.main.async {
//            self.viewModel?.addMessage("Start receiving..")
//        }
//    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data).data
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
