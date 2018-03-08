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
    
    var coreDataDevices: [NSManagedObject] = []
    var peripheralNames: [PeripheralObject] = []
    
    var openAppFlag: Bool = true
    var didDisconnect: Bool = false
    
    let DISCOVERY_UUID = "00001523-1212-EFDE-1523-785FEABCD123"
    let WRITE_CHARACTERISTIC = "00001525-1212-EFDE-1523-785FEABCD123"
    let READ_CHARACTERISTIC = "00001524-1212-EFDE-1523-785FEABCD123"
    
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral!
    var peripherals = Array<CBPeripheral>()
    var writeCharacteristic: CBCharacteristic!
    var readCharacteristic: CBCharacteristic!
    
    
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var brightnessView: UIView!
    @IBOutlet weak var popUpView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var backgroundView: UIView!
    
    @IBOutlet weak var nameTextField: UITextField!
    
    
    // Sets the 'pull down to refresh' variable
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action:
            #selector(SetupViewController.scanForNewPeripherals), for: UIControlEvents.allEvents)
        refreshControl.tintColor = UIColor.black
        
        return refreshControl
    }()
    
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
        
        retrieve()
        
        self.startManager()
        
        self.tableView.addSubview(self.refreshControl)
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
        
        self.nameTextField.text = self.tableView.cellForRow(at: indexPath)?.textLabel?.text
        
        for peripheral in peripherals {
            
            if (peripheral.identifier.uuidString == peripheralNames[indexPath.row].uuid) {
                connectedPeripheral = peripheral
                centralManager.connect(connectedPeripheral, options: nil)
                return
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        // Configure the cell...
        
        let peripheral = peripheralNames[indexPath.row]
        
        cell.textLabel?.text = peripheral.name
        cell.detailTextLabel?.text = peripheral.uuid
        
        return cell
    }
    
    @IBAction func lowestBrightness(_ sender: Any) {
        writeBLEData(202, disconnectFlag: false)
    }
    
    @IBAction func highestBrightness(_ sender: Any) {
        writeBLEData(201, disconnectFlag: false)
    }
    
    @IBAction func disconnectPressed(_ sender: Any) {
        save(uuidString: connectedPeripheral.identifier.uuidString, nameString: self.nameTextField.text!)
        
        writeBLEData(0, disconnectFlag: true)
    }
    
    
    func scanForNewPeripherals() {
        self.peripherals.removeAll()
        self.peripheralNames.removeAll()
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
        
        centralManager.scanForPeripherals(withServices: [CBUUID(string: DISCOVERY_UUID)], options: nil)

        Timer.scheduledTimer(timeInterval: 4.0, target: self, selector: #selector(DiscoveryViewController.stopScanning), userInfo: nil, repeats: false)
    }
    
    func stopScanning() {
        
        refreshControl.endRefreshing()
        
        centralManager.stopScan()
    }
    
    func writeBLEData(_ value: Int, disconnectFlag: Bool) {
        
        self.didDisconnect = disconnectFlag
        
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
            if (self.didDisconnect) {
                self.nameTextField.resignFirstResponder()
                
                self.nameTextField.text = ""
                
                centralManager.cancelPeripheralConnection(connectedPeripheral)
                
                self.didDisconnect = false
                
                self.scanForNewPeripherals()
            } else {
                connectedPeripheral.discoverServices(nil)
            }
        }
    }
    
    /**
     * Discovery of bluetooth devices
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        let newPeripheralName = PeripheralObject()
        newPeripheralName.name = peripheral.name!
        newPeripheralName.uuid = peripheral.identifier.uuidString
        
        peripherals.append(peripheral)
        
        for device in coreDataDevices {
            if (newPeripheralName.uuid == device.value(forKey: "uuid") as! String) {
                newPeripheralName.name = device.value(forKey: "name") as! String
            }
        }
        
        peripheralNames.append(newPeripheralName)
        
        peripheralNames = peripheralNames.sorted(by: { $0.name.uppercased() < $1.name.uppercased() })
        
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
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
//            print("Service: \(service)")
            
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
                
//                print("\n\nWrite Characteristics: \(characteristic)")
                
            } else if (aCharacteristic.uuid == CBUUID(string: READ_CHARACTERISTIC)) {
                readCharacteristic = aCharacteristic
//                print("\n\nRead Characteristic: \(characteristic)")
            }
        }
    }
    
    // Bluetooth turing on / off
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        var errorTitle: String = ""
        var errorMessage: String = ""
        
        switch (central.state) {
            
        case .poweredOff:
            print("power off")
            errorTitle = "Bluetooh Off"
            errorMessage = "You have turned off Bluetooth. Please turn on to discover devices."
            break
        case .poweredOn:
            print("power on")
            errorTitle = "Bluetooth On"
            errorMessage = "Press the refresh button to update the device list."
            break
        case .resetting:
            print("resetting")
            break
        case .unauthorized:
            print("unauthorized")
            errorTitle = "Unauthorized"
            errorMessage = "You have not authorized Bluetooth for your device"
            break
        case .unsupported:
            print("unsupported")
            errorTitle = "Bluetooth Unsupported"
            errorMessage = "Your device does not support Bluetooth."
            break
        default:
            print("default")
        }
        
        let alertController = UIAlertController(title: errorTitle, message: errorMessage, preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel) {
            (result : UIAlertAction) -> Void in
        }
        
        alertController.addAction(okAction)
        
        if (openAppFlag) {
            openAppFlag = false
        } else {
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    // Core Data Functions
    func save(uuidString: String, nameString: String) {
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        // 1
        let managedContext =
            appDelegate.persistentContainer.viewContext
        
        for device in coreDataDevices {
            if (uuidString == device.value(forKey: "uuid") as! String) {
                
                let updateDevice = managedContext.object(with: device.objectID)
                
                updateDevice.setValue(nameString, forKey: "name")
                
                do {
                    try managedContext.save()
                } catch let error as NSError {
                    print("Could not save. \(error), \(error.userInfo)")
                }
                
                return
            }
        }
        
        // 2
        let entity =
            NSEntityDescription.entity(forEntityName: "Devices",
                                       in: managedContext)!
        
        
        
        let addDevice = NSManagedObject(entity: entity,
                                     insertInto: managedContext)
        
        // 3
        addDevice.setValue(uuidString, forKey: "uuid")
        addDevice.setValue(nameString, forKeyPath: "name")
        
        // 4
        do {
            try managedContext.save()
            coreDataDevices.append(addDevice)
            
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    func retrieve() {
        //1
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        
        //2
        let fetchRequest =
            NSFetchRequest<NSManagedObject>(entityName: "Devices")
        
        //3
        do {
            coreDataDevices = try managedContext.fetch(fetchRequest)
            
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
    }
}
extension String {
    
    func newHexadecimal() -> Data? {
        var data = Data(capacity: self.count / 2)
        
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
