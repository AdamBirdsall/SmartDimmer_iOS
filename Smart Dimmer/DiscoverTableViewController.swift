//
//  DiscoverTableViewController.swift
//  Smart Dimmer
//
//  Created by Adam Birdsall on 6/28/17.
//  Copyright © 2017 Adam Birdsall. All rights reserved.
//

import UIKit
import CoreBluetooth

class DiscoverTableViewController: UITableViewController, CBCentralManagerDelegate, CBPeripheralDelegate  {
    
    var centralManager: CBCentralManager!
    var peripherals = Array<CBPeripheral>()
    var connectedPeripheral: CBPeripheral!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Make BLE Connection
        
        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(DiscoverTableViewController.scanForDevice), userInfo: nil, repeats: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Close BLE Connection
    }
    
    
    // Central Manager Delegates
    /*********************************************/
    func scanForDevice() {
        
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        peripherals.append(peripheral)
        self.tableView.reloadData()
        
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Central manager did update state")
        
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        // Configure the cell...
        
        let peripheral = peripherals[indexPath.row]
        cell.textLabel?.text = peripheral.name

        return cell
    }
 
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "connectToDevice") {
            
            centralManager.stopScan()
            
            let destination = segue.destination as! ViewController
            
            let indexPath = self.tableView.indexPathForSelectedRow!
            
            destination.connectedPeripheral = peripherals[indexPath.row]
        }
    }

}
