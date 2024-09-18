//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
@preconcurrency import NIOCore

extension NonBlockingFileIO {
    
    public func writeFile(_ buffer: ByteBuffer, at path: String, eventLoop: EventLoop) async throws {
        return try await self.writeFile(buffer, at: path, eventLoop: eventLoop).get()
    }
    
    public func writeFile(_ buffer: ByteBuffer, at path: String, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        do {
            let fd = try NIOFileHandle(path: path, mode: .write, flags: .allowFileCreation())
            let done = self.write(fileHandle: fd, buffer: buffer, eventLoop: eventLoop)
            done.whenComplete { _ in
                try? fd.close()
            }
            return done
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }

    public func collectFile(at path: String, allocator: ByteBufferAllocator, eventLoop: EventLoop) async throws -> ByteBuffer {
        return try await self.collectFile(at: path, allocator: allocator, eventLoop: eventLoop).get()
    }
    
    public func collectFile(at path: String, allocator: ByteBufferAllocator, eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: path),
            let fileSize = attributes[.size] as? NSNumber
        else {
            return eventLoop.makeFailedFuture(Abort(.internalServerError))
        }
        
        do {
            let fileHandle = try NIOFileHandle(path: path)
            return self.read(fileHandle: fileHandle,
                             fromOffset: 0,
                             byteCount: fileSize.intValue,
                             allocator: allocator,
                             eventLoop: eventLoop)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
}
