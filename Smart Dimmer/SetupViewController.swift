//
//  SetupViewController.swift
//  Smart Dimmer
//
//  Created by Adam Birdsall on 8/16/17.
//  Copyright © 2017 Adam Birdsall. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreData
import SimpleAnimation

class SetupViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CBCentralManagerDelegate, CBPeripheralDelegate, UITextFieldDelegate, UINavigationControllerDelegate {

    let managedObjectContext = (UIApplication.shared.delegate
        as! AppDelegate).persistentContainer.viewContext
    
    let DISCOVERY_UUID = "00001523-1212-EFDE-1523-785FEABCD123"
    let WRITE_CHARACTERISTIC = "00001525-1212-EFDE-1523-785FEABCD123"
    let READ_CHARACTERISTIC = "00001524-1212-EFDE-1523-785FEABCD123"
    
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral!
    var peripherals = Array<CBPeripheral>()
    var writeCharacteristic: CBCharacteristic!
    var readCharacteristic: CBCharacteristic!
    
    var coreDataArray = Array<CoreDataDevice>()
    
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var brightnessView: UIView!
    @IBOutlet weak var popUpView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var backgroundView: UIView!
    
    @IBOutlet weak var nameTextField: UITextField!
    /**
     * View did load default functions
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Notification Center for resigning the app
        NotificationCenter.default.addObserver(self, selector: #selector(DiscoveryViewController.disconnectFromPeripherals), name: NSNotification.Name(rawValue: "disconnectFromAll"), object: nil)
        
        self.brightnessView.layer.cornerRadius = 12.5
        self.disconnectButton.layer.cornerRadius = 12.5
        self.popUpView.layer.cornerRadius = 12.5
        self.popUpView.alpha = 0.0
        self.backgroundView.alpha = 0.0
        
        self.nameTextField.delegate = self
        
        self.startManager()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.nameTextField.resignFirstResponder()
        return true
    }
    
    override func viewWillLayoutSubviews() {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector (DiscoveryViewController.scanAgain))
        self.navigationItem.rightBarButtonItem = refreshButton
        
        Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(DiscoveryViewController.scanForDevice), userInfo: nil, repeats: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.backgroundView.alpha = 0.0
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func disconnectFromPeripherals() {
        
        if (connectedPeripheral != nil) {
            centralManager.cancelPeripheralConnection(connectedPeripheral)
        }
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
        
        retrieveCoreData()
        
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
    

    @IBAction func lowestBrightness(_ sender: Any) {
        writeBLEData(202)
    }
    
    @IBAction func highestBrightness(_ sender: Any) {
        writeBLEData(201)
    }
    
    @IBAction func disconnectPressed(_ sender: Any) {
        saveToCoreData(peripheral: connectedPeripheral)
        centralManager.cancelPeripheralConnection(connectedPeripheral)
    }
    
    func saveToCoreData(peripheral: CBPeripheral) {
        let entityDescription =
            NSEntityDescription.entity(forEntityName: "Devices",
                                       in: managedObjectContext)
        
        let device = DevicesMO(entity: entityDescription!,
                               insertInto: managedObjectContext)
        
        device.name = nameTextField.text!
        device.uuid = peripheral.identifier.uuidString
        device.groups = ""
        
        do {
            try managedObjectContext.save()
            self.nameTextField.text = ""
            
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    func retrieveCoreData() {
        let entityDescription =
            NSEntityDescription.entity(forEntityName: "Devices",
                                       in: managedObjectContext)
        
        let request: NSFetchRequest<DevicesMO> = DevicesMO.fetchRequest()
        request.entity = entityDescription
        
//        let pred = NSPredicate(format: "(name = %@)", name.text!)
//        request.predicate = pred
        
        do {
            var results =
                try managedObjectContext.fetch(request as!
                    NSFetchRequest<NSFetchRequestResult>)
            
            if results.count > 0 {
                let match = results[0] as! NSManagedObject
                
                let newDevice: CoreDataDevice = CoreDataDevice()
                newDevice.name = match.value(forKey: "name") as! String
                newDevice.uuid = match.value(forKey: "uuid") as! String
                newDevice.groups = match.value(forKey: "groups") as! String
                
                coreDataArray.append(newDevice)
                
            } else {
//                status.text = "No Match"
            }
            
        } catch let error {
            print(error.localizedDescription)
//            status.text = error.localizedDescription
        }
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
        //        let hexData = hex.data(using: .utf8)
        
        let trimmedString = hex.trimmingCharacters(in: .whitespaces)
        
        let data = trimmedString.newHexadecimal()
        
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
        
        self.popUpView.transform = .identity
        self.popUpView.bounceIn(from: .top)
        
        UIView.animate(withDuration: 0.15, animations: {
            self.backgroundView.alpha = 0.5
            self.navigationController?.navigationBar.isUserInteractionEnabled = false
        })
    
        self.tableView.isUserInteractionEnabled = false
        
        connectedPeripheral.delegate = self
        connectedPeripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        print(error.debugDescription)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?){
        
        self.popUpView.transform = .identity
        self.popUpView.slideOut(to: .top)
        
        UIView.animate(withDuration: 0.15, animations: {
            self.backgroundView.alpha = 0.0
            self.navigationController?.navigationBar.isUserInteractionEnabled = true
        })
        
        if self.connectedPeripheral != nil {
            self.connectedPeripheral.delegate = nil
            self.connectedPeripheral = nil
            self.writeCharacteristic = nil
            self.readCharacteristic = nil
        }
        
        print("did disconnect")
        
        self.tableView.isUserInteractionEnabled = true
//        scanForNewPeripherals()
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
extension String {
    
    func newHexadecimal() -> Data? {
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
