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
import DrawerController

class SearchViewController: ExperienceCollectionViewController, UITextFieldDelegate
{
	let searchField = UITextField(frame: CGRect(x: 0, y: 0, width: 10000, height: 22))
	var timer = Timer()
	
    override init()
    {
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad()
	{
		super.viewDidLoad()
		
        screenName = "Search"

		errorIcon.image = UIImage(named: "ic_search_144pt")
		
		searchField.placeholder = "Search"
		searchField.backgroundColor = UIColor.clear
		searchField.borderStyle = .none
		searchField.textColor = UIColor.white
		searchField.textAlignment = .left
		searchField.delegate = self
		
		navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "ic_arrow_back_white"), style: .plain, target: self, action: #selector(SearchViewController.back))
		navigationItem.titleView = searchField
		
	}
	
	override func viewWillLayoutSubviews()
	{
		super.viewWillLayoutSubviews()
	}
	
	override func viewDidAppear(_ animated: Bool)
	{
		super.viewWillAppear(animated)
		collectionView.reloadData()
		searchField.becomeFirstResponder()
	}
	
	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
	{
		if timer.isValid
		{
			timer.invalidate()
		}
		if let searchText: NSString = searchField.text as! NSString
		{
			let searchTextAfterChanges = searchText.replacingCharacters(in: range, with: string)
			if searchTextAfterChanges.characters.count >= 3
			{
				timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(SearchViewController.search), userInfo: nil, repeats: false)
			}
		}
		return true
		
	}
	
	func search()
	{
		if let appDelegate = UIApplication.shared.delegate as? ArtcodeAppDelegate
		{
			if let searchText = searchField.text
			{
				errorMessage.text = "No results found for \(searchText)"
				progress += 1
				appDelegate.server.search(searchText) { (experiences) -> Void in
					self.progress -= 1
					self.setExperienceURIs(experiences)
				}				
			}
		}
	}
	
	func back()
	{
		navigationController?.popViewController(animated: true)
	}
	
	override func error(_ experience: String, error: NSError)
	{
		NSLog("Error loading %@: %@", "\(experience)", "\(error)")
	}
}
