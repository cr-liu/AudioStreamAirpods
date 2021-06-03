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
    var messages: [String] = []
    var host: String = "LocalHost"
    var port: Int = 12345
    // Only works on ipv4 or ipv6; if need both, create instance in the pipline!
    let h16D320Ch1Handler = H16D320Ch1ServerHandler()
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    private var channel: Channel?
    private lazy var serverBootstrap = ServerBootstrap(group: group)
        // Specify backlog and enable SO_REUSEADDR for the server itself
        .serverChannelOption(ChannelOptions.backlog, value: 16) // max clients
        .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        
        // Set the handlers that are applied to the accepted Channels
        .childChannelInitializer { channel in
            // Add handler that will buffer data until a \n is received
            channel.pipeline.addHandlers([BackPressureHandler(), self.h16D320Ch1Handler])
//            channel.pipeline.addHandlers([self.h16D320Ch1Handler])
        }
        
        // Enable SO_REUSEADDR for the accepted Channels
        .childChannelOption(ChannelOptions.socketOption(.tcp_nodelay), value: 1)
        .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
        .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
    
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
            channel = try self.serverBootstrap.bind(host: self.host, port: self.port).wait()
            try channel?.closeFuture.wait()
        } catch let error {
            messages.append("Could not start TCP server! (\(error.localizedDescription))!")
        }
    }
    
    func asyncRun() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.run()
        }
    }
    
    func shutdown() {
        channel?.close(mode: .all, promise: nil)
    }
    
    func prepareHeader() {
        h16D320Ch1Handler.preparePktHeader()
    }
    
    func send2Channels(_ dataArray: ContiguousArray<Int16>) {
        h16D320Ch1Handler.cmdFromServer(send: dataArray)
    }
}

final class H16D320Ch1ServerHandler: H16D320Ch1, ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer
    
    var messages: [String] = []
    private var packetID: Int32 = 0
    var isAntitarget: Bool = false
    private var buf: ByteBuffer = ByteBufferAllocator().buffer(capacity: 336)
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
            self.messages.append("\(remoteAddress) connected.")
            self.hasClient = true
        }
    }
    
    public func channelInactive(context: ChannelHandlerContext) {
        let channel = context.channel
        self.channelsSyncQueue.async {
            if self.channels.removeValue(forKey: ObjectIdentifier(channel)) != nil {
                self.messages.append(String(describing: self.remoteAddresses[ObjectIdentifier(channel)]) + " disconnected.")
                self.remoteAddresses.removeValue(forKey: ObjectIdentifier(channel))
                if self.channels.isEmpty {
                    self.hasClient = false
                }
            }
        }
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var read = self.unwrapInboundIn(data)
        if read.readString(length: read.readableBytes) == "AudioStreamAirpods" {
            messages.append("Connection from iOS.")
        } else {
            messages.append("Unexpected incoming packet, ignored.")
        }
    }
    
    func preparePktHeader() {
        self.channelsSyncQueue.async {
            let unixtimeDouble: Double = Date().timeIntervalSince1970
            let unixtime: Int32 = Int32(floor(unixtimeDouble))
            let milisec: Int16 = Int16((unixtimeDouble - Double(unixtime)) * 1000)
            self.sktHeader = H16D320Ch1Header(unixTime: unixtime, ms: milisec, pktID: self.packetID, humanID: 0,
                                                 isAntitarget: self.isAntitarget ? -1 : 1, speechActivity: 0)
            self.packetID += 1
        }
    }
    
    func prepareBuf(_ dataArray: ContiguousArray<Int16>) {
        buf.moveWriterIndex(to: 0)
        let rawPtr = buf.withUnsafeMutableWritableBytes{ $0 }.baseAddress!
        writeH16D320Ch1(to: rawPtr, dataArray: dataArray)
        buf.moveWriterIndex(to: 336)
    }
    
    func cmdFromServer(send dataArray: ContiguousArray<Int16>) {
        if !hasClient { return }
        self.channelsSyncQueue.async {
            self.prepareBuf(dataArray)
            self.writeToAll(channels: self.channels, buffer: self.buf)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        messages.append("error: \(error)")
        context.close(promise: nil)
    }

    private func writeToAll(channels: [ObjectIdentifier: Channel], buffer: ByteBuffer) {
        channels.forEach { $0.value.writeAndFlush(buffer, promise: nil) }
    }
}
