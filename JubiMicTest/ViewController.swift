//
//  ViewController.swift
//  JubiMicTest
//
//  Created by Jared Wheeler on 4/21/17.
//  Copyright © 2017 Jared Wheeler. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        DSPEngine.sharedInstance.prepare()
        DSPEngine.sharedInstance.resume()
    }
    
    
}

