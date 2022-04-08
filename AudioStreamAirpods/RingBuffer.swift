//
//  RingBuffer.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/11/14.
//

import Foundation

class RingBuffer<T> {
    var buf: Array<T>
    var capacity: Int
    var count: Int = 0
    private var readIndex: Int = 0
    private var writeIndex: Int = 0
    private var lock = os_unfair_lock_s()
    
    init(repeating repeatedValue: T, count: Int) {
        buf = Array<T>(repeating: repeatedValue, count: count)
        capacity = count
    }
    
    private func countSize() -> Int {
        if writeIndex >= readIndex {
            return writeIndex - readIndex
        } else {
            return writeIndex + capacity - readIndex
        }
    }
    
    func pushBack(_ newElement: T) {
        buf[writeIndex] = newElement
        advanceWriteIndex()
        count += 1
    }
    
    func pushBack(_ newArray: Array<T>) {
        os_unfair_lock_lock(&lock)
        if newArray.count <= capacity - writeIndex {
            buf.replaceSubrange(writeIndex..<(writeIndex + newArray.count), with: newArray)
            advanceWriteIndex(by: newArray.count)
        } else {
            var copyResidual = newArray.count
            while copyResidual > 0 {
                let bytesToCopy = min(capacity - writeIndex, copyResidual)
                buf.replaceSubrange(writeIndex..<(writeIndex + bytesToCopy),
                                    with: newArray[(newArray.count - copyResidual)..<(newArray.count - copyResidual + bytesToCopy)])
                copyResidual -= bytesToCopy
                advanceWriteIndex(by: bytesToCopy)
            }
        }
        count = countSize()
        os_unfair_lock_unlock(&lock)
    }
    
    @discardableResult
    func popFront() -> T {
        os_unfair_lock_lock(&lock)
        let val = buf[readIndex]
        advanceReadIndex()
        count -= 1
        os_unfair_lock_unlock(&lock)
        return val
    }
    
    @discardableResult
    func popFront(_ n: Int) -> Array<T> {
        os_unfair_lock_lock(&lock)
        let sliceIndex = capacity - readIndex
        let slicedArray: Array<T>
        if n <= sliceIndex {
            slicedArray = Array(buf[readIndex..<(readIndex + n)])
        } else {
            slicedArray = Array(buf[readIndex..<capacity] + buf[0..<(n - sliceIndex)])
        }
        advanceReadIndex(by: n)
        count = countSize()
        os_unfair_lock_unlock(&lock)
        return slicedArray
    }
    
    func removeAll() {
//        buf.removeAll(keepingCapacity: true)
        os_unfair_lock_lock(&lock)
        readIndex = 0
        writeIndex = 0
        os_unfair_lock_unlock(&lock)
    }
    
    func resize(_ newSize: Int) {
        buf.removeAll(keepingCapacity: false)
        os_unfair_lock_lock(&lock)
        buf.reserveCapacity(newSize)
        capacity = newSize
        os_unfair_lock_unlock(&lock)
    }
    
    private func advanceWriteIndex(by steps: Int = 1) {
        writeIndex += steps
        while writeIndex >= capacity {
            writeIndex -= capacity
        }
    }
    
    private func advanceReadIndex(by steps: Int = 1) {
        readIndex += steps
        if readIndex >= capacity {
            readIndex -= capacity
        }
    }
}
