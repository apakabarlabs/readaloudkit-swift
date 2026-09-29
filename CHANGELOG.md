# Changelog

## 0.3.0

Unreleased.

### Changed

- `NarrationAlignment.sonnet: Int` is now `piece: String`, the field and type the
  server's narration schema publishes: a work names its pieces by their own ids, and
  a play or a book of stanzas has no sonnet numbers. The JSON key changes with it.

  Before:

  ```swift
  NarrationAlignment(sonnet: 18, duration: 4, words: words, recording: recording)
  ```

  ```json
  {"sonnet": 18, "duration": 4, "words": [...]}
  ```

  After:

  ```swift
  NarrationAlignment(piece: "18", duration: 4, words: words, recording: recording)
  ```

  ```json
  {"piece": "18", "duration": 4, "words": [...]}
  ```

- `SpokenLineTracker` keeps the tokenizer it was created with, as `tokenizer`, and
  `progress(heard:)` splits the transcript with it. `progress(heard:tokenizer:)` is
  gone: a transcript split by another rule than the printed lines could not be held
  against them word for word, and a tracker built for another script silently read
  its transcripts as Latin.

  Before:

  ```swift
  let tracker = SpokenLineTracker(lines: lines, tokenizer: tokenizer)
  let progress = tracker.progress(heard: transcript, tokenizer: tokenizer)
  ```

  After:

  ```swift
  let tracker = SpokenLineTracker(lines: lines, tokenizer: tokenizer)
  let progress = tracker.progress(heard: transcript)
  ```

### Fixed

- The README showed completeness as `faithful.count == matches.count`, which is true
  when a written word was not heard at all, because such a word makes no match. It
  now shows `SpokenLineTracker.progress(heard:).isComplete`, and a test holds the
  README to the usage it runs.

### Internal

- The cases the tests hold the library to are YAML under
  `Tests/ReadAloudKitTests/Resources/`, one file per subject, so every port reads the
  same ones. Swift keeps only the runners and the tests about the shape of its API.
- `VerseLayoutPlanner.plan` no longer carries a branch no input can reach.

## 0.2.0

- Exposed the passage, word tracking, narration timing, layout, progress, and
  waveform APIs for Swift package consumers.
- Updated the ReadAlign dependency to 0.13.1 and added generated API
  documentation.

## 0.1.0

- Carried out of the app that used to hold it, so that the rule deciding whether
  a word was said lives in one place and every side of a product answers the
  same way.
- No behaviour changed in the carrying: the sources and their 94 tests are as
  they were.
