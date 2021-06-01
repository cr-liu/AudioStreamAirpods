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

final class H16D320Ch1ServerHandler: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer
    
    var messages: [String] = []
    private var packetID: Int32 = 0
    private var packetHeader: H16D320Ch1Header?
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
            messages.append("Unexpected incoming packet, flush to sink.")
        }

        // 64 should be good enough for the ipaddress
//        var buffer = context.channel.allocator.buffer(capacity: read.readableBytes + 64)
//        buffer.writeString("(\(context.remoteAddress!)) - ")
//        buffer.writeBuffer(&read)
//        let id = ObjectIdentifier(context.channel)
//        self.channelsSyncQueue.async {
//            // broadcast the message to all the connected clients except the one that wrote it.
//            self.writeToAll(channels: self.channels.filter { id != $0.key }, buffer: buffer)
//        }
    }
    
    func preparePktHeader() {
        self.channelsSyncQueue.async {
            let unixtimeDouble: Double = Date().timeIntervalSince1970
            let unixtime: Int32 = Int32(floor(unixtimeDouble))
            let milisec: Int16 = Int16((unixtimeDouble - Double(unixtime)) * 1000)
            self.packetHeader = H16D320Ch1Header(unixTime: unixtime, ms: milisec, pktID: self.packetID, humanID: 0,
                                                 isAntitarget: self.isAntitarget ? -1 : 1, speechActivity: 0)
        }
    }
    
    func prepareBuf(_ dataArray: ContiguousArray<Int16>) {
        buf.moveWriterIndex(to: 0)
        let rawPtr = buf.withUnsafeMutableWritableBytes{ $0 }.baseAddress!
        UnsafeMutablePointer<Int32>(rawPtr.assumingMemoryBound(to: Int32.self)).pointee = packetHeader!.unixTime
        var ptr = rawPtr + MemoryLayout<Int32>.size
        UnsafeMutablePointer<Int16>(ptr.assumingMemoryBound(to: Int16.self)).pointee = packetHeader!.ms
        ptr = ptr + MemoryLayout<Int16>.size
        UnsafeMutablePointer<Int32>(ptr.assumingMemoryBound(to: Int32.self)).pointee = packetHeader!.pktID
        ptr = ptr + MemoryLayout<Int32>.size
        UnsafeMutablePointer<Int32>(ptr.assumingMemoryBound(to: Int32.self)).pointee = packetHeader!.humanID
        ptr = ptr + MemoryLayout<Int32>.size
        UnsafeMutablePointer<Int8>(ptr.assumingMemoryBound(to: Int8.self)).pointee = packetHeader!.isAntitarget
        ptr = ptr + MemoryLayout<Int8>.size
        UnsafeMutablePointer<Int8>(ptr.assumingMemoryBound(to: Int8.self)).pointee = packetHeader!.speechActivity
        var dataPtr = UnsafeMutablePointer<Int16>((ptr + MemoryLayout<Int8>.size).assumingMemoryBound(to: Int16.self))
        for frame in dataArray {
            dataPtr.pointee = frame
            dataPtr = dataPtr + 1
        }
        buf.moveWriterIndex(to: 336)
    }
    
    public func cmdFromServer(send dataArray: ContiguousArray<Int16>) {
        if !hasClient { return }
        self.channelsSyncQueue.async {
            self.prepareBuf(dataArray)
            self.writeToAll(channels: self.channels, buffer: self.buf)
        }
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        messages.append("error: \(error)")

        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }

    private func writeToAll(channels: [ObjectIdentifier: Channel], buffer: ByteBuffer) {
        channels.forEach { $0.value.writeAndFlush(buffer, promise: nil) }
    }
}

struct H16D320Ch1Header {
    var unixTime: Int32
    var ms: Int16
    var pktID: Int32
    var humanID: Int32
    var isAntitarget: Int8
    var speechActivity: Int8
}

/// This `ChannelInboundHandler` demonstrates a few things:
///   * Synchronisation between `EventLoop`s.
///   * Mixing `Dispatch` and SwiftNIO.
///   * `Channel`s are thread-safe, `ChannelHandlerContext`s are not.
///
/// As we are using an `MultiThreadedEventLoopGroup` that uses more then 1 thread we need to ensure proper
/// synchronization on the shared state in the `ChatHandler` (as the same instance is shared across
/// child `Channel`s). For this a serial `DispatchQueue` is used when we modify the shared state (the `Dictionary`).
/// As `ChannelHandlerContext` is not thread-safe we need to ensure we only operate on the `Channel` itself while
/// `Dispatch` executed the submitted block.
//final class ChatHandler: ChannelInboundHandler {
//    public typealias InboundIn = ByteBuffer
//    public typealias OutboundOut = ByteBuffer
//
//    // All access to channels is guarded by channelsSyncQueue.
//    private let channelsSyncQueue = DispatchQueue(label: "channelsQueue")
//    private var channels: [ObjectIdentifier: Channel] = [:]
//
//    public func channelActive(context: ChannelHandlerContext) {
//        let remoteAddress = context.remoteAddress!
//        let channel = context.channel
//        self.channelsSyncQueue.async {
//            // broadcast the message to all the connected clients except the one that just became active.
//            self.writeToAll(channels: self.channels, allocator: channel.allocator, message: "(ChatServer) - New client connected with address: \(remoteAddress)\n")
//
//            self.channels[ObjectIdentifier(channel)] = channel
//        }
//
//        var buffer = channel.allocator.buffer(capacity: 64)
//        buffer.writeString("(ChatServer) - Welcome to: \(context.localAddress!)\n")
//        context.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
//    }
//
//    public func channelInactive(context: ChannelHandlerContext) {
//        let channel = context.channel
//        self.channelsSyncQueue.async {
//            if self.channels.removeValue(forKey: ObjectIdentifier(channel)) != nil {
//                // Broadcast the message to all the connected clients except the one that just was disconnected.
//                self.writeToAll(channels: self.channels, allocator: channel.allocator, message: "(ChatServer) - Client disconnected\n")
//            }
//        }
//    }
//
//    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
//        let id = ObjectIdentifier(context.channel)
//        var read = self.unwrapInboundIn(data)
//
//        // 64 should be good enough for the ipaddress
//        var buffer = context.channel.allocator.buffer(capacity: read.readableBytes + 64)
//        buffer.writeString("(\(context.remoteAddress!)) - ")
//        buffer.writeBuffer(&read)
//        self.channelsSyncQueue.async {
//            // broadcast the message to all the connected clients except the one that wrote it.
//            self.writeToAll(channels: self.channels.filter { id != $0.key }, buffer: buffer)
//        }
//    }
//
//    public func errorCaught(context: ChannelHandlerContext, error: Error) {
//        print("error: ", error)
//
//        // As we are not really interested getting notified on success or failure we just pass nil as promise to
//        // reduce allocations.
//        context.close(promise: nil)
//    }
//
//    private func writeToAll(channels: [ObjectIdentifier: Channel], allocator: ByteBufferAllocator, message: String) {
//        let buffer =  allocator.buffer(string: message)
//        self.writeToAll(channels: channels, buffer: buffer)
//    }
//
//    private func writeToAll(channels: [ObjectIdentifier: Channel], buffer: ByteBuffer) {
//        channels.forEach { $0.value.writeAndFlush(buffer, promise: nil) }
//    }
//}
//
//// We need to share the same ChatHandler for all as it keeps track of all
//// connected clients. For this ChatHandler MUST be thread-safe!
//let chatHandler = ChatHandler()
//
//let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
//let bootstrap = ServerBootstrap(group: group)
//    // Specify backlog and enable SO_REUSEADDR for the server itself
//    .serverChannelOption(ChannelOptions.backlog, value: 256)
//    .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
//
//    // Set the handlers that are applied to the accepted Channels
//    .childChannelInitializer { channel in
//        // Add handler that will buffer data until a \n is received
//        channel.pipeline.addHandler(ByteToMessageHandler(LineDelimiterCodec())).flatMap { v in
//            // It's important we use the same handler for all accepted channels. The ChatHandler is thread-safe!
//            channel.pipeline.addHandler(chatHandler)
//        }
//    }
//
//    // Enable SO_REUSEADDR for the accepted Channels
//    .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
//    .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
//    .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
//defer {
//    try! group.syncShutdownGracefully()
//}
//
//// First argument is the program path
//let arguments = CommandLine.arguments
//let arg1 = arguments.dropFirst().first
//let arg2 = arguments.dropFirst(2).first
//
//let defaultHost = "::1"
//let defaultPort = 9999
//
//enum BindTo {
//    case ip(host: String, port: Int)
//    case unixDomainSocket(path: String)
//}
//
//let bindTarget: BindTo
//switch (arg1, arg1.flatMap(Int.init), arg2.flatMap(Int.init)) {
//case (.some(let h), _ , .some(let p)):
//    /* we got two arguments, let's interpret that as host and port */
//    bindTarget = .ip(host: h, port: p)
//
//case (let portString?, .none, _):
//    // Couldn't parse as number, expecting unix domain socket path.
//    bindTarget = .unixDomainSocket(path: portString)
//
//case (_, let p?, _):
//    // Only one argument --> port.
//    bindTarget = .ip(host: defaultHost, port: p)
//
//default:
//    bindTarget = .ip(host: defaultHost, port: defaultPort)
//}
//
//let channel = try { () -> Channel in
//    switch bindTarget {
//    case .ip(let host, let port):
//        return try bootstrap.bind(host: host, port: port).wait()
//    case .unixDomainSocket(let path):
//        return try bootstrap.bind(unixDomainSocketPath: path).wait()
//    }
//}()
//
//guard let localAddress = channel.localAddress else {
//    fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
//}
//print("Server started and listening on \(localAddress)")
//
//// This will never unblock as we don't close the ServerChannel.
//try channel.closeFuture.wait()
//
//print("ChatServer closed")
