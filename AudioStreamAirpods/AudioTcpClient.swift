//
//  AudioTcpClient.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/29.
//

import Foundation
import NIO

class AudioTcpClient {
    var messages: [String] = []
    var isConnected: Bool = false
    var h16D320Handler = H16D320Ch1ClientHandler()
    var host: String = "192.168.1.10"
    var port: Int = 12345
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var channel: Channel?
    private lazy var bootstrap = ClientBootstrap(group: group)
        .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        .channelInitializer { channel in
            channel.pipeline.addHandler(self.h16D320Handler)
        }
    
    deinit {
        do {
            try group.syncShutdownGracefully()
        } catch let error {
            print("Could not shutdown gracefully - forcing exit (\(error.localizedDescription))!")
            exit(0)
        }
    }
    
    func start() {
        do {
            channel = try bootstrap.connect(host: self.host, port: self.port).wait()
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
    private var numBytes = 0
    
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
