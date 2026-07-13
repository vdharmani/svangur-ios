import Foundation

/// Builds a `multipart/form-data` request body for endpoints that mix text fields and file
/// uploads (image upload, restaurant profile edit with photos).
struct MultipartFormData: Sendable {
    let boundary: String
    private var data = Data()

    init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
    }

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    mutating func appendField(name: String, value: String) {
        appendBoundary()
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func appendFile(name: String, filename: String, mimeType: String, fileData: Data) {
        appendBoundary()
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        append("\r\n")
    }

    func build() -> Data {
        var finalData = data
        append(&finalData, "--\(boundary)--\r\n")
        return finalData
    }

    private mutating func appendBoundary() {
        append("--\(boundary)\r\n")
    }

    private mutating func append(_ string: String) {
        append(&data, string)
    }

    private func append(_ target: inout Data, _ string: String) {
        if let encoded = string.data(using: .utf8) {
            target.append(encoded)
        }
    }
}
