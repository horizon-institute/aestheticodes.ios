/*
 * Artcodes recognises a different marker scheme that allows the
 * creation of aesthetically pleasing, even beautiful, codes.
 * Copyright (C) 2013-2015  The University of Nottingham
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU Affero General Public License as published
 *     by the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU Affero General Public License for more details.
 *
 *     You should have received a copy of the GNU Affero General Public License
 *     along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation

@objc
public class DetectionSettings: NSObject
{
	public let minRegions: Int
	public let maxRegions: Int
	public let maxRegionValue: Int
	public let checksum: Int
	public let validCodes: Set<String>
	public var detected = false
	public var handler: (markers: [String]) -> Void = { arg in }

	public var displayText = 0
	public var displayOutline = 0
	public var displayThreshold = 0
	
	public init(experience: Experience)
	{
		var minRegions = 20
		var maxRegions = 0
		var maxRegionValue = 0
		var codeSet = Set<String>()
		var checksum = 0

		for action in experience.actions
		{

			for code in action.codes
			{
				let codeArr = code.characters.split{$0 == ":"}
				minRegions = min(minRegions, codeArr.count)
				maxRegions = max(maxRegions, codeArr.count)
				
				var total = 0
				for codeValue in codeArr
				{
					if let codeNumber = Int(String(codeValue))
					{
						maxRegionValue = max(maxRegionValue, codeNumber)
						total = total + codeNumber
					}
				}
				
				if(total > 0)
				{
					checksum = DetectionSettings.gcd(checksum, b: total)
				}
				codeSet.insert(code)
			}
		}
		
		NSLog("Experience settings = \(minRegions) - \(maxRegions) Regions, < \(maxRegionValue), Checksum \(checksum)")
		self.maxRegions = maxRegions
		self.minRegions = minRegions
		self.maxRegionValue = maxRegionValue
		self.checksum = checksum
	
		self.validCodes = Set(codeSet)
	}
	
	class func gcd(a: Int, b: Int) -> Int
	{
		if(b == 0)
		{
			return a
		}
		else
		{
			return gcd(b, b: a % b)
		}
	}
}