//
//  ViewController.swift
//  MobileSecureApp
//
//  Created by Daniel on 18/08/26.
//

import UIKit
import CoreLocation
import LocalAuthentication

class ViewController: UIViewController {

    @IBOutlet weak var metadataTableView: UITableView!
    @IBOutlet weak var usuarioTextField: UITextField!
    private var datos: [(titulo: String, detalle: String)] = []
    private let locationManager = CLLocationManager()
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        metadataTableView.dataSource = self
        metadataTableView.delegate = self

        cargarDatosIniciales()
    }
    private func cargarDatosIniciales() {
        datos = [
            ("Estado", "Esperando autenticación"),
            ("Fecha", obtenerFechaActual()),
            ("Dispositivo", obtenerInformacionDispositivo()),
            ("Usuario", "No ingresado"),
            ("Ubicación", "No disponible")
        ]

        metadataTableView.reloadData()
    }
    private func obtenerFechaActual() -> String {
        let formato = DateFormatter()

        formato.dateStyle = .medium
        formato.timeStyle = .medium
        formato.locale = Locale(identifier: "es_MX")

        return formato.string(from: Date())
    }
    private func obtenerInformacionDispositivo() -> String {
        let dispositivo = UIDevice.current

        return "\(dispositivo.model) - \(dispositivo.systemName) \(dispositivo.systemVersion)"
    }
    
    private func actualizarDato(titulo: String, detalle: String) {
        if let indice = datos.firstIndex(where: { $0.titulo == titulo }) {
            datos[indice] = (titulo, detalle)
        } else {
            datos.append((titulo, detalle))
        }

        metadataTableView.reloadData()
    }
    
    private func mostrarAlerta(titulo: String, mensaje: String) {
        let alerta = UIAlertController(
            title: titulo,
            message: mensaje,
            preferredStyle: .alert
        )

        let accionAceptar = UIAlertAction(
            title: "Aceptar",
            style: .default
        )

        alerta.addAction(accionAceptar)
        present(alerta, animated: true)
    }

    private func solicitarUbicacion() {
        guard CLLocationManager.locationServicesEnabled() else {
            actualizarDato(
                titulo: "Ubicación",
                detalle: "Los servicios de ubicación están desactivados"
            )
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            actualizarDato(
                titulo: "Ubicación",
                detalle: "Obteniendo ubicación..."
            )

            locationManager.requestLocation()

        case .denied:
            actualizarDato(
                titulo: "Ubicación",
                detalle: "Permiso de ubicación rechazado"
            )

            mostrarAlerta(
                titulo: "Ubicación desactivada",
                mensaje: "Debes permitir el acceso a la ubicación desde Configuración."
            )

        case .restricted:
            actualizarDato(
                titulo: "Ubicación",
                detalle: "Acceso a ubicación restringido"
            )

        @unknown default:
            actualizarDato(
                titulo: "Ubicación",
                detalle: "Estado de autorización desconocido"
            )
        }
    }
    private func autenticarConBiometria(usuario: String) {
        let contexto = LAContext()
        var errorAutenticacion: NSError?

        let politica = LAPolicy.deviceOwnerAuthenticationWithBiometrics

        if contexto.canEvaluatePolicy(
            politica,
            error: &errorAutenticacion
        ) {
            contexto.evaluatePolicy(
                politica,
                localizedReason: "Autentícate para acceder a los metadatos."
            ) { [weak self] exito, error in

                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }

                    if exito {
                        self.autenticacionExitosa(usuario: usuario)
                    } else {
                        self.actualizarDato(
                            titulo: "Estado",
                            detalle: "Autenticación rechazada"
                        )

                        self.mostrarAlerta(
                            titulo: "Acceso rechazado",
                            mensaje: error?.localizedDescription
                                ?? "No fue posible verificar tu identidad."
                        )
                    }
                }
            }
        } else {
            actualizarDato(
                titulo: "Estado",
                detalle: "Autenticación no disponible"
            )

            mostrarAlerta(
                titulo: "Seguridad no disponible",
                mensaje: errorAutenticacion?.localizedDescription
                    ?? "El dispositivo no tiene Face ID, Touch ID o código configurado."
            )
        }
    }
    private func autenticacionExitosa(usuario: String) {
        actualizarDato(
            titulo: "Estado",
            detalle: "Usuario autenticado correctamente"
        )

        actualizarDato(
            titulo: "Usuario",
            detalle: usuario
        )

        actualizarDato(
            titulo: "Fecha",
            detalle: obtenerFechaActual()
        )

        solicitarUbicacion()

        mostrarAlerta(
            titulo: "Autenticación exitosa",
            mensaje: "Bienvenido, \(usuario)."
        )
    }
    @IBAction func autenticar(_ sender: UIButton) {
        let usuario = usuarioTextField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !usuario.isEmpty else {
            mostrarAlerta(
                titulo: "Usuario requerido",
                mensaje: "Escribe tu nombre antes de continuar."
            )
            return
        }

        view.endEditing(true)

        actualizarDato(
            titulo: "Estado",
            detalle: "Esperando autenticación..."
        )

        autenticarConBiometria(usuario: usuario)
    }
    
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        return datos.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {

        let celda = tableView.dequeueReusableCell(
            withIdentifier: "MetadataCell",
            for: indexPath
        )

        let dato = datos[indexPath.row]

        celda.textLabel?.text = dato.titulo
        celda.detailTextLabel?.text = dato.detalle
        celda.detailTextLabel?.numberOfLines = 0
        celda.selectionStyle = .none

        return celda
    }
}

extension ViewController: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            actualizarDato(
                titulo: "Ubicación",
                detalle: "Obteniendo ubicación..."
            )

            manager.requestLocation()

        case .denied:
            actualizarDato(
                titulo: "Ubicación",
                detalle: "Permiso de ubicación rechazado"
            )

        case .restricted:
            actualizarDato(
                titulo: "Ubicación",
                detalle: "Acceso a ubicación restringido"
            )

        case .notDetermined:
            break

        @unknown default:
            break
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let ubicacion = locations.last else {
            actualizarDato(
                titulo: "Ubicación",
                detalle: "No se recibió ninguna ubicación"
            )
            return
        }

        let latitud = String(
            format: "%.6f",
            ubicacion.coordinate.latitude
        )

        let longitud = String(
            format: "%.6f",
            ubicacion.coordinate.longitude
        )

        actualizarDato(
            titulo: "Ubicación",
            detalle: "Latitud: \(latitud) | Longitud: \(longitud)"
        )
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        actualizarDato(
            titulo: "Ubicación",
            detalle: "Error: \(error.localizedDescription)"
        )

        print("Error de ubicación: \(error.localizedDescription)")
    }
}

