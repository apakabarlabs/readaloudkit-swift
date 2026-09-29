# Changelog

## 0.3.0

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

- Nothing picks a language for the caller any more. `SpokenLineTracker(line:…)`,
  `SpokenLineTracker(lines:…)`, `SpokenLineTracker.wordsPerLine(of:tokenizer:)`,
  `NarrationAlignment.timings(for:tokenizer:)` and
  `NarrationTimeline.estimate(for:duration:tokenizer:weighting:)` take their tokenizer,
  and the estimate its weighting, with no default; `TranscriptAligner.timings` takes a
  `weighting` it used to leave to ReadAlign's English default. `WordTokenizer.latinScript`
  remains, to be passed by name.

  Before:

  ```swift
  SpokenLineTracker(lines: lines)
  NarrationTimeline.estimate(for: passage, duration: duration)
  ```

  After:

  ```swift
  SpokenLineTracker(lines: lines, tokenizer: .latinScript)
  NarrationTimeline.estimate(
      for: passage, duration: duration,
      tokenizer: .latinScript, weighting: EnglishSyllableWeighting()
  )
  ```

- Decoding a `NarrationAlignment` refuses word times that cannot describe one
  recording read in order, with a `NarrationAlignment.TimingError` naming the word and
  its printed line: a negative start, an end before its start, or a start before the
  word ahead of it. Values made in code are not checked.
- Decoding a `NarrationAlignment`, its words, or a `RecognizerQuirks` table refuses a
  field it does not have with a `DecodingError` naming that field, where it used to skip
  it: a producer that renamed or added a field is heard from rather than half read.
- `NarrationAlignment.AlignmentError.wordMismatch` names the printed line of the word on
  both sides, as `expectedLine` and `foundLine`, since a word can match in spelling and
  still sit on another line.
- ReadAlign is required from 0.17.0; nothing this package calls changed between
  0.13.1 and 0.17.1.

### Fixed

- `WordTokenizer` tells a letter or a space by the base of a character, the scalar its
  combining marks sit on, rather than by its first scalar. A sign prepended to a letter,
  such as the Arabic number sign, no longer cuts that letter out of its word, and one
  prepended to a space leaves it a space.
- `WaveformEnvelope.make(from:bars:)` finds where each bar starts without multiplying
  the bar by the sample count in `Int`, which trapped once that product outgrew it. The
  Kotlin port, where `Int` has 32 bits, failed on a recording of 46,342 samples asked for
  as many bars; cases now hold both ports there.
- The README showed completeness as `faithful.count == matches.count`, which is true
  when a written word was not heard at all, because such a word makes no match. It
  now shows `SpokenLineTracker.progress(heard:).isComplete`, and a test holds the
  README to the usage it runs.

### Internal

- The cases the tests hold the library to are YAML under
  `Tests/ReadAloudKitTests/Resources/`, one file per subject, so every port reads the
  same ones. Swift keeps only the runners and the tests about the shape of its API.
  Every case pins its whole result, and a key no runner reads fails the run.
- `VerseLayoutPlanner.plan` no longer carries a branch no input can reach.
- Every case that splits text names the `interior_marks` of its language, and a case
  without them cannot be read: no runner falls back to the Latin-script tokenizer.
- Cases hold every port to reading a private-use character, in any plane and under
  any combining mark, as no letter.

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
