//
//  DevicesMO+CoreDataProperties.swift
//  
//
//  Created by Adam Birdsall on 8/22/17.
//
//

import Foundation
import CoreData


extension DevicesMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DevicesMO> {
        return NSFetchRequest<DevicesMO>(entityName: "Devices")
    }

    @NSManaged public var name: String?
    @NSManaged public var uuid: String?
    @NSManaged public var groups: String?

}
