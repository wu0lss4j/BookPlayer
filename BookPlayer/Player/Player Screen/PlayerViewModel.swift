//
//  PlayerViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/8/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import UIKit
import StoreKit

class PlayerViewModel {
  private var chapterBeforeSliderValueChange: Chapter?
  private var prefersChapterContext = UserDefaults.standard.bool(forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)
  private var prefersRemainingTime = UserDefaults.standard.bool(forKey: Constants.UserDefaults.remainingTimeEnabled.rawValue)

  func currentBookObserver() -> Published<Book?>.Publisher {
    return PlayerManager.shared.$currentBook
  }

  func isPlayingObserver() -> AnyPublisher<Bool, Never> {
    return PlayerManager.shared.isPlayingPublisher
  }

  func hasChapters() -> AnyPublisher<Bool, Never> {
    return PlayerManager.shared.hasChapters.eraseToAnyPublisher()
  }

  func hasPreviousChapter() -> Bool {
    return PlayerManager.shared.currentBook?.previousChapter() != nil
  }

  func hasNextChapter() -> Bool {
    return PlayerManager.shared.currentBook?.nextChapter() != nil
  }

  func handlePreviousChapterAction() {
    guard let previousChapter = PlayerManager.shared.currentBook?.previousChapter() else { return }

    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    PlayerManager.shared.jumpTo(previousChapter.start + 0.5)
  }

  func handleNextChapterAction() {
    guard let nextChapter = PlayerManager.shared.currentBook?.nextChapter() else { return }

    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    PlayerManager.shared.jumpTo(nextChapter.start + 0.5)
  }

  func isBookFinished() -> Bool {
    return PlayerManager.shared.currentBook?.isFinished ?? false
  }

  func getBookCurrentTime() -> TimeInterval {
    return PlayerManager.shared.currentBook?.currentTimeInContext(self.prefersChapterContext) ?? 0
  }

  func getMaxTimeVoiceOverPrefix() -> String {
    return self.prefersRemainingTime
      ? "book_time_remaining_title".localized
      : "book_duration_title".localized
  }

  func handlePlayPauseAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    PlayerManager.shared.playPause()
  }

  func handleRewindAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    PlayerManager.shared.rewind()
  }

  func handleForwardAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    PlayerManager.shared.forward()
  }

  func processToggleMaxTime() -> ProgressObject {
    self.prefersRemainingTime = !self.prefersRemainingTime
    UserDefaults.standard.set(self.prefersRemainingTime, forKey: Constants.UserDefaults.remainingTimeEnabled.rawValue)

    return self.getCurrentProgressState()
  }

  func processToggleProgressState() -> ProgressObject {
    self.prefersChapterContext = !self.prefersChapterContext
    UserDefaults.standard.set(self.prefersChapterContext, forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)

    return self.getCurrentProgressState()
  }

  func getCurrentProgressState() -> ProgressObject {
    let currentTime = self.getBookCurrentTime()
    let maxTimeInContext = self.getBookMaxTime()
    let progress: String
    let sliderValue: Float

    if self.prefersChapterContext,
       let currentBook = PlayerManager.shared.currentBook,
       currentBook.hasChapters,
       let chapters = currentBook.chapters,
       let currentChapter = currentBook.currentChapter {
      progress = String.localizedStringWithFormat("player_chapter_description".localized, currentChapter.index, chapters.count)
      sliderValue = Float((currentBook.currentTime - currentChapter.start) / currentChapter.duration)
    } else {
      progress = "\(Int(round((PlayerManager.shared.currentBook?.progressPercentage ?? 0) * 100)))%"
      sliderValue = Float(PlayerManager.shared.currentBook?.progressPercentage ?? 0)
    }

    // Update local chapter
    self.chapterBeforeSliderValueChange = PlayerManager.shared.currentBook?.currentChapter

    return ProgressObject(
      currentTime: currentTime,
      progress: progress,
      maxTime: maxTimeInContext,
      sliderValue: sliderValue
    )
  }

  func handleSliderDownEvent() {
    self.chapterBeforeSliderValueChange = PlayerManager.shared.currentBook?.currentChapter
  }

  func handleSliderUpEvent(with value: Float) {
    let newTime = getBookTimeFromSlider(value: value)

    PlayerManager.shared.jumpTo(newTime)
  }

  func processSliderValueChangedEvent(with value: Float) -> ProgressObject {
    var newCurrentTime = getBookTimeFromSlider(value: value)

    if self.prefersChapterContext,
       let currentChapter = self.chapterBeforeSliderValueChange {
      newCurrentTime = TimeInterval(value) * currentChapter.duration
    }

    var newMaxTime: TimeInterval?

    if self.prefersRemainingTime {
      let durationTimeInContext = PlayerManager.shared.currentBook?.durationTimeInContext(self.prefersChapterContext) ?? 0

      newMaxTime = newCurrentTime - durationTimeInContext
    }

    var progress: String?

    if !(PlayerManager.shared.currentBook?.hasChapters ?? false) || !self.prefersChapterContext {
      progress = "\(Int(round(value * 100)))%"
    }

    return ProgressObject(
      currentTime: newCurrentTime,
      progress: progress,
      maxTime: newMaxTime,
      sliderValue: value
    )
  }

  func getBookMaxTime() -> TimeInterval {
    return PlayerManager.shared.currentBook?.maxTimeInContext(self.prefersChapterContext, self.prefersRemainingTime) ?? 0
  }

  func getBookTimeFromSlider(value: Float) -> TimeInterval {
    var newTimeToDisplay = TimeInterval(value) * (PlayerManager.shared.currentBook?.duration ?? 0)

    if self.prefersChapterContext,
       let currentChapter = self.chapterBeforeSliderValueChange {
      newTimeToDisplay = currentChapter.start + TimeInterval(value) * currentChapter.duration
    }

    return newTimeToDisplay
  }

  func requestReview() {
    // don't do anything if flag isn't true
    guard UserDefaults.standard.bool(forKey: "ask_review") else { return }

    // request for review if app is active
    guard UIApplication.shared.applicationState == .active else { return }

    #if RELEASE
    SKStoreReviewController.requestReview()
    #endif

    UserDefaults.standard.set(false, forKey: "ask_review")
  }

  func getSpeedActionSheet() -> UIAlertController {
    let actionSheet = UIAlertController(title: nil, message: "player_speed_title".localized, preferredStyle: .actionSheet)

    for speed in SpeedManager.shared.speedOptions {
      if speed ==  SpeedManager.shared.getSpeed() {
        actionSheet.addAction(UIAlertAction(title: "\u{00A0} \(speed) ✓", style: .default, handler: nil))
      } else {
        actionSheet.addAction(UIAlertAction(title: "\(speed)", style: .default, handler: { _ in
          SpeedManager.shared.setSpeed(speed, currentBook: PlayerManager.shared.currentBook)
        }))
      }
    }

    actionSheet.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

    return actionSheet
  }
}

extension PlayerViewModel {
  func createBookmark(vc: UIViewController) {
    guard let book = PlayerManager.shared.currentBook else { return }

    let currentTime = book.currentTime

    if let bookmark = BookmarksService.getBookmark(at: currentTime, book: book, type: .user) {
      self.showBookmarkSuccessAlert(vc: vc, bookmark: bookmark, existed: true)
      return
    }

    let bookmark = BookmarksService.createBookmark(at: currentTime, book: book, type: .user)

    self.showBookmarkSuccessAlert(vc: vc, bookmark: bookmark, existed: false)
  }

  func showBookmarkSuccessAlert(vc: UIViewController, bookmark: Bookmark, existed: Bool) {
    let formattedTime = TimeParser.formatTime(bookmark.time)

    let titleKey = existed
      ? "bookmark_exists_title"
      : "bookmark_created_title"

    let alert = UIAlertController(title: String.localizedStringWithFormat(titleKey.localized, formattedTime),
                                  message: nil,
                                  preferredStyle: .alert)

    if !existed {
      alert.addAction(UIAlertAction(title: "bookmark_note_action_title".localized, style: .default, handler: { _ in
        self.showBookmarkNoteAlert(vc: vc, bookmark: bookmark)
      }))
    }

    alert.addAction(UIAlertAction(title: "bookmarks_see_title".localized, style: .default, handler: { _ in
      let nav = AppNavigationController.instantiate(from: .Player)
      let bookmarksVC = BookmarksViewController.instantiate(from: .Player)
      nav.setViewControllers([bookmarksVC], animated: false)

      vc.present(nav, animated: true, completion: nil)
    }))

    alert.addAction(UIAlertAction(title: "ok_button".localized, style: .cancel, handler: nil))

    vc.present(alert, animated: true, completion: nil)
  }

  func showBookmarkNoteAlert(vc: UIViewController, bookmark: Bookmark) {
    let alert = UIAlertController(title: "bookmark_note_action_title".localized,
                                  message: nil,
                                  preferredStyle: .alert)

    alert.addTextField(configurationHandler: { textfield in
      textfield.text = ""
    })

    alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "ok_button".localized, style: .default, handler: { _ in
      guard let note = alert.textFields?.first?.text else {
        return
      }

      DataManager.addNote(note, bookmark: bookmark)
    }))

    vc.present(alert, animated: true, completion: nil)
  }
}
