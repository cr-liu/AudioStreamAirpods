//
//  AudioTcpServer.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/19.
//

import Foundation
import NIO
import Dispatch

class AudioTcpServer {
    weak var viewModel: SensorViewModel?
    var isListening: Bool = false
    var host: String = "LocalHost"
    var port: Int = 0
    // Only works on ipv4 or ipv6; if need both, create instance in the pipline!
    let h80D10ms16kHandler = H80D10ms16kTcpServerHandler()
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    private var channel: Channel?
    private lazy var serverBootstrap = ServerBootstrap(group: group)
        // Specify backlog and enable SO_REUSEADDR for the server itself
        .serverChannelOption(ChannelOptions.backlog, value: 16) // max clients
        .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        
        // Set the handlers that are applied to the accepted Channels
        .childChannelInitializer { channel in
            // Add handler that will buffer data until a \n is received
            channel.pipeline.addHandlers([self.h80D10ms16kHandler])
//            channel.pipeline.addHandlers([self.h16D320Ch1Handler])
        }
        
        // Enable SO_REUSEADDR for the accepted Channels
        .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
        .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
        .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
    
    init(withImu imuPtr: UnsafeRawPointer) {
        h80D10ms16kHandler.imuDataPtr = imuPtr
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

    func run()  {
        do {
            channel = try self.serverBootstrap.bind(host: self.host, port: self.port).wait()
            isListening = true
            DispatchQueue.main.async {
                self.viewModel?.isSending = true
                self.viewModel?.addMessage("TCP server started and listen on port: \(self.port).")
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
        if !isListening {
            return
        }
        channel?.close(mode: .all, promise: nil)
        h80D10ms16kHandler.closeAll()
        isListening = false
        DispatchQueue.main.async {
            self.viewModel?.isSending = false
            self.viewModel?.addMessage("TCP server closed.")
        }
    }
    
    func prepareHeader() {
        h80D10ms16kHandler.preparePktHeader()
    }
    
    func send2Channels(_ dataArray: Array<Int16>) {
        h80D10ms16kHandler.cmdFromServer(send: dataArray)
    }
}


final class H80D10ms16kTcpServerHandler: H80D10ms16k, ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer
    
    static let sktSize = 1024 // 512 // 400
    weak var viewModel: SensorViewModel?
    var isAntitarget: Bool = false
    private var packetID: Int32 = 0
    private var buf: ByteBuffer = ByteBufferAllocator().buffer(capacity: sktSize)
    private let channelsSyncQueue = DispatchQueue(label: "tcpQueue", qos: .userInitiated)
    private var channels: [ObjectIdentifier: Channel] = [:]
    private var remoteAddresses: [ObjectIdentifier: String] = [:]
    private var hasClient: Bool = false
    
    public func channelActive(context: ChannelHandlerContext) {
        let remoteAddress = context.remoteAddress!
        let channel = context.channel
        self.channelsSyncQueue.async {
            self.channels[ObjectIdentifier(channel)] = channel
            self.remoteAddresses[ObjectIdentifier(channel)] = remoteAddress.ipAddress!
            self.hasClient = true
        }
        DispatchQueue.main.async {
            self.viewModel?.addMessage(remoteAddress.ipAddress! + " connected.")
        }
    }
    
    public func channelInactive(context: ChannelHandlerContext) {
        let channel = context.channel
        context.close(mode: .all, promise: nil)
        if self.channels.removeValue(forKey: ObjectIdentifier(channel)) != nil {
            let remoteAddress: String = self.remoteAddresses[ObjectIdentifier(channel)]!
            DispatchQueue.main.async {
                self.viewModel?.addMessage(remoteAddress + " disconnected.")
            }
            self.remoteAddresses.removeValue(forKey: ObjectIdentifier(channel))
            if self.channels.isEmpty {
                self.hasClient = false
            }
        }
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var read = self.unwrapInboundIn(data)
        if read.readString(length: read.readableBytes) == "AudioStreamAirpods" {
            DispatchQueue.main.async {
                self.viewModel?.addMessage("Connection from iOS.")
            }
        } else {
            DispatchQueue.main.async {
                self.viewModel?.addMessage("Unexpected incoming packet, ignored.")
            }
        }
    }
    
    func preparePktHeader() {
        self.channelsSyncQueue.async {
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
        if !hasClient { return }
        self.prepareBuf(dataArray)
        self.channelsSyncQueue.async {
            self.writeToAll(channels: self.channels, buffer: self.buf)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        DispatchQueue.main.async {
            self.viewModel?.addMessage("error: \(error)")
        }
        context.close(promise: nil)
    }

    private func writeToAll(channels: [ObjectIdentifier: Channel], buffer: ByteBuffer) {
        channels.forEach { $0.value.writeAndFlush(buffer, promise: nil) }
    }
    
    fileprivate func closeAll() {
        self.channels.forEach { $0.value.close(mode: .all, promise: nil) }
        self.hasClient = false
    }
}
