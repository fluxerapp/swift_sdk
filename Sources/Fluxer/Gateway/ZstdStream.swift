import Foundation
import libzstd

public class ZstdException: Error, CustomStringConvertible, @unchecked Sendable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { "ZstdException: \(message)" }
}

public final class ZstdStreamException: ZstdException, @unchecked Sendable {}

private let zstdContentSizeUnknown: UInt64 = UInt64.max
private let zstdContentSizeError: UInt64 = UInt64.max - 1
private let zstdEFlush: ZSTD_EndDirective = ZSTD_e_flush
private let zstdEEnd: ZSTD_EndDirective = ZSTD_e_end
private let zstdCCompressionLevel = ZSTD_c_compressionLevel

private func growOutputBuffer(
    buffer: [UInt8],
    usedLength: Int,
    requiredLength: Int,
    maximumLength: Int
) -> [UInt8] {
    var nextLength = buffer.isEmpty ? 1 : buffer.count
    while nextLength < requiredLength {
        nextLength = nextLength > maximumLength / 2 ? maximumLength : nextLength * 2
    }
    var grown = [UInt8](repeating: 0, count: nextLength)
    if usedLength > 0 {
        grown.replaceSubrange(0..<usedLength, with: buffer.prefix(usedLength))
    }
    return grown
}

public final class ZstdStreamEncoder {
    public static let defaultMaxCompressedMessageSize = 64 * 1024 * 1024
    private static let nativeOutputSize = 64 * 1024

    private let level: Int
    public let maxCompressedMessageSize: Int
    private var context: OpaquePointer?
    private var disposed = false
    private var poisoned = false
    private var ended = false

    public init(level: Int = 3, maxCompressedMessageSize: Int = ZstdStreamEncoder.defaultMaxCompressedMessageSize) {
        guard maxCompressedMessageSize > 0 else {
            fatalError("maxCompressedMessageSize must be greater than zero")
        }
        self.level = level
        self.maxCompressedMessageSize = maxCompressedMessageSize
        self.context = Self.createContext(level: level)
    }

    deinit {
        dispose()
    }

    public func compress(_ chunk: Data) throws -> Data {
        ensureUsable()
        return try compressChunk(chunk, endDirective: zstdEFlush)
    }

    public func end() throws -> Data {
        ensureUsable()
        let result = try compressChunk(Data(), endDirective: zstdEEnd)
        ended = true
        return result
    }

    public func reset() throws {
        if disposed { throw ZstdStreamException("Encoder has been disposed") }
        if let context {
            ZSTD_freeCCtx(context)
        }
        context = Self.createContext(level: level)
        poisoned = false
        ended = false
    }

    public func dispose() {
        if disposed { return }
        disposed = true
        if let context {
            ZSTD_freeCCtx(context)
            self.context = nil
        }
    }

    private func compressChunk(_ chunk: Data, endDirective: ZSTD_EndDirective) throws -> Data {
        guard let context else { throw ZstdStreamException("Encoder has no context") }

        return try chunk.withUnsafeBytes { chunkBytes in
            try withUnsafeTemporaryAllocation(of: UInt8.self, capacity: Self.nativeOutputSize) { nativeOutput in
                var input = ZSTD_inBuffer(
                    src: chunkBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    size: chunk.count,
                    pos: 0
                )
                var output = ZSTD_outBuffer(dst: nativeOutput.baseAddress, size: Self.nativeOutputSize, pos: 0)

                var compressed = [UInt8](repeating: 0, count: Self.nativeOutputSize)
                var compressedLength = 0
                var remaining: size_t = 1

                while input.pos < input.size || remaining != 0 {
                    let inputPosition = input.pos
                    output.pos = 0
                    remaining = ZSTD_compressStream2(context, &output, &input, endDirective)
                    if ZSTD_isError(remaining) != 0 {
                        poisoned = true
                        throw ZstdStreamException(String(cString: ZSTD_getErrorName(remaining)))
                    }

                    let produced = Int(output.pos)
                    if compressedLength + produced > maxCompressedMessageSize {
                        poisoned = true
                        throw ZstdStreamException(
                            "Compressed message exceeds the \(maxCompressedMessageSize) byte limit"
                        )
                    }

                    let requiredLength = compressedLength + produced
                    if requiredLength > compressed.count {
                        var nextLength = compressed.count * 2
                        while nextLength < requiredLength { nextLength *= 2 }
                        if nextLength > maxCompressedMessageSize { nextLength = maxCompressedMessageSize }
                        compressed = growOutputBuffer(
                            buffer: compressed,
                            usedLength: compressedLength,
                            requiredLength: requiredLength,
                            maximumLength: maxCompressedMessageSize
                        )
                    }
                    if produced > 0 {
                        compressed.replaceSubrange(
                            compressedLength..<requiredLength,
                            with: nativeOutput.prefix(produced)
                        )
                        compressedLength = requiredLength
                    }

                    if input.pos == inputPosition && produced == 0
                        && (input.pos < input.size || remaining != 0)
                    {
                        poisoned = true
                        throw ZstdStreamException("Encoder made no progress")
                    }
                }

                return Data(compressed.prefix(compressedLength))
            }
        }
    }

    private func ensureUsable() {
        if disposed { fatalError("ZstdStreamEncoder has been disposed") }
        if poisoned {
            fatalError("ZstdStreamEncoder is poisoned after failed compression; call reset()")
        }
        if ended {
            fatalError("ZstdStreamEncoder has ended; call reset()")
        }
    }

    private static func createContext(level: Int) -> OpaquePointer {
        guard let context = ZSTD_createCCtx() else {
            fatalError("Failed to create compression context")
        }
        let result = ZSTD_CCtx_setParameter(context, zstdCCompressionLevel, Int32(level))
        if ZSTD_isError(result) != 0 {
            let message = String(cString: ZSTD_getErrorName(result))
            ZSTD_freeCCtx(context)
            fatalError(message)
        }
        return context
    }
}

public final class ZstdStreamDecoder {
    public static let defaultMaxDecompressedMessageSize = 64 * 1024 * 1024
    private static let nativeOutputSize = 64 * 1024

    public let maxDecompressedMessageSize: Int
    private var context: OpaquePointer?
    private var disposed = false
    private var poisoned = false
    private var ended = false
    private var lastResultHint: size_t = 0

    public var isFrameComplete: Bool { lastResultHint == 0 }

    public init(maxDecompressedMessageSize: Int = ZstdStreamDecoder.defaultMaxDecompressedMessageSize) {
        guard maxDecompressedMessageSize > 0 else {
            fatalError("maxDecompressedMessageSize must be greater than zero")
        }
        self.maxDecompressedMessageSize = maxDecompressedMessageSize
        self.context = Self.createContext()
    }

    deinit {
        dispose()
    }

    public func feed(_ chunk: Data) throws -> Data {
        ensureUsable()
        if chunk.isEmpty { return Data() }
        guard let context else { throw ZstdStreamException("Decoder has no context") }

        return try chunk.withUnsafeBytes { chunkBytes in
            try withUnsafeTemporaryAllocation(of: UInt8.self, capacity: Self.nativeOutputSize) { nativeOutput in
                var input = ZSTD_inBuffer(
                    src: chunkBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    size: chunk.count,
                    pos: 0
                )
                var output = ZSTD_outBuffer(dst: nativeOutput.baseAddress, size: Self.nativeOutputSize, pos: 0)

                var decoded = [UInt8](repeating: 0, count: Self.nativeOutputSize)
                var decodedLength = 0

                while input.pos < input.size || output.pos == Self.nativeOutputSize {
                    let inputPosition = input.pos
                    output.pos = 0

                    let result = ZSTD_decompressStream(context, &output, &input)
                    if ZSTD_isError(result) != 0 {
                        poisoned = true
                        throw ZstdStreamException(String(cString: ZSTD_getErrorName(result)))
                    }
                    lastResultHint = result

                    let produced = Int(output.pos)
                    if decodedLength + produced > maxDecompressedMessageSize {
                        poisoned = true
                        throw ZstdStreamException(
                            "Decompressed message exceeds the \(maxDecompressedMessageSize) byte limit"
                        )
                    }

                    let requiredLength = decodedLength + produced
                    if requiredLength > decoded.count {
                        decoded = growOutputBuffer(
                            buffer: decoded,
                            usedLength: decodedLength,
                            requiredLength: requiredLength,
                            maximumLength: maxDecompressedMessageSize
                        )
                    }
                    if produced > 0 {
                        decoded.replaceSubrange(
                            decodedLength..<requiredLength,
                            with: nativeOutput.prefix(produced)
                        )
                        decodedLength = requiredLength
                    }

                    if result == 0 && input.pos == input.size {
                        break
                    }

                    if input.pos == inputPosition && produced == 0 && input.pos < input.size {
                        poisoned = true
                        throw ZstdStreamException("Decoder made no progress")
                    }
                }

                return Data(decoded.prefix(decodedLength))
            }
        }
    }

    public func finish() throws {
        ensureUsable()
        if !isFrameComplete {
            poisoned = true
            throw ZstdStreamException("Truncated zstd stream")
        }
        ended = true
    }

    public func reset() throws {
        if disposed { throw ZstdStreamException("Decoder has been disposed") }
        if let context {
            ZSTD_freeDCtx(context)
        }
        context = Self.createContext()
        poisoned = false
        ended = false
        lastResultHint = 0
    }

    public func dispose() {
        if disposed { return }
        disposed = true
        if let context {
            ZSTD_freeDCtx(context)
            self.context = nil
        }
    }

    private func ensureUsable() {
        if disposed { fatalError("ZstdStreamDecoder has been disposed") }
        if poisoned {
            fatalError("ZstdStreamDecoder is poisoned after a failed feed; call reset()")
        }
        if ended {
            fatalError("ZstdStreamDecoder has finished; call reset()")
        }
    }

    private static func createContext() -> OpaquePointer {
        guard let context = ZSTD_createDCtx() else {
            fatalError("Failed to create decompression context")
        }
        return context
    }
}
