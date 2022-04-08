//
//  AudioUdpClient.swift
//  AudioStreamAirpods
//
//  Created by liu on 2022/04/05.
//

import Foundation
import NIO

class AudioUdpClient {
    weak var viewModel: SensorViewModel?
    var isSending: Bool = false
    // UDP broadcast
    var host: String = "255.255.255.255"
    var port: Int = 12345
    var h80D10ms16kHandler = H80D10ms16kUdpClientHandler()
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var channel: Channel?
    private var clientBootstrap: DatagramBootstrap!
        // Set the handlers that are applied to the accepted Channels
    
    init(withImu imuPtr: UnsafeRawPointer) {
        h80D10ms16kHandler.imuDataPtr = imuPtr
    }
    
    deinit {
        do {
            try group.syncShutdownGracefully()
        } catch let error {
            print("Could not shutdown gracefully - forcing exit (\(error.localizedDescription))!")
            exit(0)
        }
    }

    func run()  {
        do {
            h80D10ms16kHandler.remoteAddressInitializer(self.host, port: self.port)
            clientBootstrap = DatagramBootstrap(group: group)
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR),
                               value: 1)
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_BROADCAST),
                               value: 1)
                .channelInitializer { channel in
                    channel.pipeline.addHandlers(self.h80D10ms16kHandler)
                }
            channel = try clientBootstrap.bind(to: .init(ipAddress: "0.0.0.0", port: port)).wait()
            isSending = true
            DispatchQueue.main.async {
                self.viewModel?.isSending = true
                self.viewModel?.addMessage("UDP send on port \(self.port).")
            }
            try channel?.closeFuture.wait()
        } catch let error {
            DispatchQueue.main.async {
                self.viewModel?.addMessage("Could not start TCP server! (\(error.localizedDescription))!")
            }
        }
    }
    
    func asyncRun() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.run()
        }
    }
    
    func shutdown() {
        if !isSending {
            return
        }
        channel?.close(mode: .all, promise: nil)
        isSending = false
        DispatchQueue.main.async {
            self.viewModel?.isSending = false
            self.viewModel?.addMessage("UDP sender closed.")
        }
    }
    
    func prepareHeader() {
        h80D10ms16kHandler.preparePktHeader()
    }
    
    func send2Channels(_ dataArray: Array<Int16>) {
        h80D10ms16kHandler.cmdFromServer(send: dataArray)
    }
}


final class H80D10ms16kUdpClientHandler: H80D10ms16k, ChannelInboundHandler {
    public typealias InboundIn = AddressedEnvelope<ByteBuffer>
    public typealias OutboundOut = AddressedEnvelope<ByteBuffer>
    
    static let sktSize = 1024 // 512 // 400
    var messages: [String] = []
    var isAntitarget: Bool = false
    private var packetID: Int32 = 0
    private var buf: ByteBuffer = ByteBufferAllocator().buffer(capacity: sktSize)
    private let channelsSyncQueue = DispatchQueue(label: "udpQueue", qos: .userInitiated)
    private var channel: Channel?
    private var remoteAddress: SocketAddress?
//    private let remoteAddressInitializer: () throws -> SocketAddress
    
    func remoteAddressInitializer(_ host: String, port: Int) {
        do {
            remoteAddress = try SocketAddress.makeAddressResolvingHost(host, port: port)
        } catch let error {
            messages.append("Could not resolve host! (\(error.localizedDescription)")
        }
    }
    
    public func channelActive(context: ChannelHandlerContext) {
        channel = context.channel
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var read = self.unwrapInboundIn(data).data
        if read.readString(length: read.readableBytes) == "AudioStreamAirpods" {
            messages.append("Connection from iOS.")
        } else {
            messages.append("Unexpected incoming packet, ignored.")
        }
    }
    
    func preparePktHeader() {
        channelsSyncQueue.async {
            let unixtimeDouble: Double = Date().timeIntervalSince1970
            let unixtime: Int32 = Int32(floor(unixtimeDouble))
            let milisec: Int16 = Int16((unixtimeDouble - Double(unixtime)) * 1000)
            self.sktHeader = H80D10ms16kHeader(unixTime: unixtime, ms: milisec, pktID: self.packetID, humanID: 0,
                                              isAntitarget: self.isAntitarget ? -1 : 1, speechActivity: 0)
            self.packetID += 1
        }
    }
    
    func prepareBuf(_ dataArray: Array<Int16>) {
//        for i in 0 ..< dataArray.count {
//            stereoData[i * 2] = dataArray[i]
//            stereoData[i * 2 + 1] = dataArray[i]
//        }
        buf.moveWriterIndex(to: 0)
        let rawPtr = buf.withUnsafeMutableWritableBytes{ $0 }.baseAddress!
        writeSocketBuf(to: rawPtr, withSound: dataArray)
        buf.moveWriterIndex(to: buf.capacity)
    }
    
    func cmdFromServer(send dataArray: Array<Int16>) {
        channelsSyncQueue.async {
            self.prepareBuf(dataArray)
            self.channel?.writeAndFlush(
                self.wrapOutboundOut(AddressedEnvelope<ByteBuffer>(remoteAddress: self.remoteAddress!, data: self.buf)),
                promise: nil)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        messages.append("error: \(error)")
        context.close(promise: nil)
    }
}

