import Foundation
import UIKit

final class MetadataViewModel {

    private(set) var datos: [MetadataItem] = []

    var alActualizarDatos: (() -> Void)?

    func cargarDatosIniciales() {
        datos = [
            MetadataItem(
                titulo: "Estado",
                detalle: "Esperando autenticación"
            ),
            MetadataItem(
                titulo: "Fecha",
                detalle: obtenerFechaActual()
            ),
            MetadataItem(
                titulo: "Dispositivo",
                detalle: obtenerInformacionDispositivo()
            ),
            MetadataItem(
                titulo: "Usuario",
                detalle: "No ingresado"
            ),
            MetadataItem(
                titulo: "Ubicación",
                detalle: "No disponible"
            )
        ]

        notificarCambios()
    }

    func actualizarDato(titulo: String, detalle: String) {
        if let indice = datos.firstIndex(
            where: { $0.titulo == titulo }
        ) {
            datos[indice] = MetadataItem(
                titulo: titulo,
                detalle: detalle
            )
        } else {
            datos.append(
                MetadataItem(
                    titulo: titulo,
                    detalle: detalle
                )
            )
        }

        notificarCambios()
    }

    func obtenerFechaActual() -> String {
        let formato = DateFormatter()

        formato.dateStyle = .medium
        formato.timeStyle = .medium
        formato.locale = Locale(identifier: "es_MX")

        return formato.string(from: Date())
    }

    func obtenerInformacionDispositivo() -> String {
        let dispositivo = UIDevice.current

        return """
        \(dispositivo.model) - \
        \(dispositivo.systemName) \
        \(dispositivo.systemVersion)
        """
    }

    private func notificarCambios() {
        DispatchQueue.main.async { [weak self] in
            self?.alActualizarDatos?()
        }
    }
}
