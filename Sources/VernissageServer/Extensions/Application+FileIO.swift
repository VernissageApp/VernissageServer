//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import NIOFileSystem

extension NonBlockingFileIO {
    
    public func writeFile(_ buffer: ByteBuffer, at path: String) async throws {
        // This returns the number of bytes written which we don't need
        _ = try await FileSystem.shared.withFileHandle(forWritingAt: .init(path), options: .newFile(replaceExisting: true)) { handle in
            try await handle.write(contentsOf: buffer, toAbsoluteOffset: 0)
        }
    }
        
    public func collectFile(at path: String, allocator: ByteBufferAllocator) async throws -> ByteBuffer {
        guard let fileSize = try await FileSystem.shared.info(forFileAt: .init(path))?.size else {
            throw Abort(.internalServerError)
        }
        
        return try await self.read(path: path, fromOffset: 0, byteCount: Int(fileSize))
    }
    
    private func read(path: String, fromOffset offset: Int64, byteCount: Int) async throws -> ByteBuffer {
        return try await FileSystem.shared.withFileHandle(forReadingAt: .init(path)) { handle in
            return try await handle.readChunk(fromAbsoluteOffset: offset, length: .bytes(Int64(byteCount)))
        }
    }
}
