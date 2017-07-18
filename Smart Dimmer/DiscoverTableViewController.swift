//
//  DiscoverTableViewController.swift
//  Smart Dimmer
//
//  Created by Adam Birdsall on 7/11/17.
//  Copyright © 2017 Adam Birdsall. All rights reserved.
//

import UIKit
import CoreBluetooth

class DiscoverTableViewController: UITableViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    let DISCOVERY_UUID = "00001523-1212-EFDE-1523-785FEABCD123"
    let WRITE_CHARACTERISTIC = "00001525-1212-EFDE-1523-785FEABCD123"
    
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral!
    var peripherals = Array<CBPeripheral>()
    var writeCharacteristic: CBCharacteristic!
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var powerButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(ViewController.scanForDevice), userInfo: nil, repeats: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return peripherals.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! DiscoverTableViewCell
        
        let peripheral = peripherals[indexPath.row]
        cell.nameLabel.text = peripheral.name

        cell.powerButton.tag = indexPath.row
        
        return cell
    }
    
    @IBAction func powerButtonPressed(sender: UIButton) {
        let peripheral = self.peripherals[sender.tag]
        
        print("in the power button function")
    }
    
    

    
    
    
    /**
     * Writing to the bluetooth module
     */
    func writeBLEData(value: [UInt8]) {
        
        let data = NSData(bytes: value, length: value.count)
        
        connectedPeripheral?.writeValue(data as Data, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
    }
    
    /**
     * Discovery of bluetooth devices
     */
    func scanForDevice() {
        
        centralManager.scanForPeripherals(withServices: [CBUUID(string: DISCOVERY_UUID)], options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        peripheral.setValue("SmartDimmer (proto) Blue", forKey: "name")
        print("Peripheral: \(peripheral)")
        peripherals.append(peripheral)
        self.tableView.reloadData()
        
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
//        self.connectedLabel.text = "Connected to: \(connectedPeripheral.name!)"
        
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
    
    func discoverProperties(characteristic: CBCharacteristic, error: Error?) {
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
