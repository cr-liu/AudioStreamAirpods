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
}
