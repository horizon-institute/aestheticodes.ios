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

class NavigationMenuViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, GIDSignInUIDelegate
{
	let identifier = "NavigationMenuViewCell"
	
	let navigation: [String] = ["recommended", "starred"]
	let icons = ["recommended": "ic_photo_camera_18pt", "starred": "ic_star_18pt"]
	var drawerController: DrawerController!
	
	@IBOutlet weak var tableView: UITableView!
	
    init()
	{
		super.init(nibName:"NavigationMenuViewController", bundle:nil)
	}
	
	required init?(coder aDecoder: NSCoder)
	{
		super.init(coder: aDecoder)
	}
	
	override func viewDidLoad()
	{
		super.viewDidLoad()
		
		tableView.rowHeight = UITableViewAutomaticDimension
		tableView.estimatedRowHeight = 44.0
		
		let nibName = UINib(nibName: identifier, bundle:nil)
		tableView.registerNib(nibName, forCellReuseIdentifier: identifier)
		
		tableView.selectRowAtIndexPath(NSIndexPath(forItem: 0, inSection: 0), animated: false, scrollPosition: UITableViewScrollPosition.Top)
	}
	
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
	{
		if section == 0
		{
			return navigation.count
		}
		if let appDelegate = UIApplication.sharedApplication().delegate as? ArtcodeAppDelegate
		{
			if appDelegate.server.accounts.count > 1
			{
				return appDelegate.server.accounts.count
			}
			return appDelegate.server.accounts.count + 1
		}
		return 0
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
	{
		let cell :NavigationMenuViewCell = tableView.dequeueReusableCellWithIdentifier(identifier) as! NavigationMenuViewCell
		if indexPath.section == 0
		{
			let item = navigation[indexPath.item]
			let itemTitle = NSLocalizedString(item, tableName: nil, bundle: NSBundle.mainBundle(), value: item.capitalizedString, comment: "")
			
			cell.navigationTitle.text = itemTitle
			
			if let icon = icons[item]
			{
				cell.navigationIcon.image = UIImage(named: icon)
			}
		}
		else
		{
			if let appDelegate = UIApplication.sharedApplication().delegate as? ArtcodeAppDelegate
			{
				if indexPath.item >= appDelegate.server.accounts.count
				{
					cell.navigationTitle.text = "Add Account"
					cell.navigationIcon.image = UIImage(named: "ic_add_18pt")
				}
				else
				{
					let accounts =  appDelegate.server.accounts.keys.sort()
					if let account = appDelegate.server.accounts[accounts[indexPath.item]]
					{
						if account.id == "local"
						{
							cell.navigationIcon.image = UIImage(named: "ic_smartphone_18pt")
						}
						else
						{
							cell.navigationIcon.image = UIImage(named: "ic_cloud_18pt")
						}
						cell.navigationTitle.text = account.name
					}
				}
			}
		}
		return cell;
	}
	
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
	{
		if indexPath.section == 0
		{
			if indexPath.item == 0
			{
				drawerController.setCenterViewController(RecommendedViewController(), withCloseAnimation: true, completion: nil)
			}
			else if indexPath.item == 1
			{
				drawerController.setCenterViewController(StarredViewController(), withCloseAnimation: true, completion: nil)
			}
		}
		else if let appDelegate = UIApplication.sharedApplication().delegate as? ArtcodeAppDelegate
		{
			if indexPath.section == 1 && indexPath.item < appDelegate.server.accounts.count
			{
				// Create library view controller
				let accounts =  appDelegate.server.accounts.keys.sort()
				if let account = appDelegate.server.accounts[accounts[indexPath.item]]
				{
					drawerController.setCenterViewController(AccountViewController(account: account), withCloseAnimation: true, completion: nil)
				}
			}
			else if indexPath.section == 1 && indexPath.item >= appDelegate.server.accounts.count
			{
				GIDSignIn.sharedInstance().uiDelegate = self
				GIDSignIn.sharedInstance().signIn()
				// Add account
			}
		}
	}

	func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String?
	{
		if section == 0
		{
			return nil
		}
		else
		{
			return NSLocalizedString("libraries", tableName: nil, bundle: NSBundle.mainBundle(), value: "Libraries", comment: "")
		}
	}
	
	func numberOfSectionsInTableView(tableView: UITableView) -> Int
	{
		return 2
	}
}