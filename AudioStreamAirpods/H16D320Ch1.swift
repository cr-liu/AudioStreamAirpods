//
//  H16D320Ch1.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/06/01.
//

import Foundation

class H16D320Ch1 {
    var soundData = ContiguousArray<Int16>(repeating: 0, count: 160)
    var skipHeader: Bool = true
    var sktHeader: H16D320Ch1Header?
    
    struct H16D320Ch1Header {
        var unixTime: Int32
        var ms: Int16
        var pktID: Int32
        var humanID: Int32
        var isAntitarget: Int8
        var speechActivity: Int8
    }
    
    @inlinable
    func readH16D320Ch1(from ptr: UnsafeMutableRawPointer) {
        var movingPtr = ptr
        if skipHeader {
            movingPtr += 16
        } else {
            if sktHeader == nil {
                sktHeader = H16D320Ch1Header(unixTime: 0, ms: 0, pktID: 0, humanID: 0, isAntitarget: -1, speechActivity: 0)
            }
            sktHeader!.unixTime = UnsafeMutablePointer<Int32>(movingPtr.assumingMemoryBound(to: Int32.self)).pointee
            movingPtr += MemoryLayout<Int32>.size
            sktHeader!.ms = UnsafeMutablePointer<Int16>(movingPtr.assumingMemoryBound(to: Int16.self)).pointee
            movingPtr += MemoryLayout<Int16>.size
            sktHeader!.pktID = UnsafeMutablePointer<Int32>(movingPtr.assumingMemoryBound(to: Int32.self)).pointee
            movingPtr += MemoryLayout<Int32>.size
            sktHeader!.humanID = UnsafeMutablePointer<Int32>(movingPtr.assumingMemoryBound(to: Int32.self)).pointee
            movingPtr += MemoryLayout<Int32>.size
            sktHeader!.isAntitarget = UnsafeMutablePointer<Int8>(movingPtr.assumingMemoryBound(to: Int8.self)).pointee
            movingPtr += MemoryLayout<Int8>.size
            sktHeader!.speechActivity = UnsafeMutablePointer<Int8>(ptr.assumingMemoryBound(to: Int8.self)).pointee
        }
        var dataPtr = UnsafeMutablePointer<Int16>((movingPtr + MemoryLayout<Int8>.size).assumingMemoryBound(to: Int16.self))
        for index in 0 ..< 160 {
            soundData[index] = dataPtr.pointee
            dataPtr = dataPtr + 1
        }
    }
    
    @inlinable
    func writeH16D320Ch1(to ptr: UnsafeMutableRawPointer, dataArray: ContiguousArray<Int16>) {
        var movingPtr = ptr
        UnsafeMutablePointer<Int32>(movingPtr.assumingMemoryBound(to: Int32.self)).pointee = sktHeader!.unixTime
        movingPtr += MemoryLayout<Int32>.size
        UnsafeMutablePointer<Int16>(movingPtr.assumingMemoryBound(to: Int16.self)).pointee = sktHeader!.ms
        movingPtr += MemoryLayout<Int16>.size
        UnsafeMutablePointer<Int32>(movingPtr.assumingMemoryBound(to: Int32.self)).pointee = sktHeader!.pktID
        movingPtr += MemoryLayout<Int32>.size
        UnsafeMutablePointer<Int32>(ptr.assumingMemoryBound(to: Int32.self)).pointee = sktHeader!.humanID
        movingPtr += MemoryLayout<Int32>.size
        UnsafeMutablePointer<Int8>(ptr.assumingMemoryBound(to: Int8.self)).pointee = sktHeader!.isAntitarget
        movingPtr += MemoryLayout<Int8>.size
        UnsafeMutablePointer<Int8>(ptr.assumingMemoryBound(to: Int8.self)).pointee = sktHeader!.speechActivity
        var dataPtr = UnsafeMutablePointer<Int16>((ptr + MemoryLayout<Int8>.size).assumingMemoryBound(to: Int16.self))
        for frame in dataArray {
            dataPtr.pointee = frame
            dataPtr = dataPtr + 1
        }
    }
}


