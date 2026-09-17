//
//  CostAPIClient.swift
//  costa
//

import Foundation

struct CostAPIClient: Sendable {
    var baseURL: URL
    var accessToken: String

    init(baseURL: URL = APIBaseURL.url, accessToken: String) {
        self.baseURL = baseURL
        self.accessToken = accessToken
    }

    // MARK: - Expenses

    func listExpenses(month: String? = nil, draft: Bool? = nil) async throws -> [Expense] {
        var components = URLComponents(url: baseURL.appending(path: "api/expenses"), resolvingAgainstBaseURL: true)!
        var items: [URLQueryItem] = []
        if let month { items.append(URLQueryItem(name: "month", value: month)) }
        if let draft { items.append(URLQueryItem(name: "draft", value: draft ? "true" : "false")) }
        if !items.isEmpty { components.queryItems = items }
        guard let url = components.url else { throw CostAPIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await execute(request, as: ExpenseListResponse.self).expenses
    }

    func createExpense(request: CreateExpenseRequest) async throws -> CreateExpenseResponse {
        let url = baseURL.appending(path: "api/expenses")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        return try await execute(urlRequest, as: CreateExpenseResponse.self)
    }

    func patchExpense(id: String, patch: ExpensePatch) async throws -> Expense {
        let url = baseURL.appending(path: "api/expenses/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(patch)
        return try await execute(request, as: ExpenseOneResponse.self).expense
    }

    // MARK: - Categories

    func listCategories() async throws -> [CostCategory] {
        let url = baseURL.appending(path: "api/cost/categories")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await execute(request, as: CategoriesResponse.self).categories
    }

    func createCategory(_ body: CreateCategoryRequest) async throws -> CostCategory {
        let url = baseURL.appending(path: "api/cost/categories")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await execute(request, as: CategoryOneResponse.self).category
    }

    // MARK: - Costs

    func dailySummary(days: Int = 7, currency: String? = nil) async throws -> DailySummaryResponse {
        var components = URLComponents(
            url: baseURL.appending(path: "api/cost/summary/daily"),
            resolvingAgainstBaseURL: true
        )!
        var items = [URLQueryItem(name: "days", value: String(days))]
        if let currency, !currency.isEmpty {
            items.append(URLQueryItem(name: "currency", value: currency))
        }
        components.queryItems = items
        guard let url = components.url else { throw CostAPIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await execute(request, as: DailySummaryResponse.self)
    }

    func patchCost(id: String, patch: CostPatch) async throws -> Cost {
        let url = baseURL.appending(path: "api/cost/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(patch)
        return try await execute(request, as: CostOneResponse.self).cost
    }

    /// Deletes a single cost/line-item.
    ///
    /// NOTE: this assumes the DELETE endpoint lives at the same path as
    /// `patchCost` (`api/cost/{id}`), just with the DELETE HTTP method —
    /// matching typical REST conventions. If your backend uses a
    /// different path (e.g. `api/costs/{id}` or a nested route under the
    /// parent expense), update the path below to match.
    ///
    /// Doesn't decode a response body since DELETE endpoints commonly
    /// return 204 No Content (or an empty body) rather than JSON — only
    /// the HTTP status code is checked.
    func deleteCost(id: String) async throws {
        let url = baseURL.appending(path: "api/cost/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        try await executeNoContent(request)
    }

    // MARK: - AI extraction

    func fromBill(imageJPEG: Data, fileName: String = "receipt.jpg") async throws -> FromBillResponse {
        let url = baseURL.appending(path: "api/cost/from-bill")
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(imageJPEG: imageJPEG, fileName: fileName, boundary: boundary)
        return try await execute(request, as: FromBillResponse.self)
    }

    // MARK: - Shared

    private func multipartBody(imageJPEG: Data, fileName: String, boundary: String) -> Data {
        var body = Data()

        func appendStr(_ s: String) {
            if let d = s.data(using: .utf8) { body.append(d) }
        }

        appendStr("--\(boundary)\r\n")
        appendStr("Content-Disposition: form-data; name=\"image\"; filename=\"\(fileName)\"\r\n")
        appendStr("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageJPEG)
        appendStr("\r\n--\(boundary)--\r\n")

        return body
    }

    private func execute<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CostAPIError.transport(error)
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200 ..< 300).contains(code) else {
            if let env = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw CostAPIError.httpStatus(code, env.error)
            }
            throw CostAPIError.httpStatus(code, String(data: data, encoding: .utf8))
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CostAPIError.decoding(error)
        }
    }

    /// Same status-code handling as `execute(_:as:)`, but for endpoints
    /// that don't return a decodable JSON body (e.g. DELETE returning 204).
    private func executeNoContent(_ request: URLRequest) async throws {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CostAPIError.transport(error)
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200 ..< 300).contains(code) else {
            if let env = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw CostAPIError.httpStatus(code, env.error)
            }
            throw CostAPIError.httpStatus(code, String(data: data, encoding: .utf8))
        }
    }
}

enum CostAPIError: LocalizedError {
    case invalidURL
    case httpStatus(Int, String?)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:               "Invalid API URL"
        case let .httpStatus(code, msg): msg ?? "Request failed (\(code))"
        case let .decoding(err):         err.localizedDescription
        case let .transport(err):        err.localizedDescription
        }
    }
}
