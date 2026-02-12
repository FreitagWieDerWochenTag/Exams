//
//  RPiService.swift
//  Exams-App
//
//  Created by Aldin Mukic on 10.02.26.
//

import Foundation

class RPiService {
    static let shared = RPiService()
    private init() {}

    // Verbindung testen
    func ping(completion: @escaping (Bool) -> Void) {
        let url = URL(string: APIConfig.baseURL + "/ping")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            completion(data != nil)
        }.resume()
    }

    // Liste der Tests holen
    func fetchTests(group: String, completion: @escaping ([TestFile]) -> Void) {
        let encoded = group.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? group
        let url = URL(string: APIConfig.baseURL + "/api/student/tests/\(encoded)")!
        var request = URLRequest(url: url)
        request.setValue("STUDENT", forHTTPHeaderField: "X-ROLE")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard
                let data,
                let list = try? JSONDecoder().decode([TestFile].self, from: data)
            else {
                completion([])
                return
            }
            completion(list)
        }.resume()
    }

    // PDF laden
    func downloadTest(group: String, filename: String, completion: @escaping (URL?) -> Void) {
        let encodedGroup = group.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? group
        let encodedFile = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename
        let url = URL(string: APIConfig.baseURL + "/api/student/tests/\(encodedGroup)/\(encodedFile)")!
        var request = URLRequest(url: url)
        request.setValue("STUDENT", forHTTPHeaderField: "X-ROLE")

        print("=== Download URL: \(url.absoluteString) ===")

        URLSession.shared.downloadTask(with: request) { tempURL, response, error in
            if let error {
                print("=== Download Error: \(error) ===")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("=== Download Status: \(status) ===")

            guard let tempURL else {
                print("=== Download: tempURL is nil ===")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dest = docs.appendingPathComponent(filename)

            try? FileManager.default.removeItem(at: dest)

            do {
                try FileManager.default.copyItem(at: tempURL, to: dest)
                print("=== PDF gespeichert: \(dest.path) ===")

                // Pruefen ob die Datei gueltig ist
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int) ?? 0
                print("=== PDF Groesse: \(fileSize) bytes ===")

                DispatchQueue.main.async { completion(dest) }
            } catch {
                print("=== Copy Error: \(error) ===")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }

    // PDF hochladen (Lehrer -> RPi)
    func uploadTest(group: String,
                    fileName: String,
                    fileData: Data,
                    completion: @escaping (Bool) -> Void) {

        let url = URL(string: APIConfig.baseURL + "/api/teacher/tests")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("TEACHER", forHTTPHeaderField: "X-ROLE")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // GROUP FIELD
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"group\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(group)\r\n".data(using: .utf8)!)

        // PDF FIELD
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"pdf\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { _, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async {
                completion((200...299).contains(status))
            }
        }.resume()
    }

    // Schueler-Abgabe hochladen
    func submitTest(group: String,
                    filename: String,
                    pdfData: Data,
                    completion: @escaping (Bool) -> Void) {

        let url = URL(string: APIConfig.baseURL + "/api/student/submit")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("STUDENT", forHTTPHeaderField: "X-ROLE")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // GROUP FIELD
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"group\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(group)\r\n".data(using: .utf8)!)

        // PDF FIELD
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"pdf\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(pdfData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { _, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async {
                completion((200...299).contains(status))
            }
        }.resume()
    }
}
