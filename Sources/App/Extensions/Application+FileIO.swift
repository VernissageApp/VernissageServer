//
//  File.swift
//  
//
//  Created by Marcin Czachurski on 28/07/2023.
//

import Vapor
import NIOCore

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
}
