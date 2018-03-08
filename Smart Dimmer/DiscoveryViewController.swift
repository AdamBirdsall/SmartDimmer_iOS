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
import SimpleAnimation


class DiscoveryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CBCentralManagerDelegate, CBPeripheralDelegate, UINavigationControllerDelegate {
    
    var coreDataDevices: [NSManagedObject] = []
    var deviceNameString = ""
    var deviceUuidString = ""
    var defaultValue:Float = 0.0
    
    let DISCOVERY_UUID = "00001523-1212-EFDE-1523-785FEABCD123"
    let WRITE_CHARACTERISTIC = "00001525-1212-EFDE-1523-785FEABCD123"
    let READ_CHARACTERISTIC = "00001524-1212-EFDE-1523-785FEABCD123"
    
    var openAppFlag: Bool = true
    
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral!
    var peripherals = Array<CBPeripheral>()
    var peripheralNames: [PeripheralObject] = []
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
    @IBOutlet weak var sliderView: UIView!
    @IBOutlet weak var disconnectButton: UIButton!
    
    @IBOutlet weak var onOffSwitch: UISwitch!
    
    // Sets the 'pull down to refresh' variable
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
    
        verticalStepSlider.addTarget(self, action:
            #selector(DiscoveryViewController.updateLightValue(_:)), for: UIControlEvents.valueChanged)

        self.disconnectButton.layer.cornerRadius = 12.5
        self.popUpView.layer.cornerRadius = 12.5
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
        
//        retrieve()
        
        peripherals.removeAll()
        peripheralNames.removeAll()
        self.tableView.reloadData()
    
        Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(DiscoveryViewController.scanForDevice), userInfo: nil, repeats: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        retrieve()

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
    
    // Disconnects from peripherals. Used when screen changes
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
    
    func powerTurnedOff() {
        self.tableView.isUserInteractionEnabled = true
        self.tableView.reloadData()
        
        self.popUpView.transform = .identity
        self.popUpView.slideOut(to: .bottom)
        
        UIView.animate(withDuration: 0.15, animations: {
            self.backgroundView.alpha = 0.0
            self.navigationController?.navigationBar.isUserInteractionEnabled = true
        })
    }
    
    /**************************************************************************************/
    /**************************************************************************************/
    
    // Button Actions and writing to the BLE devices
    
    func updateLightValue(_ sender: Any) {
        
        let brightnessValue = self.verticalStepSlider.roundedValue * 10
        
        if (brightnessValue > 0.0) {
            self.onOffSwitch.isOn = true
        } else {
            self.onOffSwitch.isOn = false
        }
        
        if (brightnessValue != defaultValue) {
            
            self.brightnessLabel.text = "\(Int(brightnessValue))%"
            
            writeBLEData(Int(brightnessValue))
            
            defaultValue = brightnessValue
            
        } else {
            
        }
    }
    
    @IBAction func switchClicked(_ sender: Any) {
        
        if (onOffSwitch.isOn) {
            guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else {
                    return
            }
            
            let managedContext =
                appDelegate.persistentContainer.viewContext
            
            // is in groups
            if (self.tableView.isEditing) {
                
                var brightnessValueText : Float = 0.0
                
                for newPeripheral in connectedPeripheralArray {
                    
                    for device in coreDataDevices {
                        if (newPeripheral.connectedPeripheral.identifier.uuidString == device.value(forKey: "uuid") as! String) {
                            let updateDevice = managedContext.object(with: device.objectID)
                            
                            // If it does not have a brightness value set, then put to 100 on switch on
                            let brightnessValue = updateDevice.value(forKey: "previousBrightness") as? String ?? "100"
                            
                            let setSliderValue = Float(updateDevice.value(forKey: "previousBrightness") as? String ?? "100.0")!
                                                        
                            let hex = String(format:"%2X", Int(setSliderValue))
                            
                            let trimmedString = hex.trimmingCharacters(in: .whitespaces)
                            
                            let data = trimmedString.hexadecimal()
                            
                            if (setSliderValue > brightnessValueText) {
                                brightnessValueText = setSliderValue
                                self.brightnessLabel.text = "\(Int(setSliderValue))%"
                                self.verticalStepSlider.value = brightnessValueText / 10
                            }
                            
                            newPeripheral.connectedPeripheral?.writeValue(data!, for: newPeripheral.connectedWriteCharacteristic, type: CBCharacteristicWriteType.withResponse)
                            
                            saveSwitchValue(uuidString: newPeripheral.connectedPeripheral.identifier.uuidString, brightnessInt: brightnessValue)
                        }
                    }
                }
                
            } else { // is not in groups
                
                for device in coreDataDevices {
                    if (connectedPeripheral.identifier.uuidString == device.value(forKey: "uuid") as! String) {
                        
                        let updateDevice = managedContext.object(with: device.objectID)
                        
                        // If it does not have a brightness value set, then put to 100 on switch on
                        let brightnessValue = updateDevice.value(forKey: "previousBrightness") as? String ?? "100"
                        
                        let setSliderValue = Float(updateDevice.value(forKey: "previousBrightness") as? String ?? "100.0")!
                        
                        self.verticalStepSlider.value = setSliderValue / 10
                        
                        let hex = String(format:"%2X", Int(setSliderValue))
                        
                        let trimmedString = hex.trimmingCharacters(in: .whitespaces)
                        
                        let data = trimmedString.hexadecimal()
                        
                        self.brightnessLabel.text = "\(Int(setSliderValue))%"
                        
                        connectedPeripheral?.writeValue(data!, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
                        
                        saveSwitchValue(uuidString: connectedPeripheral.identifier.uuidString, brightnessInt: brightnessValue)
                    }
                }
            }
        } else {
            self.verticalStepSlider.value = self.verticalStepSlider.minimumValue
            self.brightnessLabel.text = "0%"
            
            if (self.tableView.isEditing) {
                
                for newPeripheral in connectedPeripheralArray {
                    let hex = String(format:"%2X", 0)
                    
                    let trimmedString = hex.trimmingCharacters(in: .whitespaces)
                    
                    let data = trimmedString.hexadecimal()
                    
                    newPeripheral.connectedPeripheral?.writeValue(data!, for: newPeripheral.connectedWriteCharacteristic, type: CBCharacteristicWriteType.withResponse)
                    
                    saveSwitchValue(uuidString: newPeripheral.connectedPeripheral.identifier.uuidString, brightnessInt: "0")
                }
                
            } else {
                
                let hex = String(format:"%2X", 0)
                
                let trimmedString = hex.trimmingCharacters(in: .whitespaces)
                
                let data = trimmedString.hexadecimal()
                
                connectedPeripheral?.writeValue(data!, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
                
                saveSwitchValue(uuidString: connectedPeripheral.identifier.uuidString, brightnessInt: "0")
            }
        }
    }
    
    /**
     * Writing to the bluetooth module
     */
    func writeBLEData(_ value: Int) {
        
        let hex = String(format:"%2X", value)
        
        let trimmedString = hex.trimmingCharacters(in: .whitespaces)
        
        let data = trimmedString.hexadecimal()
        
        self.brightnessLabel.text = "\(value)%"
        
        if (self.tableView.isEditing) {
            for newPeripheral in connectedPeripheralArray {
                save(uuidString: newPeripheral.connectedPeripheral.identifier.uuidString, nameString: newPeripheral.connectedPeripheral.name!, brightnessInt: String(value))

                newPeripheral.connectedPeripheral.writeValue(data!, for: newPeripheral.connectedWriteCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
        } else {
            
            save(uuidString: connectedPeripheral.identifier.uuidString, nameString: connectedPeripheral.name!, brightnessInt: String(value))
            
            connectedPeripheral?.writeValue(data!, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
    }
    
    func writeToSwitchData(_ value: Int) {
        
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
                    
                    self.popUpView.transform = .identity
                    self.popUpView.slideOut(to: .bottom)
                    
                    UIView.animate(withDuration: 0.15, animations: {
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

                self.brightnessLabel.text = "0%"
                
                var brightnessTextValue: Float = 0.0
                
                for connectedPeripheralObject in connectedPeripheralArray {
                    for device in coreDataDevices {
                        if (connectedPeripheralObject.connectedPeripheral.identifier.uuidString == device.value(forKey: "uuid") as! String) {
                            let temp: Float = Float(device.value(forKey: "brightnessValue") as? String ?? "100.0")!

                            if (temp > brightnessTextValue) {
                                brightnessTextValue = temp
                                
                                self.brightnessLabel.text = "\(brightnessTextValue)%"
                                self.verticalStepSlider.value = brightnessTextValue / 10
                            }
                        }
                    }
                }

                self.popUpView.transform = .identity
                self.popUpView.slideIn(from: .bottom)

                UIView.animate(withDuration: 0.15, animations: {
                    self.backgroundView.alpha = 0.5
                    self.navigationController?.navigationBar.isUserInteractionEnabled = false
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
    
    /**************************************************************************************/
    /**************************************************************************************/
    
    // Bluetooth scanning and refreshing functions
    
    // function to show the side menu
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
        self.peripheralNames.removeAll()
        self.tableView.reloadData()
        for peripheral in connectedPeripheralArray {
            centralManager.cancelPeripheralConnection(peripheral.connectedPeripheral)
            
            let index = connectedPeripheralArray.index(where: {$0.connectedPeripheral.identifier.uuidString == peripheral.connectedPeripheral.identifier.uuidString})
            self.connectedPeripheralArray.remove(at: index!)
        }
        
        centralManager.scanForPeripherals(withServices: [CBUUID(string: DISCOVERY_UUID)], options: nil)
        Timer.scheduledTimer(timeInterval: 2.5, target: self, selector: #selector(DiscoveryViewController.endRefresh), userInfo: nil, repeats: false)
    }
    
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
    
    /**************************************************************************************/
    /**************************************************************************************/
    
    // Bluetooth peripheral functions
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
        
        // If the user did NOT select a group of devices
        if (!self.tableView.isEditing) {
            
            self.onOffSwitch.isEnabled = true
            self.onOffSwitch.isHidden = false
            
            self.popUpView.transform = .identity
            self.popUpView.slideIn(from: .bottom)
            
            UIView.animate(withDuration: 0.15, animations: {
                self.backgroundView.alpha = 0.5
                self.navigationController?.navigationBar.isUserInteractionEnabled = false
            })
            
            
            self.tableView.isUserInteractionEnabled = false
            
            connectedPeripheral.delegate = self
            connectedPeripheral.discoverServices(nil)
            
            self.connectedLabel.text = "Connected to: \(deviceNameString)"
            
            self.verticalStepSlider.value = verticalStepSlider.minimumValue
            self.brightnessLabel.text = "0%"
            self.onOffSwitch.isOn = false
            
            for device in coreDataDevices {
                if (connectedPeripheral.identifier.uuidString == device.value(forKey: "uuid") as! String) {
                    let temp: Float = Float(device.value(forKey: "brightnessValue") as? String ?? "100.0")!
                    
                    if (temp > 0.0) {
                        self.verticalStepSlider.value = temp / 10
                        self.brightnessLabel.text = "\(temp)%"
                        self.onOffSwitch.isOn = true
                    } else {
                        self.verticalStepSlider.value = verticalStepSlider.minimumValue
                        self.brightnessLabel.text = "0%"
                        self.onOffSwitch.isOn = false
                    }
                }
            }
            
        } else { // User selected a group of devices
            
            self.onOffSwitch.isEnabled = true
            self.onOffSwitch.isHidden = false
            
            // Setting the value to zero initially for groups
            self.verticalStepSlider.value = self.verticalStepSlider.minimumValue
            
            self.connectedLabel.text = "Connected to: Group"
            peripheral.delegate = self
            peripheral.discoverServices(nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        let alertController = UIAlertController(title: "Error Connecting", message: error?.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel) {
            (result : UIAlertAction) -> Void in
            
            self.powerTurnedOff()
        }
        
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?){
       
        if (error != nil) {
            let alertController = UIAlertController(title: "Error Disconnecting", message: error?.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
            let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel) {
                (result : UIAlertAction) -> Void in
                
                self.powerTurnedOff()
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
            
            self.connectedLabel.text = ""
            
            self.popUpView.transform = .identity
            self.popUpView.slideOut(to: .bottom)
            
            UIView.animate(withDuration: 0.15, animations: {
                self.backgroundView.alpha = 0.0
                self.navigationController?.navigationBar.isUserInteractionEnabled = true
            })
            
            self.tableView.isUserInteractionEnabled = true
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            
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
                
                if (self.tableView.isEditing) {
                    let newPeripheral: Peripherals = Peripherals()
                    newPeripheral.connectedPeripheral = peripheral
                    newPeripheral.connectedWriteCharacteristic = aCharacteristic
                    connectedPeripheralArray.append(newPeripheral)
                }
            }
        }
    }
    
    /**************************************************************************************/
    /**************************************************************************************/
    
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
    
    /**************************************************************************************/
    /**************************************************************************************/

    func saveSwitchValue(uuidString: String, brightnessInt: String) {
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
                let previousValue = updateDevice.value(forKey: "brightnessValue")
                
                updateDevice.setValue(previousValue, forKey: "previousBrightness")
                updateDevice.setValue(brightnessInt, forKey: "brightnessValue")
                
                do {
                    try managedContext.save()
                } catch let error as NSError {
                    print("Could not save. \(error), \(error.userInfo)")
                }
                
                return
            }
        }
    }
    // Core Data Functions
    // TODO: add group name to this
    func save(uuidString: String, nameString: String, brightnessInt: String) {
        
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
                let previousValue = updateDevice.value(forKey: "brightnessValue")
                
                updateDevice.setValue(previousValue, forKey: "previousBrightness")
                updateDevice.setValue(brightnessInt, forKey: "brightnessValue")
                
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
        addDevice.setValue(brightnessInt, forKey: "brightnessValue")
        
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
    
    /**************************************************************************************/
    /**************************************************************************************/
    /**
     * Tableview functions
     */
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripheralNames.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        deviceUuidString = ""
        deviceNameString = ""
        
        if (!self.tableView.isEditing) {
            self.tableView.deselectRow(at: indexPath, animated: true)
            deviceNameString = (self.tableView.cellForRow(at: indexPath)?.textLabel?.text)!
            // TODO: switching this label to show group name instead of uuid
            deviceUuidString = (self.tableView.cellForRow(at: indexPath)?.detailTextLabel?.text)!
        }
        
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
        if (self.tableView.isEditing) {
            
            let index = connectedPeripheralArray.index(where: {$0.connectedPeripheral.identifier.uuidString == peripheralNames[indexPath.row].uuid})
            self.connectedPeripheralArray.remove(at: index!)
            
            
            for peripheral in peripherals {
                
                if (peripheral.identifier.uuidString == peripheralNames[indexPath.row].uuid) {
                    connectedPeripheral = peripheral
                    centralManager.cancelPeripheralConnection(connectedPeripheral)
                    return
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        // Configure the cell...
    
        let peripheral = peripheralNames[indexPath.row]
        
        cell.textLabel?.text = peripheral.name
        cell.detailTextLabel?.text = peripheral.uuid
        
        return cell
    }
}
extension String {
    
    func hexadecimal() -> Data? {
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

