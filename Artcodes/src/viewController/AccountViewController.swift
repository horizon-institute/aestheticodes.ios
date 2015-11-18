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
import ArtcodesScanner

class AccountViewController: ExperienceTableViewController
{
    let account: Account
    
    init(account: Account)
    {
        self.account = account
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        self.account = LocalAccount()
        super.init(coder: aDecoder)
    }
	
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
	{
		NSLog("\(indexPath)")
		if let appDelegate = UIApplication.sharedApplication().delegate as? ArtcodeAppDelegate
		{
			appDelegate.navigationController.pushViewController(ExperienceEditViewController(experience: Experience(), account: account), animated: true)
		}

	}
	
    override func viewDidLoad()
	{
		super.viewDidLoad()
		
        screenName = "View Library"
		
        sorted = true
	}
	
	override func viewWillAppear(animated: Bool)
	{
		showProgress()
		account.loadLibrary { (experiences) -> Void in
			self.clear()
			self.addExperienceURIs(experiences, forGroup: "")
			self.tableView.reloadData()
			if let footer = NSBundle.mainBundle().loadNibNamed("AddExperienceView", owner: self, options: nil)[0] as? UIView
			{
				let tapRec = UITapGestureRecognizer()
				tapRec.addTarget(self, action: "addExperience")
				footer.addGestureRecognizer(tapRec)
				
				self.tableView.tableFooterView = footer
			}
			else
			{
				self.tableView.tableFooterView = nil
			}
		}
	}
	
	func addExperience()
	{
		if let appDelegate = UIApplication.sharedApplication().delegate as? ArtcodeAppDelegate
		{
			appDelegate.navigationController.pushViewController(ExperienceEditViewController(experience: Experience(), account: account), animated: true)
		}
	}
}