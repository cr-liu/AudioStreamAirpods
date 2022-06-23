//
//  H80D320Ch1.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/11/10.
//

import Foundation
import Accelerate

class H80D10ms16k {
    var sktHeader: H80D10ms16kHeader?
    var imuDataPtr: UnsafeRawPointer? // pointer to [Float32 * 16] imu data
    var audioChannels: Int = 2
    var monoData = Array<Int16>(repeating: 0, count: 160)
    var stereoData = Array<Int16>(repeating: 0, count: 320) // 160 x 2ch

    let headerSize = 80
    
    struct H80D10ms16kHeader {
        var unixTime: Int32 = 0
        var ms: Int16 = 0
        var pktID: Int32 = 0
        var humanID: Int32 = 0
        var isAntitarget: Int8 = -1
        var speechActivity: Int8 = 0
    }
    
    @inlinable
    func writeSocketBuf(to bufPtr: UnsafeMutableRawPointer, withSound soundData: Array<Int16>?) {
        var movingPtr = bufPtr
        UnsafeMutablePointer<Int32>(movingPtr.assumingMemoryBound(to: Int32.self)).pointee = sktHeader!.unixTime
        movingPtr += MemoryLayout<Int32>.size
        UnsafeMutablePointer<Int16>(movingPtr.assumingMemoryBound(to: Int16.self)).pointee = sktHeader!.ms
        movingPtr += MemoryLayout<Int16>.size
        UnsafeMutablePointer<Int32>(movingPtr.assumingMemoryBound(to: Int32.self)).pointee = sktHeader!.pktID
        movingPtr += MemoryLayout<Int32>.size
        UnsafeMutablePointer<Int32>(movingPtr.assumingMemoryBound(to: Int32.self)).pointee = sktHeader!.humanID
        movingPtr += MemoryLayout<Int32>.size
        UnsafeMutablePointer<Int8>(movingPtr.assumingMemoryBound(to: Int8.self)).pointee = sktHeader!.speechActivity
        movingPtr += MemoryLayout<Int8>.size
        UnsafeMutablePointer<Int8>(movingPtr.assumingMemoryBound(to: Int8.self)).pointee = sktHeader!.isAntitarget
        movingPtr += MemoryLayout<Int8>.size
        
        memcpy(movingPtr, imuDataPtr, MemoryLayout<Float32>.size * 16)
        movingPtr += MemoryLayout<Float32>.size * 16
        
        if soundData != nil {
            let sndDataPtr = soundData!.withUnsafeBytes{ $0 }
            memcpy(movingPtr, sndDataPtr.baseAddress, soundData!.count * MemoryLayout<Int16>.size)
        } else {
            let sndDataPtr = stereoData.withUnsafeBytes{ $0 }
            memcpy(movingPtr, sndDataPtr.baseAddress, stereoData.count * MemoryLayout<Int16>.size)
        }
    }
}
