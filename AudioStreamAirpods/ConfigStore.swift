//
//  ConfigStore.swift
//  AudioStreamAirpods
//
//  Created by liu on 2022/10/05.
//

import Foundation

struct NetConfig: Codable {
    var usingUdp: Bool
    var listenPort: Int
    var remotePort: Int
    var remoteHost: String
 
    init(usingUDP: Bool, remotePort: Int, listenPort: Int, remoteHost: String) {
        self.usingUdp = usingUDP
        self.listenPort = listenPort
        self.remotePort = remotePort
        self.remoteHost = remoteHost
    }
}

class ConfigStore {
    private static func fileURL() throws -> URL {
        try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("conf.data")
    }
    
    static func load(netConf: NetConfig, completion: @escaping (Result<NetConfig, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let fileURL = try fileURL()
                guard let file = try? FileHandle(forReadingFrom: fileURL) else {
                    DispatchQueue.main.async {
                        completion(.success(netConf))
                    }
                    return
                }
                let conf = try JSONDecoder().decode(NetConfig.self, from: file.availableData)
                DispatchQueue.main.async {
                    completion(.success(conf))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    static func save(netConf: NetConfig, completion: @escaping (Result<(), Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let confData = try JSONEncoder().encode(netConf)
                let saveFile = try fileURL()
                try confData.write(to: saveFile)
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
