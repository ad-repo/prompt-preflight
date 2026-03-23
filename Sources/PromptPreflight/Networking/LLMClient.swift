import Foundation

protocol LLMClient: Sendable {
    func send(inputMarkdown: String, systemPrompt: String, model: String) async throws -> String
}

enum LLMError: Error, LocalizedError {
    case missingAPIKey(LLMProvider)
    case invalidURL(String)
    case httpStatus(code: Int, message: String)
    case invalidResponse(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Missing API key for \(provider.displayName)."
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .httpStatus(let code, let message):
            return "Provider returned HTTP \(code): \(message)"
        case .invalidResponse(let message):
            return "Invalid provider response: \(message)"
        case .cancelled:
            return "Request cancelled."
        }
    }
}

struct HTTPRetryPolicy {
    let maxRetries: Int

    static let `default` = HTTPRetryPolicy(maxRetries: 1)

    static func isTransientStatus(_ statusCode: Int) -> Bool {
        statusCode == 408 || statusCode == 409 || statusCode == 429 || (500 ... 599).contains(statusCode)
    }

    static func isAuthStatus(_ statusCode: Int) -> Bool {
        statusCode == 401 || statusCode == 403
    }

    static func isTransientError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
}

protocol HTTPTransporting: Sendable {
    func perform(_ request: URLRequest, retryPolicy: HTTPRetryPolicy) async throws -> (Data, HTTPURLResponse)
}

final class HTTPTransport: HTTPTransporting, @unchecked Sendable {
    private let session: URLSession

    init(timeout: TimeInterval = AppConstants.requestTimeoutSeconds) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: config)
    }

    func perform(_ request: URLRequest, retryPolicy: HTTPRetryPolicy = .default) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0

        while true {
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw LLMError.invalidResponse("Missing HTTP response")
                }

                if (200 ... 299).contains(httpResponse.statusCode) {
                    return (data, httpResponse)
                }

                let bodyMessage = String(data: data, encoding: .utf8) ?? "<empty>"
                if attempt < retryPolicy.maxRetries,
                   HTTPRetryPolicy.isTransientStatus(httpResponse.statusCode),
                   !HTTPRetryPolicy.isAuthStatus(httpResponse.statusCode) {
                    attempt += 1
                    continue
                }

                throw LLMError.httpStatus(code: httpResponse.statusCode, message: bodyMessage)
            } catch is CancellationError {
                throw LLMError.cancelled
            } catch {
                if attempt < retryPolicy.maxRetries, HTTPRetryPolicy.isTransientError(error) {
                    attempt += 1
                    continue
                }
                throw error
            }
        }
    }
}

final class OpenAIClient: LLMClient, @unchecked Sendable {
    private let apiKey: String
    private let transport: HTTPTransporting

    init(apiKey: String, transport: HTTPTransporting) {
        self.apiKey = apiKey
        self.transport = transport
    }

    func send(inputMarkdown: String, systemPrompt: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw LLMError.invalidURL("https://api.openai.com/v1/chat/completions")
        }

        struct Payload: Encodable {
            struct Message: Encodable {
                let role: String
                let content: String
            }

            let model: String
            let messages: [Message]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            Payload(
                model: model,
                messages: [
                    Payload.Message(role: "system", content: systemPrompt),
                    Payload.Message(role: "user", content: inputMarkdown)
                ]
            )
        )

        let (data, _) = try await transport.perform(request, retryPolicy: .default)

        struct Response: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }

                let message: Message
            }

            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let first = decoded.choices.first?.message.content else {
            throw LLMError.invalidResponse("OpenAI response missing choices")
        }
        return first
    }
}

final class GeminiClient: LLMClient, @unchecked Sendable {
    private let apiKey: String
    private let transport: HTTPTransporting

    init(apiKey: String, transport: HTTPTransporting) {
        self.apiKey = apiKey
        self.transport = transport
    }

    func send(inputMarkdown: String, systemPrompt: String, model: String) async throws -> String {
        let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw LLMError.invalidURL(urlString)
        }

        struct Payload: Encodable {
            struct Part: Encodable {
                let text: String
            }

            struct Content: Encodable {
                let role: String
                let parts: [Part]
            }

            struct SystemInstruction: Encodable {
                let parts: [Part]
            }

            let systemInstruction: SystemInstruction
            let contents: [Content]
        }

        let payload = Payload(
            systemInstruction: Payload.SystemInstruction(parts: [Payload.Part(text: systemPrompt)]),
            contents: [Payload.Content(role: "user", parts: [Payload.Part(text: inputMarkdown)])]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, _) = try await transport.perform(request, retryPolicy: .default)

        struct Response: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable {
                        let text: String?
                    }

                    let parts: [Part]?
                }

                let content: Content?
            }

            let candidates: [Candidate]?
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.first?.text else {
            throw LLMError.invalidResponse("Gemini response missing text")
        }

        return text
    }
}

final class AnthropicClient: LLMClient, @unchecked Sendable {
    private let apiKey: String
    private let transport: HTTPTransporting

    init(apiKey: String, transport: HTTPTransporting) {
        self.apiKey = apiKey
        self.transport = transport
    }

    func send(inputMarkdown: String, systemPrompt: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw LLMError.invalidURL("https://api.anthropic.com/v1/messages")
        }

        struct Payload: Encodable {
            struct Message: Encodable {
                struct Content: Encodable {
                    let type: String
                    let text: String
                }

                let role: String
                let content: [Content]
            }

            let model: String
            let max_tokens: Int
            let system: String
            let messages: [Message]
        }

        let payload = Payload(
            model: model,
            max_tokens: 2_048,
            system: systemPrompt,
            messages: [
                Payload.Message(
                    role: "user",
                    content: [Payload.Message.Content(type: "text", text: inputMarkdown)]
                )
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, _) = try await transport.perform(request, retryPolicy: .default)

        struct Response: Decodable {
            struct Content: Decodable {
                let type: String
                let text: String?
            }

            let content: [Content]
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw LLMError.invalidResponse("Anthropic response missing text")
        }
        return text
    }
}

final class OllamaClient: LLMClient, @unchecked Sendable {
    private let baseURL: URL
    private let token: String?
    private let transport: HTTPTransporting

    init(baseURL: URL, token: String?, transport: HTTPTransporting) {
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
    }

    func send(inputMarkdown: String, systemPrompt: String, model: String) async throws -> String {
        let url = baseURL.appending(path: "/api/chat")

        struct Payload: Encodable {
            struct Message: Encodable {
                let role: String
                let content: String
            }

            let model: String
            let stream: Bool
            let messages: [Message]
        }

        let payload = Payload(
            model: model,
            stream: false,
            messages: [
                Payload.Message(role: "system", content: systemPrompt),
                Payload.Message(role: "user", content: inputMarkdown)
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, _) = try await transport.perform(request, retryPolicy: .default)

        struct Response: Decodable {
            struct Message: Decodable {
                let content: String
            }

            let message: Message?
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let content = decoded.message?.content else {
            throw LLMError.invalidResponse("Ollama response missing message content")
        }
        return content
    }
}
