//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
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
protocol OpenAIServiceType: Sendable {
    /// Generates a concise image description (alt text) using the specified model and OpenAI API.
    ///
    /// - Parameters:
    ///   - imageUrl: The URL of the image to analyze.
    ///   - model: The OpenAI model to use for generation.
    ///   - apiKey: The OpenAI API key for authentication.
    /// - Returns: The generated image description string.
    /// - Throws: An error if the request to OpenAI fails or if parsing the response is unsuccessful.
    func generateImageDescription(imageUrl: String, model: String, apiKey: String) async throws -> String

    /// Generates relevant hashtags for an image using the specified model and OpenAI API.
    ///
    /// - Parameters:
    ///   - imageUrl: The URL of the image to analyze.
    ///   - model: The OpenAI model to use for generation.
    ///   - apiKey: The OpenAI API key for authentication.
    /// - Returns: An array of generated hashtags as strings.
    /// - Throws: An error if the request to OpenAI fails or if parsing the response is unsuccessful.
    func generateHashtags(imageUrl: String, model: String, apiKey: String) async throws -> [String]
}

/// A service for interacting with OpenAI API.
final class OpenAIService: OpenAIServiceType {

    /// Generate description from image.
    /// https://platform.openai.com/docs/guides/vision
    func generateImageDescription(imageUrl: String, model: String, apiKey: String) async throws -> String {
        guard let apiUrl = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw OpenAIError.incorrectOpenAIUrl
        }
        
        let jsonString =
"""
{
    "model": "\(model)",
    "messages": [
    {
      "role": "user",
      "content": [
        {
            "type": "text",
            "text": "Generate concise and clear alt text for an image by accurately describing its visual elements and composition. Avoid expressing subjective feelings or interpretations. Ensure the alt text provides enough context for users who rely on these descriptions to understand the image. Include significant details that visually impaired users would find informative. Do not start sentences with introductions like 'This image shows ...' or 'This is a picture of ...'."
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
            let a = String(data: data, encoding: .ascii) ?? "<data != string>"
            print(a)
            
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
    
    /// Generate hashtags from image.
    /// https://platform.openai.com/docs/guides/vision
    func generateHashtags(imageUrl: String, model: String, apiKey: String) async throws -> [String] {
        guard let apiUrl = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw OpenAIError.incorrectOpenAIUrl
        }
        
        let jsonString =
"""
{
    "model": "\(model)",
    "messages": [
    {
      "role": "user",
      "content": [
        {
            "type": "text",
            "text": "Generate hashtags based on the image content provided. Only output the hashtags, nothing else. Use relevant, popular, and engaging hashtags suitable for sharing on social media platforms. Don't mention the name of any existing social network."
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

        return content.getHashtags()
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

