//
//  MainEditor_ViewManipulation.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 10/5/15.
//  Copyright © 2015 Honza Dvorsky. All rights reserved.
//

import Cocoa
import ReactiveSwift

extension MainEditorViewController {
    
    //view controller manipulation

    fileprivate func rebindContentViewController() {
        
        let content = self._contentViewController!

        self.nextButton.rac_enabled <~ content.nextAllowed
        self.previousButton.rac_enabled <~ content.previousAllowed
        self.cancelButton.rac_enabled <~ content.cancelAllowed
        content.wantsNext.observeValues { [weak self] in self?._next(animated: $0) }
        content.wantsPrevious.observeValues { [weak self] in self?._previous(animated: false) }
        self.nextButton.rac_title <~ content.nextTitle
    }
    
    fileprivate func remove(_ viewController: NSViewController?) {
        guard let vc = viewController else { return }
        vc.view.removeFromSuperview()
        vc.removeFromParentViewController()
    }
    
    fileprivate func add(_ viewController: EditableViewController) {
        self.addChildViewController(viewController)
        let view = viewController.view
        self.containerView.addSubview(view)
        
        //also match backgrounds?
        view.wantsLayer = true
        view.layer!.backgroundColor = self.containerView.layer!.backgroundColor
        
        //setup
        self._contentViewController = viewController
        self.rebindContentViewController()
    }
    
    func setContentViewController(_ viewController: EditableViewController, animated: Bool) {
        
        //1. remove the old view
        self.remove(self._contentViewController)
        
        //2. add the new view on top of the old one
        self.add(viewController)
        
        //if no animation, complete immediately
        if !animated {
            return
        }
        
        //animation, yay!
        
        let newView = viewController.view
        
        //3. offset the new view to the right
        var startingFrame = newView.frame
        let originalFrame = startingFrame
        startingFrame.origin.x += startingFrame.size.width
        newView.frame = startingFrame
        
        //4. start an animation from right to the center
        NSAnimationContext.runAnimationGroup({ (context: NSAnimationContext) -> Void in
            
            context.duration = 0.3
            newView.animator().frame = originalFrame
            
            }) { /* do nothing */ }
    }
}
