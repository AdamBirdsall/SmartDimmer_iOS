//
//  SetupViewController.swift
//  Smart Dimmer
//
//  Created by Adam Birdsall on 8/16/17.
//  Copyright © 2017 Adam Birdsall. All rights reserved.
//

import UIKit
import CoreBluetooth

class SetupViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CBCentralManagerDelegate, CBPeripheralDelegate {

    
    let DISCOVERY_UUID = "00001523-1212-EFDE-1523-785FEABCD123"
    let WRITE_CHARACTERISTIC = "00001525-1212-EFDE-1523-785FEABCD123"
    let READ_CHARACTERISTIC = "00001524-1212-EFDE-1523-785FEABCD123"
    
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral!
    var peripherals = Array<CBPeripheral>()
    var writeCharacteristic: CBCharacteristic!
    var readCharacteristic: CBCharacteristic!
    
    @IBOutlet weak var popUpView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var backgroundView: UIView!
    
    /**
     * View did load default functions
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.popUpView.layer.cornerRadius = 12.5
        
        self.startManager()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector (DiscoveryViewController.scanAgain))
        self.navigationItem.rightBarButtonItem = refreshButton
        
        Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(DiscoveryViewController.scanForDevice), userInfo: nil, repeats: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
//        self.backgroundView.alpha = 0.0
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    
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
        self.tableView.cellForRow(at: indexPath)?.detailTextLabel?.text = "Connected"
        
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
        cell.detailTextLabel?.text = "Not Configured"
        
        return cell
    }
    

    @IBAction func lowestBrightness(_ sender: Any) {
        writeBLEData(202)
    }
    
    @IBAction func highestBrightness(_ sender: Any) {
        writeBLEData(201)
    }
    
    @IBAction func disconnectPressed(_ sender: Any) {
        centralManager.cancelPeripheralConnection(connectedPeripheral)
    }
    
    func scanAgain() {
        scanForNewPeripherals()
    }
    
    func scanForNewPeripherals() {
        self.peripherals.removeAll()
        self.tableView.reloadData()
        scanForDevice()
    }
    
    /**
     * Writing to the bluetooth module
     */
    func startManager() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
        //        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey : Device.restoreIdentifier])
    }
    func scanForDevice() {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        let uiBusy = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        uiBusy.hidesWhenStopped = true
        uiBusy.startAnimating()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: uiBusy)
        
        centralManager.scanForPeripherals(withServices: [CBUUID(string: DISCOVERY_UUID)], options: nil)

        Timer.scheduledTimer(timeInterval: 4.0, target: self, selector: #selector(DiscoveryViewController.stopScanning), userInfo: nil, repeats: false)
    }
    func stopScanning() {
        
        let refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector (DiscoveryViewController.scanAgain))
        self.navigationItem.rightBarButtonItem = refreshButton
        
        centralManager.stopScan()
    }
    
    func writeBLEData(_ value: Int) {
        
        let hex = String(format:"%2X", value)
        let hexData = hex.data(using: .utf8)
        
        connectedPeripheral?.writeValue(hexData!, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
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
            connectedPeripheral.discoverServices(nil)
        }
    }
    
    /**
     * Discovery of bluetooth devices
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        print("Peripheral: \(peripheral)")
        peripherals.append(peripheral)
        self.tableView.reloadData()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        UIView.animate(withDuration: 0.15, animations: {
            self.backgroundView.alpha = 0.5
            self.popUpView.alpha = 1.0
        })
    
        self.tableView.isUserInteractionEnabled = false
        
        connectedPeripheral.delegate = self
        connectedPeripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        print(error.debugDescription)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?){
        
        UIView.animate(withDuration: 0.15, animations: {
            self.backgroundView.alpha = 0.0
            self.popUpView.alpha = 0.0
        })
        
        if self.connectedPeripheral != nil {
            self.connectedPeripheral.delegate = nil
            self.connectedPeripheral = nil
            self.writeCharacteristic = nil
            self.readCharacteristic = nil
        }
        
        print("did disconnect")
        
        self.tableView.isUserInteractionEnabled = true
        scanForNewPeripherals()
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
                writeCharacteristic = aCharacteristic
                
                print("\n\nWrite Characteristics: \(characteristic)")
                
            } else if (aCharacteristic.uuid == CBUUID(string: READ_CHARACTERISTIC)) {
                readCharacteristic = aCharacteristic
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
