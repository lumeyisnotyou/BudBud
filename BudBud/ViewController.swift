//
//  ViewController.swift
//  BudBud
//
//  Created by lumey on 4/12/23.
//

import UIKit
import CoreBluetooth
import SDWebImage
let fastPairUUID = CBUUID(string: "0xFE2C")
let fastPairModelUUID = CBUUID(string: "FE2C1233-8366-4814-8EB0-01DE32100BEA")
extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is on")
            centralManager.scanForPeripherals(withServices: [fastPairUUID], options: nil)
        case .poweredOff:
            print("Bluetooth is off")
        case .resetting:
            print("Bluetooth is resetting")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unknown:
            print("Bluetooth is unknown")
        case .unsupported:
            print("Bluetooth is unsupported")
        default:
            print("Bluetooth is default")
        }
    }
}

class ViewController: UIViewController {
    var centralManager: CBCentralManager!
    var FPPeripheral: CBPeripheral!
    @IBOutlet weak var ProductName: UILabel!
    @IBOutlet weak var ProductInfo: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        // Do any additional setup after loading the view.
        
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered \(peripheral.name ?? "unknown") at \(RSSI)")
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
        FPPeripheral = peripheral
        FPPeripheral.delegate = self
        
        
        
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "unknown")")
        FPPeripheral.discoverServices(nil)
        
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "unknown")")
        
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "unknown")")
        // Rescan for peripherals
        centralManager.scanForPeripherals(withServices: [fastPairUUID], options: nil)
    }
    
    
}

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            print(service)
            peripheral.discoverCharacteristics(nil, for: service)
            
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print(characteristic)
            if characteristic.properties.contains(.read) {
                print("\(characteristic.uuid): properties contains .read")
                peripheral.readValue(for: characteristic)
                
                // Find the fast pair model ID characteristic
                if characteristic.uuid == CBUUID(string: "0x2A24") {
                    // Read the value of the characteristic
                    peripheral.readValue(for: characteristic)
                    print("Read value for \(characteristic.uuid): \(characteristic.value)")
                    
                }
            }
            if characteristic.properties.contains(.notify) {
                print("\(characteristic.uuid): properties contains .notify")
            }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        switch characteristic.uuid {
        case fastPairModelUUID:
            let modelID = getModelID(from: characteristic.value!)
            print("Model ID: \(modelID)")
            // Send a GET request to the server to get the model name
            
            let task = Task {
                let productDetails = await getProductDetailsFromAPI(modelID: modelID)
                print("Product Details: \(productDetails)")
                // Declare some product details, all device info is stored in a dictionary under the key "device"
                let device = productDetails["device"] as! Dictionary<String, Any>
                let productName = device["name"] as! String
                let productImageURL = device["imageUrl"] as! String
                let deviceType = device["deviceType"] as! String
                var TWImages: Dictionary<String, Any>
                var caseImageURL: String
                var earbudLImageURL: String
                var earbudRImageURL: String
                // If the device is true wireless, get the case and buds images
                // Make sure no images are already on the screen
                for subview in self.ProductInfo.subviews {
                    subview.removeFromSuperview()
                }
                // Set the name of the product label to the product name
                self.ProductName.text = productName
                if deviceType == "TRUE_WIRELESS_HEADPHONES" {
                    TWImages = device["trueWirelessImages"] as! Dictionary<String, Any>
                    caseImageURL = TWImages["caseUrl"] as! String
                    earbudLImageURL = TWImages["leftBudUrl"] as! String
                    earbudRImageURL = TWImages["rightBudUrl"] as! String
                    print(caseImageURL,earbudLImageURL,earbudRImageURL)
                    // Create the images
                    let caseImage = UIImageView()
                    let earbudLImage = UIImageView()
                    let earbudRImage = UIImageView()
                    // Download the images
                    caseImage.sd_setImage(with: URL(string: caseImageURL), completed: nil)
                    earbudLImage.sd_setImage(with: URL(string: earbudLImageURL), completed: nil)
                    earbudRImage.sd_setImage(with: URL(string: earbudRImageURL), completed: nil)
                    // Position the images to align to the center of the view at a size of 200x200
                    caseImage.frame = CGRect(x: self.ProductInfo.frame.width/2 - 100, y: self.ProductInfo.frame.height/2 - 100, width: 200, height: 200)
                    earbudLImage.frame = CGRect(x: self.ProductInfo.frame.width/2 - 210, y: 100, width: 150, height: 150)
                    earbudRImage.frame = CGRect(x: self.ProductInfo.frame.width/2 + 65, y: 100, width: 150, height: 150)

                    

                    // Add the images to the product info view
                    self.ProductInfo.addSubview(caseImage)
                    self.ProductInfo.addSubview(earbudLImage)
                    self.ProductInfo.addSubview(earbudRImage)
                } else {
                    // Create the image
                    let productImage = UIImageView()
                    // Download the image
                    productImage.sd_setImage(with: URL(string: productImageURL), completed: nil)
                    // Add the image to the product info view
                    self.ProductInfo.addSubview(productImage)

                }
                // Update the UI with the product details by creating new UI elements and adding them to the product info view
                
                // If the device is true wireless, add the case and buds, else, just use the device image
                
                // Add the product name label to the product info view
            }
        default:
            print("Unhandled Characteristic UUID: \(characteristic.uuid)")
        }
    }
    // The model ID is a 24-bit integer, so we need to interpret the data as such
    func getModelID(from data: Data) -> Int {
        var modelID: Int = 0
        let modelIDData = data.subdata(in: 0..<3)
        (modelIDData as NSData).getBytes(&modelID, length: MemoryLayout<Int>.size)
        return modelID
    }
    func getProductDetailsFromAPI(modelID: Int) async -> Dictionary <String, Any>{
        var APIurl = "https://nearbydevices-pa.googleapis.com/v1/device/"
            APIurl += String(modelID)
            let APIkey = "AIzaSyBv7ZrOlX5oIJLVQrZh-WkZFKm5L6FlStQ"
            let mode = "MODE_RELEASE"
            APIurl += "?key="
            APIurl += APIkey
            APIurl += "&mode="
            APIurl += mode
            var request = URLRequest(url: URL(string: APIurl)!)
            request.httpMethod = "GET"
            // Send the request and return the JSON
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                print(json)
                return json as! Dictionary<String, Any>
            } catch {
                print(error)
                return ["error": error]
            }



    }
}
