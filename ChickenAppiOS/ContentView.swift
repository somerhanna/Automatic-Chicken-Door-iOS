//
//  ContentView.swift
//  ChickenAppiOS
//
//  Created by Somer Hanna on 3/18/26.
//

import SwiftUI
import CoreBluetooth

// MARK: - BLE Manager
class BLEManager: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    
    @Published var isConnected = false
    @Published var connectionStatus = "Not Connected"
    @Published var lastCommand = ""
    
    // UUIDs must match the ESP32 sketch
    let serviceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    let characteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func connect() {
        if !isConnected {
            connectionStatus = "Scanning for ChickenDoor..."
            centralManager.scanForPeripherals(withServices: [serviceUUID])
        }
    }
    
    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func sendCommand(_ command: String) {
        guard let peripheral = peripheral,
              let characteristic = characteristic else {
            connectionStatus = "Not connected to ESP32"
            return
        }
        
        let data = command.data(using: .utf8)!
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        lastCommand = command
        connectionStatus = "Sent: \(command)"
    }
}

// MARK: - BLE Manager Delegate
extension BLEManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connectionStatus = "Bluetooth is on"
        case .poweredOff:
            connectionStatus = "Bluetooth is off"
        case .unsupported:
            connectionStatus = "Bluetooth not supported"
        default:
            connectionStatus = "Unknown state"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == "ChickenDoor" {
            self.peripheral = peripheral
            self.peripheral?.delegate = self
            centralManager.stopScan()
            centralManager.connect(peripheral)
            connectionStatus = "Connecting to ChickenDoor..."
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectionStatus = "Connected! Discovering services..."
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectionStatus = "Disconnected"
        self.peripheral = nil
        self.characteristic = nil
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == characteristicUUID {
                    self.characteristic = characteristic
                    connectionStatus = "Ready to send commands"
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            connectionStatus = "Write error: \(error.localizedDescription)"
        } else {
            connectionStatus = "Command sent successfully!"
        }
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.3),
                    Color.green.opacity(0.2),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Main Content
            VStack(spacing: 25) {
                // Header
                VStack(spacing: 10) {
                    Text("🐔 Chicken Door")
                        .font(.system(size: 45, weight: .bold))
                        .foregroundColor(.blue)
                        .shadow(color: .gray.opacity(0.3), radius: 2, x: 2, y: 2)
                    
                    Text("Time Controller")
                        .font(.title3)
                        .foregroundColor(.brown)
                    
                    // Connection Status
                    HStack {
                        Circle()
                            .fill(bleManager.isConnected ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        Text(bleManager.connectionStatus)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(20)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Control Buttons
                VStack(spacing: 20) {
                    Text("Add Time to Chicken Door")
                        .font(.headline)
                        .foregroundColor(.brown)
                    
                    // Main buttons grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        TimeButton(title: "+1 Hour",
                                  icon: "clock.fill",
                                  color: .blue) {
                            bleManager.sendCommand("add_hour")
                        }
                        
                        TimeButton(title: "+30 Min",
                                  icon: "clock",
                                  color: .green) {
                            bleManager.sendCommand("add_30min")
                        }
                        
                        TimeButton(title: "+15 Min",
                                  icon: "clock",
                                  color: .orange) {
                            bleManager.sendCommand("add_15min")
                        }
                        
                        TimeButton(title: "Get Time",
                                  icon: "arrow.clockwise",
                                  color: .purple) {
                            bleManager.sendCommand("get_time")
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Connect/Disconnect buttons
                VStack(spacing: 12) {
                    if !bleManager.isConnected {
                        Button(action: {
                            bleManager.connect()
                        }) {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Connect to Chicken Door")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(15)
                        }
                    } else {
                        Button(action: {
                            bleManager.disconnect()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Disconnect")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(15)
                        }
                    }
                    
                    if !bleManager.lastCommand.isEmpty {
                        Text("Last: \(bleManager.lastCommand)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .padding()
        }
    }
}

// MARK: - Custom Button Style
struct TimeButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 35))
                Text(title)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding(.vertical, 25)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(20)
            .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 5)
        }
    }
}

#Preview {
    ContentView()
}
