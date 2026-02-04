//
//  CircularAudioBuffer.swift
//  VeepaAudioTest
//
//  Created for AudioUnit Hook implementation
//  Purpose: Thread-safe ring buffer for transferring audio samples
//           from SDK render callback to our AVAudioEngine playback
//

import Foundation

/// Thread-safe circular buffer for Int16 audio samples
///
/// Used to transfer audio data between:
/// - Producer: SDK's AudioUnit render callback (high-priority audio thread)
/// - Consumer: Our AVAudioSourceNode render block (high-priority audio thread)
///
/// Design considerations:
/// - Lock-free would be ideal but NSLock is acceptable for audio at 16kHz
/// - Overflow: drops oldest samples (producer wins)
/// - Underflow: returns silence (consumer gets zeros)
///
final class CircularAudioBuffer {

    // MARK: - Properties

    private var buffer: [Int16]
    private var readIndex: Int = 0
    private var writeIndex: Int = 0
    private var count: Int = 0
    private let capacity: Int
    private let lock = NSLock()

    /// Statistics for debugging
    private(set) var totalSamplesWritten: UInt64 = 0
    private(set) var totalSamplesRead: UInt64 = 0
    private(set) var overflowCount: UInt64 = 0
    private(set) var underflowCount: UInt64 = 0

    // MARK: - Initialization

    /// Create a circular buffer with specified capacity
    /// - Parameter capacity: Maximum number of Int16 samples to hold
    ///   Recommended: At least 1 second of audio (e.g., 16000 for 16kHz)
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = [Int16](repeating: 0, count: capacity)
    }

    // MARK: - Public Interface

    /// Number of samples currently available for reading
    var availableSamples: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    /// Buffer fill level as percentage (0.0 to 1.0)
    var fillLevel: Float {
        lock.lock()
        defer { lock.unlock() }
        return Float(count) / Float(capacity)
    }

    /// Check if buffer is empty
    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return count == 0
    }

    /// Check if buffer is full
    var isFull: Bool {
        lock.lock()
        defer { lock.unlock() }
        return count == capacity
    }

    // MARK: - Write (Producer)

    /// Write samples into the buffer
    ///
    /// Called from SDK's AudioUnit render callback thread.
    /// If buffer is full, oldest samples are overwritten (overflow).
    ///
    /// - Parameters:
    ///   - samples: Pointer to Int16 sample data
    ///   - count: Number of samples to write
    /// - Returns: Number of samples actually written (always equals count)
    @discardableResult
    func write(from samples: UnsafePointer<Int16>, count sampleCount: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }

        for i in 0..<sampleCount {
            buffer[writeIndex] = samples[i]
            writeIndex = (writeIndex + 1) % capacity

            if count < capacity {
                count += 1
            } else {
                // Overflow - advance read pointer (drop oldest)
                readIndex = (readIndex + 1) % capacity
                overflowCount += 1
            }
        }

        totalSamplesWritten += UInt64(sampleCount)
        return sampleCount
    }

    /// Write samples from an array
    /// - Parameter samples: Array of Int16 samples
    /// - Returns: Number of samples written
    @discardableResult
    func write(from samples: [Int16]) -> Int {
        return samples.withUnsafeBufferPointer { ptr in
            guard let baseAddress = ptr.baseAddress else { return 0 }
            return write(from: baseAddress, count: samples.count)
        }
    }

    /// Write samples from AudioBufferList (common in Core Audio callbacks)
    /// - Parameters:
    ///   - bufferList: The AudioBufferList containing samples
    ///   - frameCount: Number of frames to write
    /// - Returns: Number of samples written
    @discardableResult
    func write(from bufferList: UnsafePointer<AudioBufferList>, frameCount: UInt32) -> Int {
        let ablPointer = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: bufferList))

        guard let firstBuffer = ablPointer.first,
              let dataPointer = firstBuffer.mData?.assumingMemoryBound(to: Int16.self) else {
            return 0
        }

        return write(from: dataPointer, count: Int(frameCount))
    }

    // MARK: - Read (Consumer)

    /// Read samples from the buffer
    ///
    /// Called from our AVAudioSourceNode render block.
    /// If not enough samples available, remaining space is filled with silence (zeros).
    ///
    /// - Parameters:
    ///   - destination: Pointer to write samples to
    ///   - count: Number of samples requested
    /// - Returns: Number of actual samples read (rest is silence)
    func read(into destination: UnsafeMutablePointer<Int16>, count requestedCount: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }

        let samplesToRead = min(requestedCount, count)

        // Read available samples
        for i in 0..<samplesToRead {
            destination[i] = buffer[readIndex]
            readIndex = (readIndex + 1) % capacity
        }

        count -= samplesToRead
        totalSamplesRead += UInt64(samplesToRead)

        // Fill remaining with silence (underflow)
        if samplesToRead < requestedCount {
            let silenceCount = requestedCount - samplesToRead
            for i in samplesToRead..<requestedCount {
                destination[i] = 0
            }
            underflowCount += UInt64(silenceCount)
        }

        return samplesToRead
    }

    /// Read samples into an array
    /// - Parameter count: Number of samples to read
    /// - Returns: Array of samples (may contain silence if underflow)
    func read(count requestedCount: Int) -> [Int16] {
        var result = [Int16](repeating: 0, count: requestedCount)
        result.withUnsafeMutableBufferPointer { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            _ = read(into: baseAddress, count: requestedCount)
        }
        return result
    }

    // MARK: - Control

    /// Clear all samples from buffer
    func clear() {
        lock.lock()
        defer { lock.unlock() }

        readIndex = 0
        writeIndex = 0
        count = 0
    }

    /// Reset statistics
    func resetStatistics() {
        lock.lock()
        defer { lock.unlock() }

        totalSamplesWritten = 0
        totalSamplesRead = 0
        overflowCount = 0
        underflowCount = 0
    }

    // MARK: - Debug

    /// Get buffer statistics as string
    var statisticsDescription: String {
        lock.lock()
        defer { lock.unlock() }

        return """
        CircularAudioBuffer Statistics:
          Capacity: \(capacity) samples
          Current: \(count) samples (\(String(format: "%.1f", Float(count) / Float(capacity) * 100))% full)
          Written: \(totalSamplesWritten) samples
          Read: \(totalSamplesRead) samples
          Overflows: \(overflowCount)
          Underflows: \(underflowCount)
        """
    }
}

// MARK: - Testing Support

#if DEBUG
extension CircularAudioBuffer {
    /// Create a buffer pre-filled with test data
    static func testBuffer(capacity: Int, prefillCount: Int, value: Int16 = 0x7FFF) -> CircularAudioBuffer {
        let buffer = CircularAudioBuffer(capacity: capacity)
        let testData = [Int16](repeating: value, count: prefillCount)
        buffer.write(from: testData)
        return buffer
    }

    /// Verify buffer integrity (for testing)
    func verifyIntegrity() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // Check that count is within bounds
        guard count >= 0 && count <= capacity else { return false }

        // Check that indices are within bounds
        guard readIndex >= 0 && readIndex < capacity else { return false }
        guard writeIndex >= 0 && writeIndex < capacity else { return false }

        return true
    }
}
#endif
