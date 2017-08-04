//
//  DiscoveryViewController.swift
//  Smart Dimmer
//
//  Created by Adam Birdsall on 7/18/17.
//  Copyright © 2017 Adam Birdsall. All rights reserved.
//

import UIKit
import CoreBluetooth
import SideMenu

class DiscoveryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    let DISCOVERY_UUID = "00001523-1212-EFDE-1523-785FEABCD123"
    let WRITE_CHARACTERISTIC = "00001525-1212-EFDE-1523-785FEABCD123"
    let READ_CHARACTERISTIC = "00001524-1212-EFDE-1523-785FEABCD123"
    
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral!
    var peripherals = Array<CBPeripheral>()
    var writeCharacteristic: CBCharacteristic!
    var readCharacteristic: CBCharacteristic!
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var connectedLabel: UILabel!
    @IBOutlet weak var mainSlider: UISlider!
    @IBOutlet weak var brightnessLabel: UILabel!
    @IBOutlet weak var popUpView: UIView!
    @IBOutlet weak var scanAgainButton: UIBarButtonItem!
    
    /**
     * View did load default functions
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        self.mainSlider.isEnabled = true
        self.mainSlider.isContinuous = false
        self.popUpView.layer.cornerRadius = 25.0
        
        setupSideMenu()
        
        self.startManager()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(DiscoveryViewController.scanForDevice), userInfo: nil, repeats: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    fileprivate func setupSideMenu() {
        // Define the menus
        SideMenuManager.menuLeftNavigationController = storyboard!.instantiateViewController(withIdentifier: "LeftSideMenu") as? UISideMenuNavigationController
        
        SideMenuManager.menuPresentMode = .menuSlideIn
        
        // Enable gestures. The left and/or right menus must be set up above for these to work.
        // Note that these continue to work on the Navigation Controller independent of the View Controller it displays!
        SideMenuManager.menuAddPanGestureToPresent(toView: self.navigationController!.navigationBar)
        SideMenuManager.menuAddScreenEdgePanGesturesToPresent(toView: self.navigationController!.view)
        
    }
    
    func startManager() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
//        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey : Device.restoreIdentifier])
    }
    
    /**************************************************************************************/
    /**************************************************************************************/
    /**
     * Tableview functions
     */
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return peripherals.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
        
        connectedPeripheral = peripherals[indexPath.row]
        centralManager.connect(connectedPeripheral, options: nil)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        // Configure the cell...
        
        let peripheral = peripherals[indexPath.row]
        cell.textLabel?.text = peripheral.name
        cell.detailTextLabel?.text = peripheral.identifier.uuidString
        
        return cell
    }
    
    /**************************************************************************************/
    /**************************************************************************************/
    
    
    @IBAction func updateLightValue(_ sender: Any) {
        
        let step: Float = 10
        let roundedValue = round(self.mainSlider.value / step) * step
        self.mainSlider.value = roundedValue
        
        self.brightnessLabel.text = "Brightness: \(Int(roundedValue))"
        
        writeBLEData(Int(roundedValue))
    }
    
    @IBAction func doneClicked(_ sender: Any) {
        
        centralManager.cancelPeripheralConnection(connectedPeripheral)
    }
    
    @IBAction func scanAgain(_ sender: Any) {
        self.peripherals.removeAll()
        self.tableView.reloadData()
        scanForDevice()
    }
    
    /**************************************************************************************/
    /**************************************************************************************/
    /**
     * Writing to the bluetooth module
     */
    func writeBLEData(_ value: Int) {
        
        let hex = String(format:"%2X", value)
        
        let trimmedString = hex.trimmingCharacters(in: .whitespaces)
        
        let data = trimmedString.hexadecimal()
        
//        writeCharacteristic.setValue(data!, forKey: "value")
//        readCharacteristic.setValue(data!, forKey: "value")
        connectedPeripheral?.writeValue(data!, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Writing error", error)
        } else {
            print("\n\nUpdate Succeeded\n\n")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Writing error", error)
        } else {
            print("\n\nWrite Succeeded")
//            connectedPeripheral.readValue(for: writeCharacteristic)
            connectedPeripheral.discoverServices(nil)
        }
    }
    
    /**
     * Discovery of bluetooth devices
     */
    func scanForDevice() {
        centralManager.scanForPeripherals(withServices: [CBUUID(string: DISCOVERY_UUID)], options: nil)
        Timer.scheduledTimer(timeInterval: 6.0, target: self, selector: #selector(DiscoveryViewController.stopScanning), userInfo: nil, repeats: false)
    }
    func stopScanning() {
        centralManager.stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        //        peripheral.setValue("SmartDimmer (proto) Blue", forKey: "name")
        print("Peripheral: \(peripheral)")
        peripherals.append(peripheral)
        self.tableView.reloadData()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        self.connectedLabel.text = "Connected to: \(connectedPeripheral.name!)"
        
        self.tableView.isUserInteractionEnabled = false
        
        connectedPeripheral.delegate = self
        
        connectedPeripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        print(error.debugDescription)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?){
        if self.connectedPeripheral != nil {
            self.connectedPeripheral.delegate = nil
            self.connectedPeripheral = nil
            self.writeCharacteristic = nil
            self.readCharacteristic = nil
        }
        
        UIView.animate(withDuration: 0.75, animations: {
            self.popUpView.alpha = 0.0
        })
        print("did disconnect")
        self.tableView.isUserInteractionEnabled = true
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            print("Service: \(service)")
            
            let aService = service as CBService
            
            if (service.uuid == CBUUID(string: DISCOVERY_UUID)) {
                peripheral.discoverCharacteristics(nil, for: aService)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        UIView.animate(withDuration: 0.75, animations: {
            self.popUpView.alpha = 1.0
        })
        
        for characteristic in service.characteristics! {
            
            let aCharacteristic = characteristic
            
            if (aCharacteristic.uuid == CBUUID(string: WRITE_CHARACTERISTIC)) {
                writeCharacteristic = aCharacteristic
                
                print("\n\nWrite Characteristics: \(characteristic)")
                
            } else if (aCharacteristic.uuid == CBUUID(string: READ_CHARACTERISTIC)) {
                readCharacteristic = aCharacteristic
//                connectedPeripheral.setNotifyValue(true, for: readCharacteristic)
                print("\n\nRead Characteristic: \(characteristic)")
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch (central.state) {
            
        case .poweredOff:
            print("power off")
            break
        case .poweredOn:
            print("power on")
            break
        case .resetting:
            print("resetting")
            break
        case .unauthorized:
            print("unauthorized")
            break
        case .unsupported:
            print("unsupported")
            break
        default:
            print("default")
        }
    }
}

extension String {
    
    func hexadecimal() -> Data? {
        var data = Data(capacity: characters.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSMakeRange(0, utf16.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        
        guard data.count > 0 else { return nil }
        
        return data
    }
    
}
