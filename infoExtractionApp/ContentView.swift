import SwiftUI

struct DeviceInfoView: View {
    // バッテリー監視を有効化
    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    var body: some View {
        List {
            Section(header: Text("デバイス情報")) {
                Text("端末名: \(UIDevice.current.name)")
                Text("OSバージョン: \(UIDevice.current.systemVersion)")
                Text("バッテリー: \(Int(UIDevice.current.batteryLevel * 100))%")
            }
        }
    }
}
