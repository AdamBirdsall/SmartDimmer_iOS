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
import CoreData
import StepSlider
import VerticalSteppedSlider

// TODO: make slider vertical for brightness

class DiscoveryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CBCentralManagerDelegate, CBPeripheralDelegate, UINavigationControllerDelegate {
    
    var coreDataDevices: [NSManagedObject] = []
    
    let DISCOVERY_UUID = "00001523-1212-EFDE-1523-785FEABCD123"
    let WRITE_CHARACTERISTIC = "00001525-1212-EFDE-1523-785FEABCD123"
    let READ_CHARACTERISTIC = "00001524-1212-EFDE-1523-785FEABCD123"
    
    var openAppFlag: Bool = true
    
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral!
    var peripherals = Array<CBPeripheral>()
    var writeCharacteristic: CBCharacteristic!
    var readCharacteristic: CBCharacteristic!
    
    var connectedPeripheralArray = Array<Peripherals>()
    
    var tableObjects: [NSManagedObject] = []
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var connectedLabel: UILabel!
    
    @IBOutlet weak var brightnessLabel: UILabel!
    @IBOutlet weak var popUpView: UIView!
    @IBOutlet weak var backgroundView: UIView!
    var cancelOrMenuButton: UIBarButtonItem!
    @IBOutlet weak var groupsButton: UIBarButtonItem!
    
    @IBOutlet weak var verticalStepSlider: VSSlider!
    @IBOutlet weak var mainStepSlider: StepSlider!
    @IBOutlet weak var sliderView: UIView!
    @IBOutlet weak var disconnectButton: UIButton!
    
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action:
            #selector(DiscoveryViewController.scanAgain), for: UIControlEvents.allEvents)
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
    
//        verticalStepSlider.setIndex(0, animated: true)
        verticalStepSlider.addTarget(self, action:
            #selector(DiscoveryViewController.updateLightValue(_:)), for: UIControlEvents.valueChanged)
//
        self.disconnectButton.layer.cornerRadius = 12.5
        self.popUpView.layer.cornerRadius = 12.5
        self.popUpView.frame.origin.y = self.tableView.frame.maxY
        self.popUpView.alpha = 0.0
        
        self.sliderView.layer.cornerRadius = 12.5
        
        cancelOrMenuButton = UIBarButtonItem(image: UIImage(named: "icons8-Menu-25.png"), style: .plain, target: self, action: #selector(DiscoveryViewController.segueToMenu))
        self.navigationItem.leftBarButtonItem  = cancelOrMenuButton
        
        let rect = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 10, height: 50))

        var titleView : UIImageView
        titleView = UIImageView(frame:rect)
        titleView.contentMode = .scaleAspectFit
        titleView.image = UIImage(named: "topBarTitle.png")
        
        self.navigationItem.titleView = titleView
        
        setupSideMenu()
        
        self.startManager()
        
        self.tableView.addSubview(self.refreshControl)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        peripherals.removeAll()
        self.tableView.reloadData()
    
        Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(DiscoveryViewController.scanForDevice), userInfo: nil, repeats: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        retrieve()

        self.popUpView.frame.origin.y = self.view.frame.maxY
        self.backgroundView.alpha = 0.0
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        if (self.tableView.isEditing) {
            
            for peripheral in connectedPeripheralArray {
                centralManager.cancelPeripheralConnection(peripheral.connectedPeripheral)
                
                let index = connectedPeripheralArray.index(where: {$0.connectedPeripheral.identifier.uuidString == peripheral.connectedPeripheral.identifier.uuidString})
                self.connectedPeripheralArray.remove(at: index!)
            }
            
        } else {
            if (connectedPeripheral != nil) {
                centralManager.cancelPeripheralConnection(connectedPeripheral)
            }
        }
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
    
    func disconnectFromPeripherals() {
        if (self.tableView.isEditing) {
            
            for peripheral in connectedPeripheralArray {
                centralManager.cancelPeripheralConnection(peripheral.connectedPeripheral)
                
                let index = connectedPeripheralArray.index(where: {$0.connectedPeripheral.identifier.uuidString == peripheral.connectedPeripheral.identifier.uuidString})
                self.connectedPeripheralArray.remove(at: index!)
            }
            
        } else {
            if (connectedPeripheral != nil) {
                centralManager.cancelPeripheralConnection(connectedPeripheral)
            }
        }
    }
    
    /**************************************************************************************/
    /**************************************************************************************/
    /**
     * Tableview functions
     */
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    var deviceNameString = ""
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if (!self.tableView.isEditing) {
            self.tableView.deselectRow(at: indexPath, animated: true)
            deviceNameString = (self.tableView.cellForRow(at: indexPath)?.textLabel?.text)!
        }

        connectedPeripheral = peripherals[indexPath.row]
        centralManager.connect(connectedPeripheral, options: nil)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
        if (self.tableView.isEditing) {
            
            let index = connectedPeripheralArray.index(where: {$0.connectedPeripheral.identifier.uuidString == peripherals[indexPath.row].identifier.uuidString})
            self.connectedPeripheralArray.remove(at: index!)
            
            centralManager.cancelPeripheralConnection(peripherals[indexPath.row])
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        // Configure the cell...
        
        let peripheral = peripherals[indexPath.row]
        var nameString = ""
        
        for device in coreDataDevices {
            if (peripheral.identifier.uuidString == device.value(forKey: "uuid") as! String) {
                nameString = device.value(forKey: "name") as! String
            }
        }
        
        if (nameString == ""){
            cell.textLabel?.text = peripheral.name
        } else {
            cell.textLabel?.text = nameString
        }
        
        cell.detailTextLabel?.text = peripheral.identifier.uuidString
        
        return cell
    }
    
    /**************************************************************************************/
    /**************************************************************************************/
    
    var defaultValue:Float = 0.0
    func updateLightValue(_ sender: Any) {
        
        let brightnessValue = self.verticalStepSlider.roundedValue * 10
        
        if (brightnessValue != defaultValue) {
            
            self.brightnessLabel.text = "\(Int(brightnessValue))"
            
            writeBLEData(Int(brightnessValue))
            
            defaultValue = brightnessValue
            
        } else {
            
        }
    }
    
    @IBAction func doneClicked(_ sender: Any) {
        
        defaultValue = 0.0
        
        if (self.tableView.isEditing) {
            
            for peripheral in connectedPeripheralArray {
                centralManager.cancelPeripheralConnection(peripheral.connectedPeripheral)
                
                let index = connectedPeripheralArray.index(where: {$0.connectedPeripheral.identifier.uuidString == peripheral.connectedPeripheral.identifier.uuidString})
                self.connectedPeripheralArray.remove(at: index!)
            }
            
        } else {
            self.connectedLabel.text = ""

            if (connectedPeripheral != nil) {
                centralManager.cancelPeripheralConnection(connectedPeripheral)
            } else {
                let alertController = UIAlertController(title: "Error disconnecting", message: "You are not connected to any device", preferredStyle: UIAlertControllerStyle.alert)
                let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel) {
                    (result : UIAlertAction) -> Void in
                    
                    UIView.animate(withDuration: 0.35, animations: {
                        self.popUpView.frame.origin.y = self.tableView.frame.maxY
                        self.backgroundView.alpha = 0.0
                        self.navigationController?.navigationBar.isUserInteractionEnabled = true
                    })
                }
                
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    @IBAction func switchToGroups(_ sender: Any) {
        
        if (self.groupsButton.title == "Groups") {
            self.groupsButton.title = "Connect"
            
            cancelOrMenuButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector (DiscoveryViewController.cancelGroupView))
            cancelOrMenuButton.tintColor = UIColor.red
            self.navigationItem.leftBarButtonItem  = cancelOrMenuButton
            
            self.tableView?.setEditing(true, animated: true)
        } else {
            if (connectedPeripheralArray.count > 0) {
                self.popUpView.alpha = 1.0
                UIView.animate(withDuration: 0.35, animations: {
                    self.popUpView.frame.origin.y = self.tableView.frame.maxY - self.popUpView.frame.size.height - 10
                    self.backgroundView.alpha = 0.5
                    self.navigationController?.navigationBar.isUserInteractionEnabled = false
                    self.tableView.isUserInteractionEnabled = false
                })
            } else {
                // Alert View saying to select devices to group
                let alertController = UIAlertController(title: "Please select device(s)", message: "", preferredStyle: UIAlertControllerStyle.alert)
                let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel) {
                    (result : UIAlertAction) -> Void in
                }
                
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    func cancelGroupView() {
        self.groupsButton.title = "Groups"
        
        cancelOrMenuButton = UIBarButtonItem(image: UIImage(named: "icons8-Menu-25.png"), style: .plain, target: self, action: #selector(DiscoveryViewController.segueToMenu))
        self.navigationItem.leftBarButtonItem  = cancelOrMenuButton
        
        for peripheral in connectedPeripheralArray {
            centralManager.cancelPeripheralConnection(peripheral.connectedPeripheral)
            
            let index = connectedPeripheralArray.index(where: {$0.connectedPeripheral.identifier.uuidString == peripheral.connectedPeripheral.identifier.uuidString})
            self.connectedPeripheralArray.remove(at: index!)
        }
        self.tableView?.setEditing(false, animated: true)
    }
    
    func segueToMenu() {
        self.performSegue(withIdentifier: "showMenu", sender: self)
    }
    
    func scanAgain() {
        scanForNewPeripherals()
    }
    
    func endRefresh() {
        refreshControl.endRefreshing()
    }

    func scanForNewPeripherals() {
        self.peripherals.removeAll()
        self.tableView.reloadData()
        for peripheral in connectedPeripheralArray {
            centralManager.cancelPeripheralConnection(peripheral.connectedPeripheral)
            
            let index = connectedPeripheralArray.index(where: {$0.connectedPeripheral.identifier.uuidString == peripheral.connectedPeripheral.identifier.uuidString})
            self.connectedPeripheralArray.remove(at: index!)
        }
        
        centralManager.scanForPeripherals(withServices: [CBUUID(string: DISCOVERY_UUID)], options: nil)
        Timer.scheduledTimer(timeInterval: 2.5, target: self, selector: #selector(DiscoveryViewController.endRefresh), userInfo: nil, repeats: false)
    }
    
    /**************************************************************************************/
    /**************************************************************************************/
    
    func startManager() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func scanForDevice() {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true

        centralManager.scanForPeripherals(withServices: [CBUUID(string: DISCOVERY_UUID)], options: nil)
        Timer.scheduledTimer(timeInterval: 4.0, target: self, selector: #selector(DiscoveryViewController.stopScanning), userInfo: nil, repeats: false)
    }
    
    func stopScanning() {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false

        centralManager.stopScan()
    }
    
    /**
     * Writing to the bluetooth module
     */
    func writeBLEData(_ value: Int) {

        let hex = String(format:"%2X", value)
        
        let trimmedString = hex.trimmingCharacters(in: .whitespaces)
        
        let data = trimmedString.hexadecimal()
        
        if (self.tableView.isEditing) {
            for newPeripheral in connectedPeripheralArray {
                newPeripheral.connectedPeripheral.writeValue(data!, for: newPeripheral.connectedWriteCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
        } else {
            connectedPeripheral?.writeValue(data!, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Writing error", error)
        } else {
            print("Update Succeeded")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Writing error", error)
        } else {
            print("Write Succeeded")
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
        
        if (!self.tableView.isEditing) {
            self.popUpView.alpha = 1.0
            UIView.animate(withDuration: 0.35, animations: {
                self.popUpView.frame.origin.y = self.tableView.frame.maxY - self.popUpView.frame.size.height - 10
                self.backgroundView.alpha = 0.5
                self.navigationController?.navigationBar.isUserInteractionEnabled = false
            })
            self.connectedLabel.text = "Connected to: \(deviceNameString)"
            self.tableView.isUserInteractionEnabled = false
            
            connectedPeripheral.delegate = self
            connectedPeripheral.discoverServices(nil)
        } else {
            self.connectedLabel.text = "Connected to: Group"
            peripheral.delegate = self
            peripheral.discoverServices(nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        let alertController = UIAlertController(title: "Error Connecting", message: error?.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel) {
            (result : UIAlertAction) -> Void in
            
            UIView.animate(withDuration: 0.35, animations: {
                self.popUpView.frame.origin.y = self.tableView.frame.maxY
                self.backgroundView.alpha = 0.0
                self.navigationController?.navigationBar.isUserInteractionEnabled = true
            })
        }
        
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?){
       
        if (error != nil) {
            let alertController = UIAlertController(title: "Error Disconnecting", message: error?.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
            let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel) {
                (result : UIAlertAction) -> Void in
            }
            
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
            
        } else {
            if (self.tableView.isEditing) {
                self.tableView?.setEditing(false, animated: true)
                self.groupsButton.title = "Groups"
                cancelOrMenuButton = UIBarButtonItem(image: UIImage(named: "icons8-Menu-25.png"), style: .plain, target: self, action: #selector(DiscoveryViewController.segueToMenu))
                self.navigationItem.leftBarButtonItem  = cancelOrMenuButton
                peripheral.delegate = nil
            } else {
                if self.connectedPeripheral != nil {
                    self.connectedPeripheral.delegate = nil
                    self.connectedPeripheral = nil
                    self.writeCharacteristic = nil
                    self.readCharacteristic = nil
                }
            }
            
            UIView.animate(withDuration: 0.35, animations: {
                self.popUpView.frame.origin.y = self.tableView.frame.maxY
                self.backgroundView.alpha = 0.0
                self.navigationController?.navigationBar.isUserInteractionEnabled = true
            })
            
            print("did disconnect")
            
            self.tableView.isUserInteractionEnabled = true
        }
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
                
                if (self.tableView.isEditing) {
                    let newPeripheral: Peripherals = Peripherals()
                    newPeripheral.connectedPeripheral = peripheral
                    newPeripheral.connectedWriteCharacteristic = aCharacteristic
                    connectedPeripheralArray.append(newPeripheral)
                }
            }
        }
    }
    
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
            errorMessage = "Pull down to refresh the device list."
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

