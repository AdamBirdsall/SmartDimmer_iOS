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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(DiscoverTableViewController.scanForDevice), userInfo: nil, repeats: false)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    
    @IBAction func switchToggled(_ sender: Any) {
        if (self.mainSwitch.isOn) {
            self.connectedLabel.text = "On"
            writeCharacteristic.setValue("<25>", forKey: "value")
            print("Characteristic: \(writeCharacteristic!)")
            writeBLEData(string: "<value>15")
        } else {
            self.connectedLabel.text = "Off"
            writeCharacteristic.setValue("<1>", forKey: "value")
            print("Characteristic: \(writeCharacteristic!)")
            writeBLEData(string: "<value>10")
        }
    }
    
    func writeBLEData(string: String) {
        let data = string.data(using: String.Encoding.utf8)
        
        connectedPeripheral.writeValue(data!, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
        
        connectedPeripheral.discoverServices(nil)
    }
    
    // MARK: - Table view data source
    
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
    
    // Central Manager Delegates
    /*********************************************/
    func scanForDevice() {
        
        centralManager.scanForPeripherals(withServices: [CBUUID(string: DISCOVERY_UUID)], options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
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

