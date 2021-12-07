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
    var isEmpty: Bool = true
    var count: Int = 0
    private var readIndex: Int = 0
    private var writeIndex: Int = 0
    private var lock = os_unfair_lock_s()
    
    init(repeating repeatedValue: T, count: Int) {
        buf = Array<T>(repeating: repeatedValue, count: count)
        capacity = count
    }
    
    func countSize() -> Int {
        if isEmpty {
            return 0
        }
        if writeIndex > readIndex {
            return writeIndex - readIndex
        } else {
            return writeIndex + capacity - readIndex
        }
    }
    
    func pushBack(_ newElement: T) {
        buf[writeIndex] = newElement
        isEmpty = false
        advanceWriteIndex()
        count += 1
    }
    
    func pushBack(_ newArray: Array<T>) {
        os_unfair_lock_lock(&lock)
        isEmpty = false
        if newArray.count <= capacity - writeIndex {
            buf.replaceSubrange(writeIndex..<(writeIndex + newArray.count), with: newArray)
            advanceWriteIndex(by: newArray.count)
        } else {
            var copyResidual = newArray.count
            while copyResidual > capacity - writeIndex {
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
    
    func popFront() -> T {
        os_unfair_lock_lock(&lock)
        let val = buf[readIndex]
        advanceReadIndex()
        if readIndex == writeIndex {
            isEmpty = true
        }
        count -= 1
        os_unfair_lock_unlock(&lock)
        return val
    }
    
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
        readIndex = 0
        writeIndex = 0
    }
    
    func resize(_ newSize: Int) {
        buf.removeAll(keepingCapacity: false)
        buf.reserveCapacity(newSize)
        capacity = newSize
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
