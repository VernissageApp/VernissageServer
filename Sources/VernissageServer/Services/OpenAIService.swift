//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension Application.Services {
    struct OpenAIServiceKey: StorageKey {
        typealias Value = OpenAIServiceType
    }

    var openAIService: OpenAIServiceType {
        get {
            self.application.storage[OpenAIServiceKey.self] ?? OpenAIService()
        }
        nonmutating set {
            self.application.storage[OpenAIServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol OpenAIServiceType {
    func generateImageDescription(imageUrl: String, apiKey: String) async throws -> String
}

/// A service for managing roles in the system.
final class OpenAIService: OpenAIServiceType {

    /// Generate description from image.
    /// https://platform.openai.com/docs/guides/vision
    func generateImageDescription(imageUrl: String, apiKey: String) async throws -> String {
        guard let apiUrl = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw OpenAIError.incorrectOpenAIUrl
        }
        
        let jsonString =
"""
{
    "model": "gpt-4-turbo",
    "messages": [
    {
      "role": "user",
      "content": [
        {
            "type": "text",
            "text": "What’s in this image?"
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "\(imageUrl)"
          }
        }
      ]
    }
    ],
    "max_tokens": 300
}
"""

        var request = URLRequest(url: apiUrl)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpMethod = "POST"
        request.httpBody = jsonString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.asyncData(for: request)
        guard (response as? HTTPURLResponse)?.status?.responseType == .success else {
            throw NetworkError.notSuccessResponse(response, data)
        }

        guard let responseString = String(data: data, encoding: .utf8) else {
            throw OpenAIError.cannotChangeResponseToString
        }

        let responseDict = self.convertStringToDictionary(text: responseString)
        guard let choices = responseDict?["choices"] as? [[String : Any]] else {
            throw OpenAIError.incorrectJsonFormat
        }

        guard let message = choices.first?["message"] as? [String : Any] else {
            throw OpenAIError.incorrectJsonFormat
        }

        guard let content = message["content"] as? String else {
            throw OpenAIError.incorrectJsonFormat
        }

        return content
    }
    
    private func convertStringToDictionary(text: String) -> [String:AnyObject]? {
       if let data = text.data(using: .utf8) {
           do {
               let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String:AnyObject]
               return json
           } catch {
               print("Something went wrong")
           }
       }
       return nil
   }
}
