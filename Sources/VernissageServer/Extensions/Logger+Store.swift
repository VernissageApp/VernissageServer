//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

extension Logger {
    public func store(_ message: @autoclosure () -> Logger.Message,
                      _ error: Error?,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #fileID,
                      function: String = #function,
                      line: UInt = #line,
                      on application: Application
    ) async {
        let errorMessage = message()
        let errorMessageWithException = if let error {
            "\(errorMessage) Error (debug): \(error). Error (localized): \(error.localizedDescription)."
        } else {
            "\(errorMessage)"
        }
        
        // Log to console (configured at the start of the application).
        self.log(level: .error, "\(errorMessageWithException)", metadata: metadata(), source: source(), file: file, function: function, line: line)
        
        // Log to database.
        let errorItemsService = application.services.errorItemsService
        await errorItemsService.add("\(errorMessage)", error, on: application)
    }
}
