//
//  BluetoothCentral.swift
//  AudioStreamAirpods
//
//  Created by liu on 2022/01/17.
//

import Foundation
import CoreBluetooth

struct TransferService {
    static let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let writeCharUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    static let readCharUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
}

class BluetoothCentralManager: NSObject{
    
    var centralManager: CBCentralManager!
    var discoveredPeripheral: CBPeripheral?
    var transferCharacteristic: CBCharacteristic?
    var peripherals = Set<CBPeripheral>()
    var messages: [String] = []
    var incomingStr: String = ""
    weak var viewModel: SensorViewModel?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
    
    deinit {
        centralManager.stopScan()
        cleanup()
    }

    /*
     * We will first check if we are already connected to our counterpart
     * Otherwise, scan for peripherals - specifically for our service's 128bit CBUUID
     */
    func retrievePeripheral() {
        if centralManager.isScanning {
            return
        }
        
        let connectedPeripherals: [CBPeripheral] =
        (centralManager.retrieveConnectedPeripherals(withServices: [TransferService.serviceUUID]))

        if let connectedPeripheral = connectedPeripherals.last {
            messages.append("Found connected Peripherals: \(connectedPeripherals.last!.name!)")
            self.discoveredPeripheral = connectedPeripheral
            centralManager.connect(connectedPeripheral, options: nil)
        } else {
            // We were not connected to our counterpart, so start scanning
            let _ = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [self]_ in
                self.centralManager.stopScan()
            }
            centralManager.scanForPeripherals(withServices: nil,
                                              options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }
    
    func asyncRetrievePeripheral() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.retrievePeripheral()
        }
    }
    
    func asyncConnectPeripheral(_ idx: Int) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.centralManager.connect(self.peripherals[self.peripherals.index(self.peripherals.startIndex, offsetBy: idx)],
                                        options: nil)
        }
    }
    
    /*
     *  Call this when things either go wrong, or you're done with the connection.
     *  This cancels any subscriptions if there are any, or straight disconnects if not.
     *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
     */
    func cleanup() {
        // Don't do anything if we're not connected
        guard let discoveredPeripheral = discoveredPeripheral,
            case .connected = discoveredPeripheral.state else { return }

        for service in (discoveredPeripheral.services ?? [] as [CBService]) {
            for characteristic in (service.characteristics ?? [] as [CBCharacteristic]) {
                if characteristic.uuid == TransferService.readCharUUID && characteristic.isNotifying {
                    // It is notifying, so unsubscribe
                    self.discoveredPeripheral?.setNotifyValue(false, for: characteristic)
                }
            }
        }

        // If we've gotten this far, we're connected, but we're not subscribed, so we just disconnect
        writeData("E")
        centralManager.cancelPeripheralConnection(discoveredPeripheral)
    }
    
    /*
     *  Write some test data to peripheral
     */
    private func writeData(_ str: String) {
        
        guard let discoveredPeripheral = discoveredPeripheral,
              let transferCharacteristic = transferCharacteristic,
              discoveredPeripheral.canSendWriteWithoutResponse
        else { return }
        
        // write command data to peripheral
        discoveredPeripheral.writeValue(str.data(using: .ascii)!, for: transferCharacteristic, type: .withoutResponse)
    }
    
    // Update IMU data
    private func updateIMU() {
        let splitedStr = incomingStr.components(separatedBy: " ")
        incomingStr = ""
        if viewModel == nil { return }
        if var roll = Float(splitedStr[0]),
           var pitch = Float(splitedStr[1]),
           var yaw = Float(splitedStr[2]) {
            (roll, pitch, yaw) = (roll / 180 * Float.pi, pitch / 180 * Float.pi, yaw / 180 * Float.pi)
            (viewModel!.headRoll, viewModel!.headPitch, viewModel!.headYaw)
            = (roll, pitch, yaw)
            (viewModel!.imuData4Server[10], viewModel!.imuData4Server[11], viewModel!.imuData4Server[12])
            = (roll, pitch, yaw)
        }
    }
}

// CBCentralManagerDelegate
extension BluetoothCentralManager: CBCentralManagerDelegate {
    // implementations of the CBCentralManagerDelegate methods

    /*
     *  centralManagerDidUpdateState is a required protocol method.
     *  Usually, you'd check for other states to make sure the current device supports LE, is powered on, etc.
     *  In this instance, we're just using it to wait for CBCentralManagerStatePoweredOn, which indicates
     *  the Central is ready to be used.
     */
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {

        switch central.state {
        case .poweredOn:
            // ... so start working with the peripheral
            asyncRetrievePeripheral()
        case .poweredOff:
            messages.append("CBManager is not powered on")
            // In a real app, you'd deal with all the states accordingly
            return
        case .resetting:
            messages.append("CBManager is resetting")
            // In a real app, you'd deal with all the states accordingly
            return
        case .unauthorized:
            // In a real app, you'd deal with all the states accordingly
            if #available(iOS 13.0, *) {
                switch CBCentralManager.authorization {
                case .denied:
                    messages.append("You are not authorized to use Bluetooth")
                case .restricted:
                    messages.append("Bluetooth is restricted")
                default:
                    messages.append("Unexpected authorization")
                }
            } else {
                // Fallback on earlier versions
            }
            return
        case .unknown:
            messages.append("CBManager state is unknown")
            // In a real app, you'd deal with all the states accordingly
            return
        case .unsupported:
            messages.append("Bluetooth is not supported on this device")
            // In a real app, you'd deal with all the states accordingly
            return
        @unknown default:
            messages.append("A previously unknown central manager state occurred")
            // In a real app, you'd deal with yet unknown cases that might occur in the future
            return
        }
    }

    /*
     *  This callback comes whenever a peripheral that is advertising the transfer serviceUUID is discovered.
     *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
     *  we start the connection process
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        // Reject if the signal strength is too low to attempt data transfer.
        // Change the minimum RSSI value depending on your app’s use case.
        guard RSSI.intValue >= -65 && peripheral.name != nil
        else {
            return
        }
        peripherals.insert(peripheral)
    }

    /*
     *  If the connection fails for whatever reason, we need to deal with it.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to %@. %s", peripheral, String(describing: error))
        cleanup()
    }
    
    /*
     *  We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        messages.append("\(peripheral.name!) Connected")
        
        // Make sure we get the discovery callbacks
        peripheral.delegate = self
        
        // Search only for services that match our UUID
        peripheral.discoverServices([TransferService.serviceUUID])
    }
    
    /*
     *  Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        messages.append("\(peripheral.name!) Disconnected")
        discoveredPeripheral = nil
    }

}

extension BluetoothCentralManager: CBPeripheralDelegate {
    // implementations of the CBPeripheralDelegate methods

    /*
     *  The peripheral letting us know when services have been invalidated.
     */
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        for service in invalidatedServices where service.uuid == TransferService.serviceUUID {
            messages.append("Transfer service is invalidated - rediscover services")
            peripheral.discoverServices([TransferService.serviceUUID])
        }
    }

    /*
     *  The Transfer Service was discovered
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            messages.append("Error discovering services: \(error.localizedDescription)")
            cleanup()
            return
        }

        // Discover the characteristic we want...

        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        guard let peripheralServices = peripheral.services else { return }
        for service in peripheralServices where service.uuid == TransferService.serviceUUID {
            discoveredPeripheral = peripheral
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    /*
     *  The Transfer characteristic was discovered.
     *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Deal with errors (if any).
        if let error = error {
            messages.append("Error discovering characteristics: \(error.localizedDescription)")
            cleanup()
            return
        }

        // Again, we loop through the array, just in case and check if it's the right one
        guard let serviceCharacteristics = service.characteristics else { return }
        serviceCharacteristics.forEach { characteristic in
            if characteristic.uuid == TransferService.readCharUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == TransferService.writeCharUUID {
                transferCharacteristic = characteristic
                writeData("S")
            }
        }
        // Once this is complete, we just need to wait for the data to come in.
    }
    
    /*
     *   This callback lets us know more data has arrived via notification on the characteristic
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Deal with errors (if any)
        if let error = error {
            messages.append("Error discovering characteristics: \(error.localizedDescription)")
            cleanup()
            return
        }
        
        guard let characteristicData = characteristic.value,
              let stringFromData = String(data: characteristicData, encoding: .ascii)
        else { return }
        incomingStr += stringFromData.replacingOccurrences(of: "S:", with: "").replacingOccurrences(of: "\r\n", with: "")
        if stringFromData.hasSuffix("\r\n") {
            updateIMU()
        }

//        os_log("Received %d bytes: %s", characteristicData.count, stringFromData)
//
//        // Have we received the end-of-message token?
//        if stringFromData == "EOM" {
//            // End-of-message case: show the data.
//            // Dispatch the text view update to the main queue for updating the UI, because
//            // we don't know which thread this method will be called back on.
//            DispatchQueue.main.async() {
//                self.textView.text = String(data: self.data, encoding: .utf8)
//            }
//
//            // Write test data
//            writeData()
//        } else {
//            // Otherwise, just append the data to what we have previously received.
//            data.append(characteristicData)
//        }
    }

    /*
     *  The peripheral letting us know whether our subscribe/unsubscribe happened or not
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Deal with errors (if any)
//        if let error = error {
//            os_log("Error changing notification state: %s", error.localizedDescription)
//            return
//        }
//
//        // Exit if it's not the transfer characteristic
//        guard characteristic.uuid == TransferService.characteristicUUID else { return }
//
//        if characteristic.isNotifying {
//            // Notification has started
//            os_log("Notification began on %@", characteristic)
//        } else {
//            // Notification has stopped, so disconnect from the peripheral
//            os_log("Notification stopped on %@. Disconnecting", characteristic)
//            cleanup()
//        }
        
    }
    
    /*
     *  This is called when peripheral is ready to accept more data when using write without response
     */
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        messages.append("\(peripheral.name!) is ready")
        viewModel?.stopMotionUpdate()
    }
    
}
