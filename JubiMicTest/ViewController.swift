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
 
    //The UIControl update stuff is based on UIView tags set in IB.
    //This is obviously non-production, and would be handled by a more
    //robust UI messaging architecture in a real implementation
    
    @IBAction func updateGainBandSlider(_ sender: UISlider?) {
        let i = sender!.tag
        //Only update from the left channel sliders
        if i < 30 {
            DSPEngine.sharedInstance.updateGain(forBand: i-10, onChannel: 0, withValue: Float32(sender!.value))
        }
        let bandLabel : UILabel? = self.view.viewWithTag(sender!.tag + 10) as? UILabel
        bandLabel?.text = String(format: "%1.0f", sender!.value)
    }
    
    @IBAction func resetEQBands(_ sender: Any?) {
        for i in 0..<10 {
            //reset the band gain in the DSPEngine
            DSPEngine.sharedInstance.updateGain(forBand: i, onChannel: 0, withValue: 0)
            //reset the left UI Control
            let bandSliderLeft : UISlider? = self.view.viewWithTag(i+10) as? UISlider
            bandSliderLeft?.value = 0
            //reset the right UI Control
            let bandSliderRight : UISlider? = self.view.viewWithTag(i+30) as? UISlider
            bandSliderRight?.value = 0
            //reset the left value field
            let bandLabelLeft : UILabel? = self.view.viewWithTag(i+20) as? UILabel
            bandLabelLeft?.text = "0"
            //reset the right value field
            let bandLabelRight : UILabel? = self.view.viewWithTag(i+40) as? UILabel
            bandLabelRight?.text = "0"
        }
    }
}

