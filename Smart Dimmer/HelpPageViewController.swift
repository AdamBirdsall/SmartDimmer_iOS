//
//  HelpPageViewController.swift
//  Smart Dimmer
//
//  Created by Adam Birdsall on 9/27/17.
//  Copyright © 2017 Adam Birdsall. All rights reserved.
//

import UIKit

class HelpPageViewController: UIPageViewController, UIPageViewControllerDataSource {

    lazy var viewControllersList: [UIViewController] = {
        
        let sb = UIStoryboard.init(name: "Main", bundle: nil)
        let vc1 = sb.instantiateViewController(withIdentifier: "Vc1")
        let vc2 = sb.instantiateViewController(withIdentifier: "Vc2")
        let vc3 = sb.instantiateViewController(withIdentifier: "Vc3")
        let vc4 = sb.instantiateViewController(withIdentifier: "Vc4")
        let vc5 = sb.instantiateViewController(withIdentifier: "Vc5")
        let vc6 = sb.instantiateViewController(withIdentifier: "Vc6")
        
        return [vc1, vc2, vc3, vc4, vc5, vc6]
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.dataSource = self
        
        
        if let firstController = viewControllersList.first {
            self.setViewControllers([firstController], direction: .forward, animated: true, completion: nil)
        }
    }
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return viewControllersList.count
    }
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        return 0
    }

    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        guard let vcIndex = viewControllersList.index(of: viewController) else {return nil}
        
        let previousIndex = vcIndex - 1
        
        guard previousIndex >= 0 else {return nil}
        
        guard viewControllersList.count > previousIndex else {return nil}
        
        return viewControllersList[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        guard let vcIndex = viewControllersList.index(of: viewController) else {return nil}
        
        let nextIndex = vcIndex + 1
        
        guard viewControllersList.count != nextIndex else {return nil}
        
        guard viewControllersList.count > nextIndex else {return nil}
        
        return viewControllersList[nextIndex]
    }

}
