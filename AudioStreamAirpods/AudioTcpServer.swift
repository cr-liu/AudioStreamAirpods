//
//  AudioTcpServer.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/19.
//

import Foundation
import NIO

class AudioTcpServer {
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    private var host: String?
    private var port: Int?
    
    init(host: String, port: Int) {
      // 3
      self.host = host
      self.port = port
    }
    
    func run() throws {
      // 2
      guard let host = host else {
        return
      }
      guard let port = port else {
        return
      }
      do {
        // 3
        let channel = try serverBootstrap.bind(host: host, port: port).wait()
        print("\(channel.localAddress!) is now open")
        try channel.closeFuture.wait()
      } catch let error {
        throw error
      }
    }
    
    func shutdown() {
      do {
        // 1
        try group.syncShutdownGracefully()
      } catch let error {
        print("Could not shutdown gracefully - forcing exit (\(error.localizedDescription))")
        // 2
        exit(0)
      }
      print("Server closed")
    }
    
    private var serverBootstrap: ServerBootstrap {
      // 1
      return ServerBootstrap(group: group)
        .serverChannelOption(ChannelOptions.backlog, value: 256)
        // 2
        .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
//        .childChannelInitializer { channel in
//          // 3
//          channel.pipeline.add(handler: BackPressureHandler()).then { v in
//            // 4
//            channel.pipeline.add(handler: QuoteHandler())
//          }
//        }
        // 5
        .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
        .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
        .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
    }
}

final class QuoteHandler: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer
    
    // 1
    func channelRegistered(ctx: ChannelHandlerContext) {
      print("Incoming connection registered - sending Quote of the Day")
      // 2
      let quote = "quote"
      // 3
      var buffer = ctx.channel.allocator.buffer(capacity: quote.utf8.count)
      // 4
//      buffer.write(string: quote)
      print("Sending quote")
      // 5
      ctx.writeAndFlush(self.wrapOutboundOut(buffer))
    }

    // 7
    public func errorCaught(ctx: ChannelHandlerContext, error: Error) {
      print("error: ", error)
      ctx.close(promise: nil)
    }
}
