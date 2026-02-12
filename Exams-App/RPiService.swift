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

    // MARK: - Student APIs

    // Liste der Tests holen
    // GET /api/student/tests/{klasse}/{fach}
    func fetchTests(klasse: String, fach: String, completion: @escaping ([TestFile]) -> Void) {
        let encodedKlasse = klasse.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? klasse
        let encodedFach = fach.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fach
        let url = URL(string: APIConfig.baseURL + "/api/student/tests/\(encodedKlasse)/\(encodedFach)")!
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
    // GET /api/student/tests/{klasse}/{fach}/{filename}
    func downloadTest(klasse: String, fach: String, filename: String, completion: @escaping (URL?) -> Void) {
        let encodedKlasse = klasse.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? klasse
        let encodedFach = fach.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fach
        let encodedFile = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename
        let url = URL(string: APIConfig.baseURL + "/api/student/tests/\(encodedKlasse)/\(encodedFach)/\(encodedFile)")!

        var request = URLRequest(url: url)
        request.setValue("STUDENT", forHTTPHeaderField: "X-ROLE")

        print("=== Download URL: \(url.absoluteString) ===")

        URLSession.shared.downloadTask(with: request) { tempURL, response, error in
            if let error {
                print("=== Download Error: \(error) ===")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let http = response as? HTTPURLResponse else {
                print("=== Download: No HTTPURLResponse ===")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            print("=== Download Status: \(http.statusCode) ===")
            print("=== Download Headers: \(http.allHeaderFields) ===")
            print("=== Download MIME: \(response?.mimeType ?? "nil") ===")

            guard (200...299).contains(http.statusCode) else {
                // Debug: Zeig den Body an (meist JSON/HTML Fehlermeldung)
                if let tempURL, let data = try? Data(contentsOf: tempURL) {
                    let preview = String(data: data.prefix(800), encoding: .utf8) ?? "<non-utf8>"
                    print("=== Download Error Body Preview (first 800 chars): \(preview) ===")
                }
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let tempURL else {
                print("=== Download: tempURL is nil ===")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Check: ist es wirklich ein PDF?
            if let data = try? Data(contentsOf: tempURL) {
                let header = String(data: data.prefix(4), encoding: .ascii) ?? ""
                print("=== Download First 4 bytes: \(header) ===")

                guard header == "%PDF" else {
                    print("=== Download: Not a PDF! ===")
                    let preview = String(data: data.prefix(800), encoding: .utf8) ?? "<non-utf8>"
                    print("=== Not-PDF Body Preview (first 800 chars): \(preview) ===")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
            }

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let examsRoot = docs.appendingPathComponent("Exams", isDirectory: true)
            let klasseDir = examsRoot.appendingPathComponent(klasse, isDirectory: true)
            let fachDir = klasseDir.appendingPathComponent(fach, isDirectory: true)
            try? FileManager.default.createDirectory(at: fachDir, withIntermediateDirectories: true)

            let dest = fachDir.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: dest)

            do {
                try FileManager.default.copyItem(at: tempURL, to: dest)
                print("=== PDF gespeichert: \(dest.path) ===")

                let fileSize = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int) ?? 0
                print("=== PDF Größe: \(fileSize) bytes ===")

                DispatchQueue.main.async { completion(dest) }
            } catch {
                print("=== Copy Error: \(error) ===")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }

    // Schüler-Abgabe hochladen
    // POST /api/student/tests/{klasse}/{fach}/{filename}/submit
    // Backend fügt automatisch "SUBMISSION_" Präfix hinzu
    func submitTest(klasse: String,
                    fach: String,
                    filename: String,
                    studentFilename: String,
                    pdfData: Data,
                    completion: @escaping (Bool) -> Void) {

        let encodedKlasse = klasse.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? klasse
        let encodedFach = fach.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fach
        let encodedFile = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename

        let url = URL(string: APIConfig.baseURL + "/api/student/tests/\(encodedKlasse)/\(encodedFach)/\(encodedFile)/submit")!

        print("=== SUBMIT URL: \(url.absoluteString) ===")
        print("=== SUBMIT Test-Filename (URL): \(filename) ===")
        print("=== SUBMIT Student-Filename (will be saved with SUBMISSION_ prefix): \(studentFilename) ===")
        print("=== SUBMIT Data Size: \(pdfData.count) bytes ===")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("STUDENT", forHTTPHeaderField: "X-ROLE")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // PDF FIELD - Backend speichert als "SUBMISSION_{filename}"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"pdf\"; filename=\"\(studentFilename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(pdfData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("=== SUBMIT Body Size: \(body.count) bytes ===")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("=== SUBMIT Error: \(error.localizedDescription) ===")
                DispatchQueue.main.async { completion(false) }
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("=== SUBMIT Status: \(status) ===")

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("=== SUBMIT Response: \(responseString) ===")
            }

            DispatchQueue.main.async {
                completion((200...299).contains(status))
            }
        }.resume()
    }

    // MARK: - Teacher APIs

    // PDF hochladen (Lehrer -> RPi)
    // POST /api/teacher/tests
    func uploadTest(klasse: String,
                    fach: String,
                    fileName: String,
                    fileData: Data,
                    completion: @escaping (Bool) -> Void) {

        let url = URL(string: APIConfig.baseURL + "/api/teacher/tests")!

        print("=== UPLOAD URL: \(url.absoluteString) ===")
        print("=== UPLOAD Class: \(klasse), Subject: \(fach) ===")
        print("=== UPLOAD Filename: \(fileName) ===")
        print("=== UPLOAD Data Size: \(fileData.count) bytes ===")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("TEACHER", forHTTPHeaderField: "X-ROLE")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // CLASS FIELD
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"class\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(klasse)\r\n".data(using: .utf8)!)

        // SUBJECT FIELD
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"subject\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(fach)\r\n".data(using: .utf8)!)

        // PDF FIELD
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"pdf\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("=== UPLOAD Body Size: \(body.count) bytes ===")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("=== UPLOAD Error: \(error.localizedDescription) ===")
                DispatchQueue.main.async { completion(false) }
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("=== UPLOAD Status: \(status) ===")

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("=== UPLOAD Response: \(responseString) ===")
            }

            DispatchQueue.main.async {
                completion((200...299).contains(status))
            }
        }.resume()
    }

    // Abgabenliste holen
    // GET /api/teacher/submissions/{klasse}/{fach}/{testName}
    func fetchSubmissions(klasse: String, fach: String, testName: String, completion: @escaping ([Submission]) -> Void) {
        let encodedKlasse = klasse.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? klasse
        let encodedFach = fach.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fach
        let encodedTest = testName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? testName

        let url = URL(string: APIConfig.baseURL + "/api/teacher/submissions/\(encodedKlasse)/\(encodedFach)/\(encodedTest)")!
        var request = URLRequest(url: url)
        request.setValue("TEACHER", forHTTPHeaderField: "X-ROLE")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard
                let data,
                let list = try? JSONDecoder().decode([Submission].self, from: data)
            else {
                completion([])
                return
            }
            completion(list)
        }.resume()
    }

    // Einzelne Abgabe herunterladen
    // GET /api/teacher/submissions/{klasse}/{fach}/{testName}/{filename}
    func downloadSubmission(klasse: String, fach: String, testName: String, filename: String, completion: @escaping (URL?) -> Void) {
        let encodedKlasse = klasse.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? klasse
        let encodedFach = fach.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fach
        let encodedTest = testName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? testName
        let encodedFile = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename

        let url = URL(string: APIConfig.baseURL + "/api/teacher/submissions/\(encodedKlasse)/\(encodedFach)/\(encodedTest)/\(encodedFile)")!
        var request = URLRequest(url: url)
        request.setValue("TEACHER", forHTTPHeaderField: "X-ROLE")

        print("=== Download Submission URL: \(url.absoluteString) ===")

        URLSession.shared.downloadTask(with: request) { tempURL, response, error in
            if let error {
                print("=== Download Submission Error: \(error) ===")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let http = response as? HTTPURLResponse else {
                print("=== Download Submission: No HTTPURLResponse ===")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            print("=== Download Submission Status: \(http.statusCode) ===")
            print("=== Download Submission Headers: \(http.allHeaderFields) ===")
            print("=== Download Submission MIME: \(response?.mimeType ?? "nil") ===")

            guard (200...299).contains(http.statusCode) else {
                if let tempURL, let data = try? Data(contentsOf: tempURL) {
                    let preview = String(data: data.prefix(800), encoding: .utf8) ?? "<non-utf8>"
                    print("=== Download Submission Error Body Preview (first 800 chars): \(preview) ===")
                }
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let tempURL else {
                print("=== Download Submission: tempURL is nil ===")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Check: ist es wirklich ein PDF?
            if let data = try? Data(contentsOf: tempURL) {
                let header = String(data: data.prefix(4), encoding: .ascii) ?? ""
                print("=== Download Submission First 4 bytes: \(header) ===")

                guard header == "%PDF" else {
                    print("=== Download Submission: Not a PDF! ===")
                    let preview = String(data: data.prefix(800), encoding: .utf8) ?? "<non-utf8>"
                    print("=== Not-PDF Body Preview (first 800 chars): \(preview) ===")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
            }

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let examsRoot = docs.appendingPathComponent("Exams", isDirectory: true)
            let klasseDir = examsRoot.appendingPathComponent(klasse, isDirectory: true)
            let fachDir = klasseDir.appendingPathComponent(fach, isDirectory: true)
            let submissionsDir = fachDir.appendingPathComponent("Submissions", isDirectory: true)
            try? FileManager.default.createDirectory(at: submissionsDir, withIntermediateDirectories: true)

            let dest = submissionsDir.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: dest)

            do {
                try FileManager.default.copyItem(at: tempURL, to: dest)
                print("=== Submission gespeichert: \(dest.path) ===")

                let fileSize = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int) ?? 0
                print("=== Submission Größe: \(fileSize) bytes ===")

                DispatchQueue.main.async { completion(dest) }
            } catch {
                print("=== Copy Submission Error: \(error) ===")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }

    // MARK: - Helper APIs

    // Liste aller Klassen holen
    func fetchClasses(completion: @escaping ([String]) -> Void) {
        let url = URL(string: APIConfig.baseURL + "/api/classes")!

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard
                let data,
                let list = try? JSONDecoder().decode([String].self, from: data)
            else {
                completion([])
                return
            }
            completion(list)
        }.resume()
    }

    // Liste aller Fächer einer Klasse holen
    func fetchSubjects(klasse: String, completion: @escaping ([String]) -> Void) {
        let encodedKlasse = klasse.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? klasse
        let url = URL(string: APIConfig.baseURL + "/api/subjects/\(encodedKlasse)")!

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard
                let data,
                let list = try? JSONDecoder().decode([String].self, from: data)
            else {
                completion([])
                return
            }
            completion(list)
        }.resume()
    }
}
