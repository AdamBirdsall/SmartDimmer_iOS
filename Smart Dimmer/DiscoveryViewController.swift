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
    @IBOutlet weak var backgroundView: UIView!
    
    /**
     * View did load default functions
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mainSlider.isEnabled = true
        self.mainSlider.isContinuous = false
        self.popUpView.layer.cornerRadius = 12.5
        self.popUpView.frame.origin.y = self.tableView.frame.maxY
        
        let rect = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 10, height: 50))

        var titleView : UIImageView
        titleView = UIImageView(frame:rect)
        titleView.contentMode = .scaleAspectFit
        titleView.image = UIImage(named: "topBarTitle.png")
        
        self.navigationItem.titleView = titleView
        
        setupSideMenu()
        
        self.startManager()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    
        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(DiscoveryViewController.scanForDevice), userInfo: nil, repeats: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.popUpView.frame.origin.y = self.view.frame.maxY
        self.backgroundView.alpha = 0.0
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    fileprivate func setupSideMenu() {
        SideMenuManager.menuLeftNavigationController = storyboard!.instantiateViewController(withIdentifier: "LeftSideMenu") as? UISideMenuNavigationController
        SideMenuManager.menuPresentMode = .menuSlideIn
        SideMenuManager.menuAddPanGestureToPresent(toView: self.navigationController!.navigationBar)
        SideMenuManager.menuAddScreenEdgePanGesturesToPresent(toView: self.navigationController!.view)
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
        cell.detailTextLabel?.text = "Not Connected"
        
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
    
    var aleViewIsShowing: Bool = false
    @IBAction func scanAgain(_ sender: Any) {
        scanForNewPeripherals()
//        
//        aleViewIsShowing = !aleViewIsShowing
//        
//        if (aleViewIsShowing) {
//            // open the view
//            UIView.animate(withDuration: 0.35, animations: {
//                self.popUpView.frame.origin.y = self.view.frame.maxY - self.popUpView.frame.size.height - 10
//                self.backgroundView.alpha = 0.5
//            })
//        } else {
//            // close the view
//            UIView.animate(withDuration: 0.35, animations: {
//                self.popUpView.frame.origin.y = self.view.frame.maxY
//                self.backgroundView.alpha = 0.0
//            })
//        }
    }
    
    func scanForNewPeripherals() {
        self.peripherals.removeAll()
        self.tableView.reloadData()
        scanForDevice()
    }
    
    /**************************************************************************************/
    /**************************************************************************************/
    /**
     * Writing to the bluetooth module
     */
    
    func startManager() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
        //        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey : Device.restoreIdentifier])
    }
    func scanForDevice() {
        centralManager.scanForPeripherals(withServices: [CBUUID(string: DISCOVERY_UUID)], options: nil)
        Timer.scheduledTimer(timeInterval: 6.0, target: self, selector: #selector(DiscoveryViewController.stopScanning), userInfo: nil, repeats: false)
    }
    func stopScanning() {
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
        
        UIView.animate(withDuration: 0.35, animations: {
            self.popUpView.frame.origin.y = self.tableView.frame.maxY - self.popUpView.frame.size.height - 10
            self.backgroundView.alpha = 0.5
        })
        
        self.connectedLabel.text = "Connected to: \(connectedPeripheral.name!)"
        self.tableView.isUserInteractionEnabled = false
        
        connectedPeripheral.delegate = self
        connectedPeripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        print(error.debugDescription)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?){
       
        UIView.animate(withDuration: 0.35, animations: {
            self.popUpView.frame.origin.y = self.tableView.frame.maxY
            self.backgroundView.alpha = 0.0
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
