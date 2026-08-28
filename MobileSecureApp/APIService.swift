import Foundation

struct Post: Codable {
    let userId: Int
    let id: Int?
    let title: String
    let body: String
}

struct RegistroUsuario: Codable {
    let id: Int?
    let usuario: String
    let fecha: String
    let dispositivo: String
}

enum APIError: LocalizedError {
    case urlInvalida
    case respuestaInvalida
    case codigoHTTP(Int)
    case datosInvalidos

    var errorDescription: String? {
        switch self {
        case .urlInvalida: return "La dirección de la API no es válida."
        case .respuestaInvalida: return "El servidor devolvió una respuesta inválida."
        case .codigoHTTP(let codigo): return "El servidor respondió con HTTP \(codigo)."
        case .datosInvalidos: return "No fue posible interpretar la respuesta."
        }
    }
}

final class APIService {
    static let shared = APIService()
    private init() {}

    func obtenerPost(completion: @escaping (Result<Post, Error>) -> Void) {
        guard let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1") else {
            completion(.failure(APIError.urlInvalida))
            return
        }
        ejecutar(URLRequest(url: url), como: Post.self, completion: completion)
    }

    func registrarUsuario(
        usuario: String,
        fecha: String,
        dispositivo: String,
        completion: @escaping (Result<RegistroUsuario, Error>) -> Void
    ) {
        guard let url = URL(string: "https://jsonplaceholder.typicode.com/posts") else {
            completion(.failure(APIError.urlInvalida))
            return
        }

        do {
            let registro = RegistroUsuario(
                id: nil,
                usuario: usuario,
                fecha: fecha,
                dispositivo: dispositivo
            )
            var solicitud = URLRequest(url: url)
            solicitud.httpMethod = "POST"
            solicitud.timeoutInterval = 15
            solicitud.httpBody = try JSONEncoder().encode(registro)
            solicitud.setValue("application/json", forHTTPHeaderField: "Content-Type")
            solicitud.setValue("application/json", forHTTPHeaderField: "Accept")
            ejecutar(solicitud, como: RegistroUsuario.self, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }

    private func ejecutar<T: Decodable>(
        _ solicitud: URLRequest,
        como tipo: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        var solicitud = solicitud
        solicitud.timeoutInterval = 15
        URLSession.shared.dataTask(with: solicitud) { datos, respuesta, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let http = respuesta as? HTTPURLResponse else {
                completion(.failure(APIError.respuestaInvalida))
                return
            }
            guard (200...299).contains(http.statusCode) else {
                completion(.failure(APIError.codigoHTTP(http.statusCode)))
                return
            }
            guard let datos else {
                completion(.failure(APIError.datosInvalidos))
                return
            }
            do {
                completion(.success(try JSONDecoder().decode(T.self, from: datos)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
