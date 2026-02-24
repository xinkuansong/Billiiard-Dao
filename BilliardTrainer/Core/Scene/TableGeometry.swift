//
//  TableGeometry.swift
//  BilliardTrainer
//
//  程序化球台几何描述
//

import SceneKit

struct Pocket {
    let id: String
    let center: SCNVector3
    let radius: Float
    let isCorner: Bool
}

struct LinearCushionSegment {
    let start: SCNVector3
    let end: SCNVector3
    let normal: SCNVector3
}

struct CircularCushionSegment {
    let center: SCNVector3
    let radius: Float
    let startAngle: Float
    let endAngle: Float
    
    /// Check whether an angle (radians, measured from +X axis CCW in the XZ plane)
    /// falls within this arc segment's angular range.
    func isAngleInRange(_ angle: Float) -> Bool {
        let twoPi = Float.pi * 2
        var a = angle.truncatingRemainder(dividingBy: twoPi)
        if a < 0 { a += twoPi }
        
        var s = startAngle.truncatingRemainder(dividingBy: twoPi)
        if s < 0 { s += twoPi }
        var e = endAngle.truncatingRemainder(dividingBy: twoPi)
        if e < 0 { e += twoPi }
        
        let eps: Float = 0.01
        if s <= e {
            return a >= s - eps && a <= e + eps
        } else {
            return a >= s - eps || a <= e + eps
        }
    }
    
    /// Outward-pointing normal at the given ball position (from arc center toward ball).
    func normal(at ballPosition: SCNVector3) -> SCNVector3 {
        let dx = ballPosition.x - center.x
        let dz = ballPosition.z - center.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 1e-8 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(dx / len, 0, dz / len)
    }
    
    /// Angle (radians) from arc center to the given point in the XZ plane.
    func angle(to point: SCNVector3) -> Float {
        let dx = point.x - center.x
        let dz = point.z - center.z
        var a = atan2f(dz, dx)
        if a < 0 { a += Float.pi * 2 }
        return a
    }
}

struct TableGeometry {
    var linearCushions: [LinearCushionSegment]
    var circularCushions: [CircularCushionSegment]
    var pockets: [Pocket]
    
    static func chineseEightBall() -> TableGeometry {
        let y = TablePhysics.height
        
        // Geometry interpretation: outer_size (innerLength/innerWidth) represents the playfield
        // Pocket centers are located outside the playfield by their radius
        // Table centered at origin
        
        // Rail half-dimensions: playfield half-size
        let railHalfLength = TablePhysics.innerLength / 2  // 1.27m (playfield half-length)
        let railHalfWidth = TablePhysics.innerWidth / 2    // 0.635m (playfield half-width)
        
        // Pocket center offsets (from playfield center to pocket center)
        let cornerPocketCenterOffsetX = TablePhysics.cornerPocketCenterOffsetX  // 1.312m
        let cornerPocketCenterOffsetZ = TablePhysics.cornerPocketCenterOffsetZ   // 0.677m
        let sidePocketCenterOffsetZ = TablePhysics.sidePocketCenterOffsetZ      // 0.688m
        
        let cornerPocketRadius = TablePhysics.cornerPocketRadius  // 42mm
        let sidePocketRadius = TablePhysics.sidePocketRadius      // 43mm
        let cornerFilletRadius = TablePhysics.cornerPocketFilletRadius  // 105mm
        let sideFilletRadius = TablePhysics.sidePocketFilletRadius       // 30mm
        let sideNotchHalf = TablePhysics.sidePocketNotchWidth / 2        // 5mm
        
        // Define pocket centers using offset constants
        let pockets: [Pocket] = [
            // Bottom-left corner (negative X, negative Z)
            Pocket(id: "pocket_0", center: SCNVector3(-cornerPocketCenterOffsetX, y, -cornerPocketCenterOffsetZ), radius: cornerPocketRadius, isCorner: true),
            // Top-left corner (negative X, positive Z)
            Pocket(id: "pocket_1", center: SCNVector3(-cornerPocketCenterOffsetX, y, cornerPocketCenterOffsetZ), radius: cornerPocketRadius, isCorner: true),
            // Bottom-right corner (positive X, negative Z)
            Pocket(id: "pocket_2", center: SCNVector3(cornerPocketCenterOffsetX, y, -cornerPocketCenterOffsetZ), radius: cornerPocketRadius, isCorner: true),
            // Top-right corner (positive X, positive Z)
            Pocket(id: "pocket_3", center: SCNVector3(cornerPocketCenterOffsetX, y, cornerPocketCenterOffsetZ), radius: cornerPocketRadius, isCorner: true),
            // Bottom side pocket (center, negative Z)
            Pocket(id: "pocket_4", center: SCNVector3(0, y, -sidePocketCenterOffsetZ), radius: sidePocketRadius, isCorner: false),
            // Top side pocket (center, positive Z)
            Pocket(id: "pocket_5", center: SCNVector3(0, y, sidePocketCenterOffsetZ), radius: sidePocketRadius, isCorner: false)
        ]
        
        // Build linear cushion segments
        // Long rails (top and bottom, along X-axis) are split by corner and side pockets with 10mm notch
        // Short rails (left and right, along Z-axis) are split by corner pockets only
        // Linear cushions are positioned at playfield boundaries (railHalfLength/railHalfWidth)
        
        var linearCushions: [LinearCushionSegment] = []
        
        // Top long rail (positive Z): two segments split by side pocket with notch
        // Left segment: from left corner fillet to left side of side pocket notch
        // Linear segment ends where it meets the corner fillet (offset by fillet radius from playfield corner)
        let topRailLeftStartX = -railHalfLength + cornerFilletRadius
        let topRailLeftEndX = -sideNotchHalf - sideFilletRadius
        linearCushions.append(LinearCushionSegment(
            start: SCNVector3(topRailLeftStartX, y, railHalfWidth),
            end: SCNVector3(topRailLeftEndX, y, railHalfWidth),
            normal: SCNVector3(0, 0, -1)
        ))
        
        // Right segment: from right side of side pocket notch to right corner fillet
        let topRailRightStartX = sideNotchHalf + sideFilletRadius
        let topRailRightEndX = railHalfLength - cornerFilletRadius
        linearCushions.append(LinearCushionSegment(
            start: SCNVector3(topRailRightStartX, y, railHalfWidth),
            end: SCNVector3(topRailRightEndX, y, railHalfWidth),
            normal: SCNVector3(0, 0, -1)
        ))
        
        // Bottom long rail (negative Z): two segments split by side pocket with notch
        let bottomRailLeftStartX = -railHalfLength + cornerFilletRadius
        let bottomRailLeftEndX = -sideNotchHalf - sideFilletRadius
        linearCushions.append(LinearCushionSegment(
            start: SCNVector3(bottomRailLeftStartX, y, -railHalfWidth),
            end: SCNVector3(bottomRailLeftEndX, y, -railHalfWidth),
            normal: SCNVector3(0, 0, 1)
        ))
        
        let bottomRailRightStartX = sideNotchHalf + sideFilletRadius
        let bottomRailRightEndX = railHalfLength - cornerFilletRadius
        linearCushions.append(LinearCushionSegment(
            start: SCNVector3(bottomRailRightStartX, y, -railHalfWidth),
            end: SCNVector3(bottomRailRightEndX, y, -railHalfWidth),
            normal: SCNVector3(0, 0, 1)
        ))
        
        // Left short rail (negative X): one continuous segment between corner pockets
        // Segment spans from bottom corner fillet to top corner fillet
        let leftRailStartZ = -railHalfWidth + cornerFilletRadius
        let leftRailEndZ = railHalfWidth - cornerFilletRadius
        linearCushions.append(LinearCushionSegment(
            start: SCNVector3(-railHalfLength, y, leftRailStartZ),
            end: SCNVector3(-railHalfLength, y, leftRailEndZ),
            normal: SCNVector3(1, 0, 0)
        ))
        
        // Right short rail (positive X): one continuous segment between corner pockets
        let rightRailStartZ = -railHalfWidth + cornerFilletRadius
        let rightRailEndZ = railHalfWidth - cornerFilletRadius
        linearCushions.append(LinearCushionSegment(
            start: SCNVector3(railHalfLength, y, rightRailStartZ),
            end: SCNVector3(railHalfLength, y, rightRailEndZ),
            normal: SCNVector3(-1, 0, 0)
        ))
        
        // Build circular cushion segments for pocket fillets
        var circularCushions: [CircularCushionSegment] = []
        
        // Corner pocket fillets: each corner has TWO jaw arcs with a gap for the pocket opening.
        // Gap half-angle derived from pocket diameter vs fillet radius:
        //   chord = 2 * R_fillet * sin(gapHalf) = pocketDiameter
        //   gapHalf = asin(pocketRadius / filletRadius)
        let cornerGapHalf = asinf(min(cornerPocketRadius / cornerFilletRadius, 1.0))
        
        for pocket in pockets where pocket.isCorner {
            let pocketX = pocket.center.x
            let pocketZ = pocket.center.z
            
            let filletCenterX = (pocketX > 0 ? railHalfLength : -railHalfLength) - (pocketX > 0 ? cornerFilletRadius : -cornerFilletRadius)
            let filletCenterZ = (pocketZ > 0 ? railHalfWidth : -railHalfWidth) - (pocketZ > 0 ? cornerFilletRadius : -cornerFilletRadius)
            let filletCenter = SCNVector3(filletCenterX, y, filletCenterZ)
            
            // Quarter-circle base angles (the full 90° range before splitting)
            var qStart: Float = 0
            var qEnd: Float = Float.pi / 2
            
            if pocketX < 0 && pocketZ < 0 {
                qStart = Float.pi;       qEnd = 3 * Float.pi / 2
            } else if pocketX < 0 && pocketZ > 0 {
                qStart = Float.pi / 2;   qEnd = Float.pi
            } else if pocketX > 0 && pocketZ < 0 {
                qStart = 3 * Float.pi / 2; qEnd = 2 * Float.pi
            }
            
            // Gap center = midpoint of the quarter circle = direction toward pocket center
            let gapCenter = (qStart + qEnd) / 2
            
            // Jaw 1: from rail junction to gap start
            circularCushions.append(CircularCushionSegment(
                center: filletCenter,
                radius: cornerFilletRadius,
                startAngle: qStart,
                endAngle: gapCenter - cornerGapHalf
            ))
            // Jaw 2: from gap end to rail junction
            circularCushions.append(CircularCushionSegment(
                center: filletCenter,
                radius: cornerFilletRadius,
                startAngle: gapCenter + cornerGapHalf,
                endAngle: qEnd
            ))
        }
        
        // Side pocket fillets: R30mm semicircles on each side of the 10mm notch
        // Fillet centers are based on notch position and playfield width
        for pocket in pockets where !pocket.isCorner {
            let pocketZ = pocket.center.z
            let notchHalf = sideNotchHalf
            
            // Left fillet (negative X side): connects left rail segment to pocket opening
            // Fillet center: x = -(sideNotchHalf + sideFilletRadius), z = ±railHalfWidth
            let leftFilletCenterX = -notchHalf - sideFilletRadius
            let leftFilletCenterZ = pocketZ > 0 ? railHalfWidth : -railHalfWidth
            let leftFilletCenter = SCNVector3(leftFilletCenterX, y, leftFilletCenterZ)
            
            // Fillet arc: from rail (pointing toward pocket) to pocket opening
            // For top side pocket: arc from 0° (pointing right) to 90° (pointing down into pocket)
            // For bottom side pocket: arc from 180° (pointing left) to 270° (pointing up into pocket)
            let leftStartAngle: Float = pocketZ > 0 ? 0 : Float.pi
            let leftEndAngle: Float = pocketZ > 0 ? Float.pi / 2 : 3 * Float.pi / 2
            
            circularCushions.append(CircularCushionSegment(
                center: leftFilletCenter,
                radius: sideFilletRadius,
                startAngle: leftStartAngle,
                endAngle: leftEndAngle
            ))
            
            // Right fillet (positive X side): connects right rail segment to pocket opening
            // Fillet center: x = +(sideNotchHalf + sideFilletRadius), z = ±railHalfWidth
            let rightFilletCenterX = notchHalf + sideFilletRadius
            let rightFilletCenterZ = pocketZ > 0 ? railHalfWidth : -railHalfWidth
            let rightFilletCenter = SCNVector3(rightFilletCenterX, y, rightFilletCenterZ)
            
            // Fillet arc: from rail (pointing toward pocket) to pocket opening
            let rightStartAngle: Float = pocketZ > 0 ? Float.pi / 2 : 3 * Float.pi / 2
            let rightEndAngle: Float = pocketZ > 0 ? Float.pi : 2 * Float.pi
            
            circularCushions.append(CircularCushionSegment(
                center: rightFilletCenter,
                radius: sideFilletRadius,
                startAngle: rightStartAngle,
                endAngle: rightEndAngle
            ))
        }
        
        return TableGeometry(linearCushions: linearCushions, circularCushions: circularCushions, pockets: pockets)
    }
}
