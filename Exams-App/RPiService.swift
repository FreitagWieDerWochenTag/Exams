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
    func fetchTests(completion: @escaping ([TestFile]) -> Void) {
        let url = URL(string: APIConfig.baseURL + "/api/student/tests")!
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
    func downloadTest(filename: String, completion: @escaping (URL?) -> Void) {
        let url = URL(string: APIConfig.baseURL + "/api/student/tests/\(filename)")!
        var request = URLRequest(url: url)
        request.setValue("STUDENT", forHTTPHeaderField: "X-ROLE")

        URLSession.shared.downloadTask(with: request) { tempURL, _, _ in
            guard let tempURL else {
                completion(nil)
                return
            }

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dest = docs.appendingPathComponent(filename)

            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: tempURL, to: dest)

            completion(dest)
        }.resume()
    }

}
