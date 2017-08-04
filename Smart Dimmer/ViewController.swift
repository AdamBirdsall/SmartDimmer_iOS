//
//  ViewController.swift
//  Smart Dimmer
//
//  Created by Adam Birdsall on 6/28/17.
//  Copyright © 2017 Adam Birdsall. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    let DISCOVERY_UUID = "00001523-1212-EFDE-1523-785FEABCD123"
    let WRITE_CHARACTERISTIC = "00001525-1212-EFDE-1523-785FEABCD123"
    
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral!
    var peripherals = Array<CBPeripheral>()
    var writeCharacteristic: CBCharacteristic!
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var connectedLabel: UILabel!
    @IBOutlet weak var mainSwitch: UISwitch!
    @IBOutlet weak var mainSlider: UISlider!
    @IBOutlet weak var brightnessLabel: UILabel!
    @IBOutlet weak var dimStepper: UIStepper!
    
    /**
     * View did load default functions
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        self.mainSlider.isEnabled = false
        self.dimStepper.isEnabled = false
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(ViewController.scanForDevice), userInfo: nil, repeats: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

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
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        // Configure the cell...
        
        let peripheral = peripherals[indexPath.row]
        cell.textLabel?.text = peripheral.name
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        connectedPeripheral = peripherals[indexPath.row]
        centralManager.stopScan()
        centralManager.connect(connectedPeripheral, options: nil)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let peripheral = peripherals[indexPath.row]
        
        let alert = UIAlertController(title: "Rename Device", message: nil, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { action in
            let firstTextField = alert.textFields![0] as UITextField

            peripheral.setValue(firstTextField.text, forKey: "name")
            peripheral.setValue(firstTextField.text, forKey: "displayName")
            
            print("\n\n \(peripheral)")
            self.tableView.reloadData()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
        })
        
        alert.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "Enter Device Name"
        }
        
        self.present(alert, animated: true, completion: nil)
    }
    
    /**
     * Switch and slider functions
     */
    @IBAction func switchToggled(_ sender: Any) {
        if (self.mainSwitch.isOn) {
            
            self.mainSlider.value = 100
            self.dimStepper.value = 100
            
            self.mainSlider.isEnabled = true
            self.dimStepper.isEnabled = true
            
            writeBLEData(100)
        } else {
            
            self.mainSlider.value = 0
            self.dimStepper.value = 0
            
            self.mainSlider.isEnabled = false
            self.dimStepper.isEnabled = false
            
            writeBLEData(00)
        }
    }
    
    @IBAction func dimLights(_ sender: Any) {
        
        let step: Float = 10
        let roundedValue = round(self.mainSlider.value / step) * step
        self.mainSlider.value = roundedValue
        
        self.brightnessLabel.text = "\(Int(roundedValue))"
        
        writeBLEData(Int(roundedValue))
    }
    
    @IBAction func dimStepChanged(_ sender: Any) {
        let currentValue = Int(self.dimStepper.value)
        
        self.mainSlider.value = Float(currentValue)
        
        self.brightnessLabel.text = "\(currentValue)"
        
        writeBLEData(currentValue)
    }
    
    /**
     * Writing to the bluetooth module
     */
    func writeBLEData(_ value: Int) {
        
        let hex = String(format:"%2X", value)
        
        let trimmedString = hex.trimmingCharacters(in: .whitespaces)

        let data = trimmedString.hexadecimal()
        
        connectedPeripheral?.writeValue(data!, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
    }
    
    /**
     * Discovery of bluetooth devices
     */
    func scanForDevice() {
        
        centralManager.scanForPeripherals(withServices: [CBUUID(string: DISCOVERY_UUID)], options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//        peripheral.setValue("SmartDimmer (proto) Blue", forKey: "name")
        print("Peripheral: \(peripheral)")
        peripherals.append(peripheral)
        self.tableView.reloadData()
        
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        self.connectedLabel.text = "Connected to: \(connectedPeripheral.name!)"
        
        connectedPeripheral.delegate = self
        
        connectedPeripheral.discoverServices(nil)
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
        
        for characteristic in service.characteristics! {
            
            let aCharacteristic = characteristic
            
            if (aCharacteristic.uuid == CBUUID(string: WRITE_CHARACTERISTIC)) {
                print("Characteristics: \(characteristic)")
                writeCharacteristic = aCharacteristic
            }
        }
    }
    
    func discoverProperties(_ characteristic: CBCharacteristic, error: Error?) {
//        for property in characteristic.properties {
//            print("Properties: \(property)")
//        }
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
    
    /// Create `Data` from hexadecimal string representation
    ///
    /// This takes a hexadecimal representation and creates a `Data` object. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.
    
//    func hexadecimal() -> Data? {
//        var data = Data(capacity: characters.count / 2)
//        
//        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
//        regex.enumerateMatches(in: self, range: NSMakeRange(0, utf16.count)) { match, flags, stop in
//            let byteString = (self as NSString).substring(with: match!.range)
//            var num = UInt8(byteString, radix: 16)!
//            data.append(&num, count: 1)
//        }
//        
//        guard data.count > 0 else { return nil }
//        
//        return data
//    }
    
}
