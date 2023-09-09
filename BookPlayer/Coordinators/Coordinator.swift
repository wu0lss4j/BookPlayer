//
//  Coordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

public typealias BPTransition<T> = ((T) -> Void)

public enum FlowType {
  case push, modal
}

class Coordinator: NSObject {
  var navigationController: UINavigationController
  weak var presentingViewController: UIViewController?
  let flowType: FlowType
  var childCoordinators = [Coordinator]()
  weak var parentCoordinator: Coordinator?

  init(navigationController: UINavigationController,
       flowType: FlowType) {
    self.navigationController = navigationController
    self.flowType = flowType
  }

  func start() {
    fatalError("Coordinator is an abstract class, override this function in the subclass")
  }

  func getMainCoordinator() -> MainCoordinator? { return nil }
}

extension AlertPresenter where Self: Coordinator {
  func showAlert(_ title: String? = nil, message: String? = nil, completion: (() -> Void)? = nil) {
    self.navigationController.showAlert(title, message: message, completion: completion)
  }

  func showLoader() {
    LoadingUtils.loadAndBlock(in: self.navigationController)
  }

  func stopLoader() {
    LoadingUtils.stopLoading(in: self.navigationController)
  }
}

extension UINavigationControllerDelegate where Self: Coordinator {
  // Handle vcs being popped interactively
  func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
    // Read the view controller we’re moving from.
    guard let fromViewController = navigationController.transitionCoordinator?.viewController(forKey: .from) else {
      return
    }

    // Check whether our view controller array already contains that view controller. If it does it means we’re pushing a different view controller on top rather than popping it, so exit.
    if navigationController.viewControllers.contains(fromViewController) {
      return
    }
  }
}

extension Coordinator: UIAdaptivePresentationControllerDelegate {
  // Handle modals being dismissed interactively
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    self.detach()
  }

  func detach() {
    self.parentCoordinator?.childDidFinish(self)
  }

  func didFinish() {
    switch self.flowType {
    case .modal:
      self.presentingViewController?.dismiss(animated: true, completion: { [weak self] in
        self?.detach()
      })
    case .push:
      self.navigationController.popViewController(animated: true)
      self.detach()
    }
  }

  private func childDidFinish(_ child: Coordinator?) {
    guard let index = self.childCoordinators.firstIndex(where: { $0 === child }) else { return }
    self.childCoordinators.remove(at: index)
  }
}

