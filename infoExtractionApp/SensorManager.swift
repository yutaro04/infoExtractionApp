import CoreMotion
import SwiftUI
import Combine
import CoreLocation
import UIKit

// 位置情報マネージャー
class LocationManagerDelegate: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var heading: CLHeading?
    @Published var altitude: Double = 0.0
    @Published var speed: Double = 0.0
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        altitude = location?.altitude ?? 0.0
        speed = location?.speed ?? 0.0
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startUpdatingLocation()
        }
    }
}

// デバイス情報を管理するクラス
@MainActor
class DeviceInfoManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    // センサーデータ
    @Published var accelerometerX: Double = 0.0
    @Published var accelerometerY: Double = 0.0
    @Published var accelerometerZ: Double = 0.0
    
    @Published var gyroX: Double = 0.0
    @Published var gyroY: Double = 0.0
    @Published var gyroZ: Double = 0.0
    
    @Published var magnetometerX: Double = 0.0
    @Published var magnetometerY: Double = 0.0
    @Published var magnetometerZ: Double = 0.0
    
    @Published var pressure: Double = 0.0 // 気圧センサー
    @Published var relativeAltitude: Double = 0.0 // 相対高度
    
    // デバイス基本情報
    var deviceName: String { UIDevice.current.name }
    var deviceModel: String { UIDevice.current.model }
    var systemName: String { UIDevice.current.systemName }
    var systemVersion: String { UIDevice.current.systemVersion }
    var identifierForVendor: String { UIDevice.current.identifierForVendor?.uuidString ?? "N/A" }
    
    // 画面情報
    var screenBounds: String {
        let bounds = UIScreen.main.bounds
        return "\(Int(bounds.width)) x \(Int(bounds.height))"
    }
    var screenScale: String { "\(UIScreen.main.scale)x" }
    var screenBrightness: String { String(format: "%.0f%%", UIScreen.main.brightness * 100) }
    
    // バッテリー情報
    @Published var batteryLevel: Float = 0.0
    @Published var batteryState: String = "Unknown"
    
    // センサー利用可否
    var isAccelerometerAvailable: Bool { motionManager.isAccelerometerAvailable }
    var isGyroAvailable: Bool { motionManager.isGyroAvailable }
    var isMagnetometerAvailable: Bool { motionManager.isMagnetometerAvailable }
    var isDeviceMotionAvailable: Bool { motionManager.isDeviceMotionAvailable }
    
    // メモリ情報
    var totalMemory: String {
        let mem = ProcessInfo.processInfo.physicalMemory
        return ByteCountFormatter.string(fromByteCount: Int64(mem), countStyle: .memory)
    }
    
    // プロセッサ情報
    var processorCount: Int { ProcessInfo.processInfo.processorCount }
    var activeProcessorCount: Int { ProcessInfo.processInfo.activeProcessorCount }
    
    // ストレージ情報
    var totalDiskSpace: String {
        if let space = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemSize] as? Int64 {
            return ByteCountFormatter.string(fromByteCount: space, countStyle: .file)
        }
        return "N/A"
    }
    
    var freeDiskSpace: String {
        if let space = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemFreeSize] as? Int64 {
            return ByteCountFormatter.string(fromByteCount: space, countStyle: .file)
        }
        return "N/A"
    }
    
    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBatteryInfo()
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryInfo()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryInfo()
            }
        }
    }
    
    func updateBatteryInfo() {
        batteryLevel = UIDevice.current.batteryLevel
        
        switch UIDevice.current.batteryState {
        case .unknown:
            batteryState = "不明"
        case .unplugged:
            batteryState = "未接続"
        case .charging:
            batteryState = "充電中"
        case .full:
            batteryState = "満充電"
        @unknown default:
            batteryState = "不明"
        }
    }
    
    func startSensorUpdates() {
        // 加速度センサー
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
                guard let data = data, let self = self else { return }
                Task { @MainActor in
                    self.accelerometerX = data.acceleration.x
                    self.accelerometerY = data.acceleration.y
                    self.accelerometerZ = data.acceleration.z
                }
            }
        }
        
        // ジャイロスコープ
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.1
            motionManager.startGyroUpdates(to: .main) { [weak self] (data, error) in
                guard let data = data, let self = self else { return }
                Task { @MainActor in
                    self.gyroX = data.rotationRate.x
                    self.gyroY = data.rotationRate.y
                    self.gyroZ = data.rotationRate.z
                }
            }
        }
        
        // 磁力計
        if motionManager.isMagnetometerAvailable {
            motionManager.magnetometerUpdateInterval = 0.1
            motionManager.startMagnetometerUpdates(to: .main) { [weak self] (data, error) in
                guard let data = data, let self = self else { return }
                Task { @MainActor in
                    self.magnetometerX = data.magneticField.x
                    self.magnetometerY = data.magneticField.y
                    self.magnetometerZ = data.magneticField.z
                }
            }
        }
        
        // 気圧計（iOS 8.0+、iPhone 6以降）
        if CMAltimeter.isRelativeAltitudeAvailable() {
            let altimeter = CMAltimeter()
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] (data, error) in
                guard let data = data, let self = self else { return }
                Task { @MainActor in
                    self.pressure = data.pressure.doubleValue
                    self.relativeAltitude = data.relativeAltitude.doubleValue
                }
            }
        }
    }
    
    func stopSensorUpdates() {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        motionManager.stopMagnetometerUpdates()
    }
}

// 表示するView
struct SensorView: View {
    @StateObject private var deviceInfo = DeviceInfoManager()
    @StateObject private var locationManager = LocationManagerDelegate()
    
    var body: some View {
        NavigationView {
            List {
                // デバイス基本情報
                Section("デバイス情報") {
                    InfoRow(label: "デバイス名", value: deviceInfo.deviceName)
                    InfoRow(label: "モデル", value: deviceInfo.deviceModel)
                    InfoRow(label: "OS", value: deviceInfo.systemName)
                    InfoRow(label: "OSバージョン", value: deviceInfo.systemVersion)
                    InfoRow(label: "ベンダーID", value: deviceInfo.identifierForVendor)
                }
                
                // 画面情報
                Section("画面情報") {
                    InfoRow(label: "解像度", value: deviceInfo.screenBounds)
                    InfoRow(label: "スケール", value: deviceInfo.screenScale)
                    InfoRow(label: "明るさ", value: deviceInfo.screenBrightness)
                }
                
                // バッテリー情報
                Section("バッテリー") {
                    InfoRow(
                        label: "バッテリー残量",
                        value: deviceInfo.batteryLevel >= 0 
                            ? String(format: "%.0f%%", deviceInfo.batteryLevel * 100)
                            : "N/A"
                    )
                    InfoRow(label: "充電状態", value: deviceInfo.batteryState)
                }
                
                // ストレージ情報
                Section("ストレージ") {
                    InfoRow(label: "総容量", value: deviceInfo.totalDiskSpace)
                    InfoRow(label: "空き容量", value: deviceInfo.freeDiskSpace)
                }
                
                // プロセッサ情報
                Section("プロセッサ") {
                    InfoRow(label: "プロセッサ数", value: "\(deviceInfo.processorCount)")
                    InfoRow(label: "アクティブプロセッサ数", value: "\(deviceInfo.activeProcessorCount)")
                }
                
                // メモリ情報
                Section("メモリ") {
                    InfoRow(label: "物理メモリ", value: deviceInfo.totalMemory)
                }
                
                // 位置情報
                Section("位置情報") {
                    if locationManager.authorizationStatus == .notDetermined {
                        Button("位置情報の使用を許可") {
                            locationManager.requestPermission()
                        }
                    } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                        Text("位置情報へのアクセスが拒否されています")
                            .foregroundColor(.secondary)
                    } else if let location = locationManager.location {
                        InfoRow(label: "緯度", value: String(format: "%.6f°", location.coordinate.latitude))
                        InfoRow(label: "経度", value: String(format: "%.6f°", location.coordinate.longitude))
                        InfoRow(label: "高度", value: String(format: "%.1f m", locationManager.altitude))
                        InfoRow(label: "速度", value: locationManager.speed >= 0 ? String(format: "%.1f m/s", locationManager.speed) : "N/A")
                        InfoRow(label: "精度", value: String(format: "%.1f m", location.horizontalAccuracy))
                        
                        if let heading = locationManager.heading {
                            InfoRow(label: "方位（真北）", value: String(format: "%.1f°", heading.trueHeading))
                            InfoRow(label: "方位（磁北）", value: String(format: "%.1f°", heading.magneticHeading))
                        }
                    } else {
                        Text("位置情報を取得中...")
                            .foregroundColor(.secondary)
                    }
                }
                
                // 気圧センサー
                if CMAltimeter.isRelativeAltitudeAvailable() {
                    Section("気圧・高度センサー") {
                        InfoRow(label: "気圧", value: String(format: "%.2f kPa", deviceInfo.pressure))
                        InfoRow(label: "相対高度", value: String(format: "%.2f m", deviceInfo.relativeAltitude))
                    }
                }
                
                // センサー利用可否
                Section("センサー利用可否") {
                    InfoRow(label: "加速度センサー", value: deviceInfo.isAccelerometerAvailable ? "✓ 利用可能" : "✗ 利用不可")
                    InfoRow(label: "ジャイロスコープ", value: deviceInfo.isGyroAvailable ? "✓ 利用可能" : "✗ 利用不可")
                    InfoRow(label: "磁力計", value: deviceInfo.isMagnetometerAvailable ? "✓ 利用可能" : "✗ 利用不可")
                    InfoRow(label: "デバイスモーション", value: deviceInfo.isDeviceMotionAvailable ? "✓ 利用可能" : "✗ 利用不可")
                    InfoRow(label: "気圧計", value: CMAltimeter.isRelativeAltitudeAvailable() ? "✓ 利用可能" : "✗ 利用不可")
                }
                
                // 加速度センサー
                if deviceInfo.isAccelerometerAvailable {
                    Section("加速度センサー") {
                        InfoRow(label: "X", value: String(format: "%.3f g", deviceInfo.accelerometerX))
                        InfoRow(label: "Y", value: String(format: "%.3f g", deviceInfo.accelerometerY))
                        InfoRow(label: "Z", value: String(format: "%.3f g", deviceInfo.accelerometerZ))
                    }
                }
                
                // ジャイロスコープ
                if deviceInfo.isGyroAvailable {
                    Section("ジャイロスコープ") {
                        InfoRow(label: "X", value: String(format: "%.3f rad/s", deviceInfo.gyroX))
                        InfoRow(label: "Y", value: String(format: "%.3f rad/s", deviceInfo.gyroY))
                        InfoRow(label: "Z", value: String(format: "%.3f rad/s", deviceInfo.gyroZ))
                    }
                }
                
                // 磁力計
                if deviceInfo.isMagnetometerAvailable {
                    Section("磁力計") {
                        InfoRow(label: "X", value: String(format: "%.3f µT", deviceInfo.magnetometerX))
                        InfoRow(label: "Y", value: String(format: "%.3f µT", deviceInfo.magnetometerY))
                        InfoRow(label: "Z", value: String(format: "%.3f µT", deviceInfo.magnetometerZ))
                    }
                }
            }
            .navigationTitle("デバイス情報")
            .onAppear {
                deviceInfo.startSensorUpdates()
                if locationManager.authorizationStatus == .authorizedWhenInUse || 
                   locationManager.authorizationStatus == .authorizedAlways {
                    locationManager.startUpdatingLocation()
                }
            }
            .onDisappear {
                deviceInfo.stopSensorUpdates()
                locationManager.stopUpdatingLocation()
            }
        }
    }
}

// 情報行を表示するヘルパーView
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    SensorView()
}
