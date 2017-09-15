//
//  MenuTableViewController.swift
//  Smart Dimmer
//
//  Created by Adam Birdsall on 8/3/17.
//  Copyright © 2017 Adam Birdsall. All rights reserved.
//

import UIKit

class MenuTableViewController: UITableViewController, UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewWillLayoutSubviews() {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func closeMenu(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }


}
