import AccessorySetupKit
import CoreBluetooth
import Combine
import UIKit

enum ClickerProtocol {
    static let service = CBUUID(string: "7A1C0001-5B3E-4D2A-9F10-3C5D8E2B6A01")
    static let click = CBUUID(string: "7A1C0002-5B3E-4D2A-9F10-3C5D8E2B6A01")
    static let feedback = CBUUID(string: "7A1C0003-5B3E-4D2A-9F10-3C5D8E2B6A01")
}

@MainActor
final class ClickerService: NSObject, ObservableObject {
    @Published private(set) var status = "No clicker connected"
    @Published private(set) var ready = false
    @Published private(set) var pairedName: String?
    @Published private(set) var setupReady = false
    @Published var errorMessage: String?
    var onClick: ((ClickType) -> Void)?
    private let defaults = UserDefaults.standard
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var feedbackCharacteristic: CBCharacteristic?
    private var subscribed = false
    private var decoder = ClickDecoder()
    private var accessorySession: ASAccessorySession?
    private var showPickerWhenReady = false
    private var pairedID: UUID? {
        defaults.string(forKey: "pairedClickerID").flatMap(UUID.init(uuidString:))
    }

    override init() {
        super.init()
        pairedName = defaults.string(forKey: "pairedClickerName")
        if pairedID != nil {
            startCentral()
            activateSession()
        }
    }

    func setup() {
        #if targetEnvironment(simulator)
        errorMessage = "Bluetooth setup needs a real iPhone. Use the buttons below to try capturing a spot."
        #else
        if accessorySession == nil {
            showPickerWhenReady = true
            activateSession()
        } else if setupReady {
            showPicker()
        }
        #endif
    }

    private func activateSession() {
        let session = ASAccessorySession()
        accessorySession = session
        session.activate(on: .main) { [weak self] event in
            guard let self else { return }
            switch event.eventType {
            case .activated:
                self.setupReady = true
                if let accessory = session.accessories.first(where: { $0.bluetoothIdentifier == self.pairedID }) ?? session.accessories.first {
                    self.remember(accessory)
                }
                else if self.pairedID != nil { self.clearPairing() }
                if self.showPickerWhenReady {
                    self.showPickerWhenReady = false
                    self.showPicker()
                }
            case .accessoryAdded, .accessoryChanged:
                if let accessory = event.accessory { self.remember(accessory) }
            case .accessoryRemoved:
                if event.accessory?.bluetoothIdentifier == self.pairedID { self.clearPairing() }
            case .invalidated:
                self.setupReady = false
                self.accessorySession = nil
                self.errorMessage = event.error?.localizedDescription
            default: break
            }
        }
    }

    private func showPicker() {
        guard let accessorySession else { return }
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothServiceUUID = ClickerProtocol.service
        descriptor.bluetoothNameSubstring = "SpotClicker"
        let image = UIImage(systemName: "button.programmable.square.fill")!
        let item = ASPickerDisplayItem(name: "Spot Clicker", productImage: image, descriptor: descriptor)
        accessorySession.showPicker(for: [item]) { [weak self] error in
            if let error { Task { @MainActor in self?.errorMessage = error.localizedDescription } }
        }
    }

    private func remember(_ accessory: ASAccessory) {
        guard let id = accessory.bluetoothIdentifier else { return }
        if let old = peripheral, old.identifier != id {
            peripheral = nil
            central?.cancelPeripheralConnection(old)
            resetConnection()
        }
        defaults.set(id.uuidString, forKey: "pairedClickerID")
        defaults.set(accessory.displayName, forKey: "pairedClickerName")
        pairedName = accessory.displayName
        startCentral()
        reconnect()
    }

    func forget() {
        guard let accessorySession,
              let accessory = accessorySession.accessories.first(where: { $0.bluetoothIdentifier == pairedID }) else {
            clearPairing()
            return
        }
        accessorySession.removeAccessory(accessory) { [weak self] error in
            Task { @MainActor in
                if let error { self?.errorMessage = error.localizedDescription }
                else { self?.clearPairing() }
            }
        }
    }

    private func clearPairing() {
        defaults.removeObject(forKey: "pairedClickerID")
        defaults.removeObject(forKey: "pairedClickerName")
        pairedName = nil
        let old = peripheral
        peripheral = nil
        if let old { central?.cancelPeripheralConnection(old) }
        resetConnection()
        status = "No clicker connected"
    }

    private func startCentral() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: .main, options: [
            CBCentralManagerOptionRestoreIdentifierKey: "SpotClickerCentral"
        ])
    }

    private func reconnect() {
        guard let central, central.state == .poweredOn, let id = pairedID else { return }
        if peripheral == nil { peripheral = central.retrievePeripherals(withIdentifiers: [id]).first }
        guard let peripheral else { status = "Reconnect using Set up clicker"; return }
        peripheral.delegate = self
        if peripheral.state == .connected { peripheral.discoverServices([ClickerProtocol.service]) }
        else if peripheral.state != .connecting {
            status = "Waiting for clicker"
            central.connect(peripheral)
        }
    }

    func send(_ code: UInt8) {
        guard defaults.object(forKey: "clickerFeedback") as? Bool ?? true,
              let peripheral, peripheral.state == .connected, let feedbackCharacteristic else { return }
        let type: CBCharacteristicWriteType = feedbackCharacteristic.properties.contains(.writeWithoutResponse)
            ? .withoutResponse : .withResponse
        peripheral.writeValue(Data([code]), for: feedbackCharacteristic, type: type)
    }

    private func resetConnection() {
        ready = false
        subscribed = false
        feedbackCharacteristic = nil
        decoder.reset()
    }

    private func updateReady() {
        ready = subscribed && feedbackCharacteristic != nil
        status = ready ? "Ready to save" : "Setting up connection"
    }
}

// The central explicitly uses the main queue; its peripherals inherit that delegate queue.
extension ClickerService: @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: reconnect()
        case .poweredOff: resetConnection(); status = "Bluetooth is off"
        case .unauthorized: resetConnection(); status = "Bluetooth access not allowed"
        case .unsupported: resetConnection(); status = "Bluetooth unavailable"
        default: resetConnection(); status = "Bluetooth starting"
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let restored = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?
            .first(where: { $0.identifier == pairedID }) else { return }
        peripheral = restored
        restored.delegate = self
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral.identifier == pairedID else { return }
        resetConnection()
        status = "Setting up connection"
        peripheral.discoverServices([ClickerProtocol.service])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier == pairedID else { return }
        resetConnection()
        reconnect()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier == pairedID else { return }
        resetConnection()
        status = "Waiting for clicker"
        central.connect(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral.identifier == pairedID else { return }
        guard let service = peripheral.services?.first(where: { $0.uuid == ClickerProtocol.service }) else {
            status = "Clicker service unavailable"; return
        }
        peripheral.discoverCharacteristics([ClickerProtocol.click, ClickerProtocol.feedback], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard peripheral.identifier == pairedID else { return }
        guard error == nil else { status = "Clicker connection failed"; return }
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == ClickerProtocol.click { peripheral.setNotifyValue(true, for: characteristic) }
            if characteristic.uuid == ClickerProtocol.feedback { feedbackCharacteristic = characteristic }
        }
        updateReady()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral.identifier == pairedID, characteristic.uuid == ClickerProtocol.click else { return }
        subscribed = error == nil && characteristic.isNotifying
        updateReady()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral.identifier == pairedID, ready, error == nil, characteristic.uuid == ClickerProtocol.click,
              let data = characteristic.value, let type = decoder.decode(data) else { return }
        onClick?(type)
    }
}
