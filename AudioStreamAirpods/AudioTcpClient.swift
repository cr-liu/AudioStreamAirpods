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
    var h16D320Handler = H16D320ClientHandler()
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

class H16D320ClientHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer
    private var numBytes = 0
    private var soundData = [Int16](repeating: 0, count: 160)
    
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
//        buffer.moveReaderIndex(to: 336)
        
//        if let received = buffer.readString(length: readableBytes) {
//            print(readableBytes)
//        }
    }
    
    func readH16D320Ch1(from ptr: UnsafeMutableRawPointer) {
        var unixTime = UnsafeMutablePointer<Int32>(ptr.assumingMemoryBound(to: Int32.self)).pointee
        var movingPtr = ptr + MemoryLayout<Int32>.size
        var ms = UnsafeMutablePointer<Int16>(movingPtr.assumingMemoryBound(to: Int16.self)).pointee
        movingPtr = movingPtr + MemoryLayout<Int16>.size
        var pktID = UnsafeMutablePointer<Int32>(movingPtr.assumingMemoryBound(to: Int32.self)).pointee
        movingPtr = movingPtr + MemoryLayout<Int32>.size
        var humanID = UnsafeMutablePointer<Int32>(movingPtr.assumingMemoryBound(to: Int32.self)).pointee
        movingPtr = movingPtr + MemoryLayout<Int32>.size
        var isAntitarget = UnsafeMutablePointer<Int8>(movingPtr.assumingMemoryBound(to: Int8.self)).pointee
        movingPtr = movingPtr + MemoryLayout<Int8>.size
        var speechActivity = UnsafeMutablePointer<Int8>(ptr.assumingMemoryBound(to: Int8.self)).pointee
        var dataPtr = UnsafeMutablePointer<Int16>((movingPtr + MemoryLayout<Int8>.size).assumingMemoryBound(to: Int16.self))
        for index in 0 ..< 160 {
            soundData[index] = dataPtr.pointee
            dataPtr = dataPtr + 1
        }
//        print(isAntitarget)
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: \(error.localizedDescription)")
        context.close(promise: nil)
    }
}
