//
//  Peripherals.swift
//  Smart Dimmer
//
//  Created by Adam Birdsall on 8/27/17.
//  Copyright © 2017 Adam Birdsall. All rights reserved.
//

import Foundation
import CoreBluetooth

class Peripherals {
    var connectedPeripheral: CBPeripheral!
    var connectedWriteCharacteristic: CBCharacteristic!
}
