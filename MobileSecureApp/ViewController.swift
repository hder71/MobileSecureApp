import UIKit
import CoreLocation
import LocalAuthentication
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

final class ViewController: UIViewController {
    @IBOutlet private weak var metadataTableView: UITableView!
    @IBOutlet private weak var usuarioTextField: UITextField!
    @IBOutlet private weak var correoTextField: UITextField!
    @IBOutlet private weak var contrasenaTextField: UITextField!

    private let viewModel = MetadataViewModel()
    private let locationManager = CLLocationManager()
    private lazy var firestore = Firestore.firestore()

    override func viewDidLoad() {
        super.viewDidLoad()
        metadataTableView.dataSource = self
        metadataTableView.delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        viewModel.alActualizarDatos = { [weak self] in
            self?.metadataTableView.reloadData()
        }
        viewModel.cargarDatosIniciales()
    }

    private func obtenerFechaActual() -> String { viewModel.obtenerFechaActual() }
    private func obtenerInformacionDispositivo() -> String { viewModel.obtenerInformacionDispositivo() }

    private func actualizarDato(titulo: String, detalle: String) {
        viewModel.actualizarDato(titulo: titulo, detalle: detalle)
    }

    private func mostrarAlerta(titulo: String, mensaje: String) {
        let alerta = UIAlertController(title: titulo, message: mensaje, preferredStyle: .alert)
        alerta.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alerta, animated: true)
    }

    private func obtenerCredenciales() -> (usuario: String, correo: String, contrasena: String)? {
        let usuario = usuarioTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let correo = correoTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let contrasena = contrasenaTextField.text ?? ""
        guard !usuario.isEmpty else {
            mostrarAlerta(titulo: "Usuario requerido", mensaje: "Escribe tu nombre.")
            return nil
        }
        guard correo.contains("@"), correo.contains(".") else {
            mostrarAlerta(titulo: "Correo inválido", mensaje: "Escribe un correo electrónico válido.")
            return nil
        }
        guard contrasena.count >= 6 else {
            mostrarAlerta(titulo: "Contraseña inválida", mensaje: "Debe contener al menos 6 caracteres.")
            return nil
        }
        return (usuario, correo, contrasena)
    }

    @IBAction private func crearCuenta(_ sender: UIButton) {
        guard let credenciales = obtenerCredenciales() else { return }
        view.endEditing(true)
        sender.isEnabled = false
        actualizarDato(titulo: "Firebase Auth", detalle: "Creando cuenta...")
        Auth.auth().createUser(withEmail: credenciales.correo, password: credenciales.contrasena) {
            [weak self, weak sender] resultado, error in
            DispatchQueue.main.async {
                sender?.isEnabled = true
                guard let self else { return }
                if let error {
                    self.actualizarDato(titulo: "Firebase Auth", detalle: "Error al crear la cuenta")
                    self.mostrarAlerta(titulo: "No fue posible crear la cuenta", mensaje: error.localizedDescription)
                    return
                }
                guard let usuarioFirebase = resultado?.user else { return }
                self.actualizarDato(titulo: "Firebase Auth", detalle: "Cuenta creada correctamente")
                self.actualizarDato(titulo: "UID Firebase", detalle: usuarioFirebase.uid)
                self.actualizarDato(titulo: "Correo", detalle: usuarioFirebase.email ?? credenciales.correo)
                self.mostrarAlerta(titulo: "Cuenta creada", mensaje: "Ahora puedes iniciar sesión.")
            }
        }
    }

    @IBAction private func autenticar(_ sender: UIButton) {
        guard let credenciales = obtenerCredenciales() else { return }
        view.endEditing(true)
        sender.isEnabled = false
        actualizarDato(titulo: "Firebase Auth", detalle: "Iniciando sesión...")
        Auth.auth().signIn(withEmail: credenciales.correo, password: credenciales.contrasena) {
            [weak self, weak sender] resultado, error in
            DispatchQueue.main.async {
                sender?.isEnabled = true
                guard let self else { return }
                if error != nil {
                    self.actualizarDato(titulo: "Firebase Auth", detalle: "Correo o contraseña incorrectos")
                    self.mostrarAlerta(titulo: "Acceso rechazado", mensaje: "Verifica la cuenta y la contraseña.")
                    return
                }
                guard let usuarioFirebase = resultado?.user else { return }
                self.actualizarDato(titulo: "Firebase Auth", detalle: "Sesión iniciada correctamente")
                self.actualizarDato(titulo: "UID Firebase", detalle: usuarioFirebase.uid)
                self.actualizarDato(titulo: "Correo", detalle: usuarioFirebase.email ?? credenciales.correo)
                self.actualizarDato(titulo: "Estado", detalle: "Esperando autenticación biométrica...")
                self.autenticarConBiometria(usuario: credenciales.usuario)
            }
        }
    }

    private func autenticarConBiometria(usuario: String) {
        let contexto = LAContext()
        var errorAutenticacion: NSError?
        let politica = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        guard contexto.canEvaluatePolicy(politica, error: &errorAutenticacion) else {
            actualizarDato(titulo: "Estado", detalle: "Autenticación no disponible")
            mostrarAlerta(titulo: "Seguridad no disponible", mensaje: errorAutenticacion?.localizedDescription ?? "Biometría no configurada.")
            return
        }
        contexto.evaluatePolicy(politica, localizedReason: "Autentícate para acceder a los metadatos.") {
            [weak self] exito, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if exito {
                    self.autenticacionExitosa(usuario: usuario)
                } else {
                    self.actualizarDato(titulo: "Estado", detalle: "Autenticación rechazada")
                    self.mostrarAlerta(titulo: "Acceso rechazado", mensaje: error?.localizedDescription ?? "No fue posible verificar tu identidad.")
                }
            }
        }
    }

    private func autenticacionExitosa(usuario: String) {
        actualizarDato(titulo: "Estado", detalle: "Usuario autenticado correctamente")
        actualizarDato(titulo: "Usuario", detalle: usuario)
        actualizarDato(titulo: "Fecha", detalle: obtenerFechaActual())
        solicitarUbicacion()
        consumirAPIGet()
        consumirAPIPost(usuario: usuario)
        guardarRegistroFirestore(usuario: usuario)
        mostrarAlerta(titulo: "Autenticación exitosa", mensaje: "Bienvenido, \(usuario).")
    }

    private func consumirAPIGet() {
        actualizarDato(titulo: "API GET", detalle: "Consultando servidor...")
        APIService.shared.obtenerPost { [weak self] resultado in
            DispatchQueue.main.async {
                guard let self else { return }
                switch resultado {
                case .success(let post):
                    self.actualizarDato(titulo: "API GET", detalle: "HTTP 200 - Consulta exitosa")
                    self.actualizarDato(titulo: "Título recibido", detalle: post.title)
                case .failure(let error):
                    self.actualizarDato(titulo: "API GET", detalle: "Error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func consumirAPIPost(usuario: String) {
        actualizarDato(titulo: "API POST", detalle: "Enviando información...")
        APIService.shared.registrarUsuario(
            usuario: usuario,
            fecha: obtenerFechaActual(),
            dispositivo: obtenerInformacionDispositivo()
        ) { [weak self] resultado in
            DispatchQueue.main.async {
                guard let self else { return }
                switch resultado {
                case .success(let registro):
                    self.actualizarDato(titulo: "API POST", detalle: "HTTP 201 - Información enviada")
                    self.actualizarDato(titulo: "Registro remoto", detalle: "\(registro.usuario) - ID \(registro.id ?? 0)")
                case .failure(let error):
                    self.actualizarDato(titulo: "API POST", detalle: "Error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func guardarRegistroFirestore(usuario: String) {
        actualizarDato(titulo: "Firestore", detalle: "Guardando registro...")
        guard let usuarioFirebase = Auth.auth().currentUser else {
            actualizarDato(titulo: "Firestore", detalle: "No existe una sesión autenticada")
            return
        }
        let referencia = firestore.collection("usuarios")
            .document(usuarioFirebase.uid).collection("registros").document()
        let documento: [String: Any] = [
            "usuario": usuario,
            "correo": usuarioFirebase.email ?? "",
            "uid": usuarioFirebase.uid,
            "fecha": FieldValue.serverTimestamp(),
            "fechaLocal": obtenerFechaActual(),
            "dispositivo": obtenerInformacionDispositivo(),
            "apiGET": "HTTP 200",
            "apiPOST": "HTTP 201"
        ]
        referencia.setData(documento) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.actualizarDato(titulo: "Firestore", detalle: "Error: \(error.localizedDescription)")
                } else {
                    self.actualizarDato(titulo: "Firestore", detalle: "Registro remoto guardado")
                    print("Registro guardado en Firestore: \(referencia.path)")
                }
            }
        }
    }

    private func solicitarUbicacion() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            actualizarDato(titulo: "Ubicación", detalle: "Obteniendo ubicación...")
            locationManager.requestLocation()
        case .denied:
            actualizarDato(titulo: "Ubicación", detalle: "Permiso rechazado")
        case .restricted:
            actualizarDato(titulo: "Ubicación", detalle: "Acceso restringido")
        @unknown default:
            actualizarDato(titulo: "Ubicación", detalle: "Estado desconocido")
        }
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.datos.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let celda = tableView.dequeueReusableCell(withIdentifier: "MetadataCell", for: indexPath)
        let dato = viewModel.datos[indexPath.row]
        celda.textLabel?.text = dato.titulo
        celda.detailTextLabel?.text = dato.detalle
        celda.detailTextLabel?.numberOfLines = 0
        celda.selectionStyle = .none
        return celda
    }
}

extension ViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let ubicacion = locations.last else { return }
        let latitud = String(format: "%.6f", ubicacion.coordinate.latitude)
        let longitud = String(format: "%.6f", ubicacion.coordinate.longitude)
        actualizarDato(titulo: "Ubicación", detalle: "Latitud: \(latitud) | Longitud: \(longitud)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        actualizarDato(titulo: "Ubicación", detalle: "Error: \(error.localizedDescription)")
    }
}
