import Foundation

struct DecodedVIN {
    let wmi: String
    let wmiDescription: String
    let model: String
    let bodyType: String
    let restraintSystem: String
    let fuelType: String
    let driveUnit: String
    let year: String
    let plant: String
    let serialNumber: String
}

enum TeslaVINDecoder {
    
    static let wmiMap: [String: String] = [
        "5YJ": "Tesla, Inc. Passenger Car (Fremont/Austin, USA)",
        "7SA": "Tesla, Inc. Multipurpose Passenger Vehicle (Austin, USA)",
        "7G2": "Tesla, Inc. Truck (Reno, USA)",
        "LRW": "Tesla, Inc. (Shanghai, China)",
        "XP7": "Tesla, Inc. (Berlin, Germany)"
    ]
    
    static let modelMap: [String: String] = [
        "S": "Model S",
        "3": "Model 3",
        "X": "Model X",
        "Y": "Model Y",
        "C": "Cybertruck",
        "R": "Roadster",
        "T": "Semi"
    ]
    
    static let bodyTypeMap: [String: [String: String]] = [
        "S": ["A": "Hatchback 5-door, Left Hand Drive"],
        "3": [
            "E": "Sedan 4-door, Left Hand Drive",
            "F": "Sedan 4-door, Right Hand Drive"
        ],
        "X": ["C": "Class E MPV, 5-door, Left Hand Drive"],
        "Y": [
            "G": "Class D MPV, 5-door, Left Hand Drive",
            "H": "Class D MPV, 5-door, Right Hand Drive"
        ],
        "T": [
            "A": "Day Cab - Short",
            "B": "Day Cab - Long"
        ]
    ]
    
    static let restraintSystemMap: [String: [String: String]] = [
        "S": [
            "1": "Manual Type 2 Seatbelts with front airbags, PODS, side inflatable restraints, knee airbags"
        ],
        "3": [
            "1": "Type 2 Manual Seatbelts (FR, SR*3) with Front Airbags, Side Inflatable Restraints, Knee Airbags (FR)",
            "7": "Type 2 Manual Seatbelts (FR, SR*3) with Front Airbags, Side Inflatable Restraints"
        ],
        "X": [
            "A": "Type 2 seatbelts (FR, SR*3, TR*2) with front airbags, PODS, side/knee airbags",
            "B": "Type 2 seatbelts (FR, SR*2, TR*2) with front airbags, PODS, side/knee airbags",
            "D": "Type 2 seatbelts (FR, SR*3) with front airbags, PODS, side/knee airbags"
        ],
        "Y": [
            "A": "Type 2 manual seatbelts (FR, SR*3, TR*2) with front airbags, PODS, side inflatable restraints, knee airbags (FR)",
            "B": "Type 2 manual seatbelts (FR, SR*2, TR*2) with front airbags, PODS, side inflatable restraints, knee airbags (FR)",
            "C": "Type 2 manual seatbelts (FR, SR*3) with front airbags, PODS, side inflatable restraints",
            "D": "Type 2 manual seatbelts (FR, SR*3) with front airbags, PODS, side inflatable restraints, knee airbags (FR)"
        ]
    ]
    
    static let fuelTypeMap: [String: String] = [
        "E": "Li-Ion Battery",
        "F": "Lithium Iron Phosphate Battery"
    ]
    
    static let driveUnitMap: [String: [String: String]] = [
        "S": [
            "1": "Single Motor",
            "2": "Dual Motor",
            "3": "Performance – Dual Motor",
            "4": "Performance – Dual Motor",
            "5": "Dual Motor (P2)",
            "6": "Plaid (Tri-Motor, P2)",
            "C": "Base (Dual Motor)",
            "D": "Plaid (Tri-Motor)"
        ],
        "X": [
            "2": "Dual Motor",
            "4": "Performance – Dual Motor",
            "5": "Dual Motor (P2)",
            "6": "Plaid (Tri-Motor, P2)",
            "C": "Base (Dual Motor)",
            "D": "Plaid (Tri-Motor)"
        ],
        "3": [
            "A": "Single Motor – Standard",
            "B": "Dual Motor – Standard",
            "C": "Dual Motor – Performance",
            "F": "Long Range – AWD",
            "J": "Single Motor – Standard",
            "K": "Dual Motor – Standard",
            "R": "Long Range – RWD",
            "G": "Standard Range – RWD",
            "S": "Single Motor – Standard",
            "T": "Dual Motor – Performance"
        ],
        "Y": [
            "D": "Single Motor – Standard",
            "E": "Dual Motor – Standard",
            "F": "Dual Motor – Performance",
            "J": "Single Motor – Standard",
            "K": "Dual Motor – Standard",
            "L": "Dual Motor – Performance",
            "R": "Single Motor – Standard",
            "S": "Single Motor – Standard",
            "A": "Standard Range – RWD",
            "B": "Long Range – AWD",
            "C": "Performance – AWD",
            "G": "Standard Range – RWD",
            "H": "Long Range – RWD"
        ],
        "C": [
            "D": "Dual Motor",
            "E": "Tri Motor (Cyberbeast)"
        ],
        "T": [
            "B": "Dual Drive Rear Axle, Air Brakes"
        ]
    ]
    
    static let yearMap: [String: String] = [
        "E": "2014", "F": "2015", "G": "2016", "H": "2017",
        "J": "2018", "K": "2019", "L": "2020", "M": "2021",
        "N": "2022", "P": "2023", "R": "2024", "S": "2025",
        "T": "2026", "V": "2027"
    ]
    
    static let plantMap: [String: String] = [
        "F": "Fremont, CA, USA",
        "A": "Austin, TX, USA",
        "C": "Shanghai, China",
        "B": "Berlin, Germany",
        "P": "Palo Alto, CA, USA (Roadster)",
        "N": "Reno, NV, USA (Semi)"
    ]
    
    static func decode(vin rawVin: String) -> DecodedVIN? {
        let vin = rawVin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard vin.count == 17 else { return nil }
        
        let chars = Array(vin).map { String($0) }
        
        // 1. WMI (World Manufacturer Identifier) - Digits 1-3
        let wmiCode = chars[0...2].joined()
        let wmiDesc = wmiMap[wmiCode] ?? "Unknown Manufacturer (\(wmiCode))"
        
        // 2. Model - Digit 4
        let modelCode = chars[3]
        let modelDesc = modelMap[modelCode] ?? "Unknown Model (\(modelCode))"
        
        // 3. Body Type - Digit 5
        let bodyCode = chars[4]
        let bodyDesc = bodyTypeMap[modelCode]?[bodyCode] ?? "Unknown Body (\(bodyCode))"
        
        // 4. Restraint System - Digit 6
        let restraintCode = chars[5]
        let restraintDesc = restraintSystemMap[modelCode]?[restraintCode] ?? "Unknown System (\(restraintCode))"
        
        // 5. Fuel Type - Digit 7
        let fuelCode = chars[6]
        let fuelDesc = fuelTypeMap[fuelCode] ?? "Unknown Fuel (\(fuelCode))"
        
        // 6. Motor / Drive Unit - Digit 8
        let driveCode = chars[7]
        let driveDesc = driveUnitMap[modelCode]?[driveCode] ?? "Unknown Drive (\(driveCode))"
        
        // 7. Check Digit - Digit 9 (skip for parsing)
        
        // 8. Model Year - Digit 10
        let yearCode = chars[9]
        let yearDesc = yearMap[yearCode] ?? "Unknown Year (\(yearCode))"
        
        // 9. Plant - Digit 11
        let plantCode = chars[10]
        let plantDesc = plantMap[plantCode] ?? "Unknown Plant (\(plantCode))"
        
        // 10. Serial Number - Digits 12-17
        let serialNumber = chars[11...16].joined()
        
        return DecodedVIN(
            wmi: wmiCode,
            wmiDescription: wmiDesc,
            model: modelDesc,
            bodyType: bodyDesc,
            restraintSystem: restraintDesc,
            fuelType: fuelDesc,
            driveUnit: driveDesc,
            year: yearDesc,
            plant: plantDesc,
            serialNumber: serialNumber
        )
    }
}
