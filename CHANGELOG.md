# Changelog

## 0.3.0

### Added

- `Elisions`, the full forms of each elided spelling a work prints, taken from the
  work's data. A spelling may stand for several full forms, any of which counts as
  said, and spellings that normalize alike are merged.
- `PublishedAlignment`, an alignment and the version the server published it under.
- `NotUTF8`: a served alignment or hearing table is read as UTF-8, with or without a
  byte order mark, and text in any other encoding is refused with this error. A second
  byte order mark, a lone surrogate escaped in any string, and a control character
  written raw inside a string are refused with a `DecodingError`, as JSON forbids them.

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
  let tracker = SpokenLineTracker(
      lines: lines,
      quirks: .none,
      elisions: .none,
      tokenizer: tokenizer
  )
  let progress = tracker.progress(heard: transcript)
  ```

- Nothing picks a language for the caller any more. `SpokenLineTracker(line:…)`,
  `SpokenLineTracker(lines:…)`, `SpokenLineTracker.wordsPerLine(of:tokenizer:)`,
  `NarrationAlignment.timings(for:tokenizer:)` and
  `NarrationTimeline.estimate(for:duration:tokenizer:weighting:)` take their tokenizer,
  and the estimate its weighting, with no default; `TranscriptAligner.timings` takes a
  `weighting` it used to leave to ReadAlign's English default.

  Before:

  ```swift
  SpokenLineTracker(lines: lines)
  NarrationTimeline.estimate(for: passage, duration: duration)
  ```

  After:

  ```swift
  let tokenizer = WordTokenizer(interiorMarks: CharacterSet(charactersIn: work.interiorMarks))
  let tracker = SpokenLineTracker(
      lines: lines,
      quirks: quirks,
      elisions: Elisions(fullForms: work.elisions),
      tokenizer: tokenizer
  )
  let timings = NarrationTimeline.estimate(
      for: passage,
      duration: duration,
      tokenizer: tokenizer,
      weighting: EnglishSyllableWeighting()
  )
  ```

- `SpokenLineTracker(line:…)` and `SpokenLineTracker(lines:…)` take `quirks` with no
  default, as they take `tokenizer` and `elisions`; pass `.none` for a recogniser with
  nothing to patch.
- An elided spelling counts as said only when the heard word is the full form the
  work's data gives for it, passed as `Elisions`. `SpokenLineTracker(line:…)`,
  `SpokenLineTracker(lines:…)`, `SpokenWords.check` and `SpokenLineTracker.isFaithful`
  take `elisions`. The library no longer restores one or two of the vowels `aeiou` at
  an apostrophe on its own: that rule was English, and wrong for other languages.

  Before:

  ```swift
  SpokenLineTracker.isFaithful("tattered", to: "tatter’d")
  ```

  After:

  ```swift
  SpokenLineTracker.isFaithful(
      "tattered",
      to: "tatter’d",
      elisions: Elisions(fullForms: ["tatter’d": ["tattered"]])
  )
  ```

- Decoding a `NarrationAlignment` refuses word times that cannot describe one
  recording read in order, with a `NarrationAlignment.TimingError` naming the word and
  its printed line: a negative start, an end before its start, or a start before the
  word ahead of it. Values made in code are not checked.
- An alignment is read as the server publishes it, `{"version": ..., "alignment": {...}}`,
  with `PublishedAlignment.decode(_:)`, which returns the version beside the alignment.
  `NarrationAlignment.decode(_:)` is gone: nothing publishes a bare alignment.

  Before:

  ```swift
  let alignment = try NarrationAlignment.decode(data)
  ```

  After:

  ```swift
  let alignment = try PublishedAlignment.decode(data).alignment
  ```

- A hearing table is read as the server publishes it for one recogniser build,
  `{"build": ..., "version": ..., "words": {written: [{"heard": ..., "after": ...}]}}`.
  `RecognizerQuirks.decode(_:build:)` refuses a table published for another build with
  `RecognizerQuirks.WrongBuild`. The table keyed by model, `decode(_:model:)`,
  `UnknownModel` and a bare heard string in place of `{"heard": ...}` are gone: no
  server publishes them.

  Before:

  ```swift
  let quirks = try RecognizerQuirks.decode(data, model: "parakeet")
  ```

  After:

  ```swift
  let quirks = try RecognizerQuirks.decode(data, build: "parakeet-tdt-0.6b-v3-sherpa-int8")
  ```

- Decoding a published alignment or a hearing table refuses a missing field and a
  value of another type, but reads past a field it does not know, so that a field the
  server adds later does not stop a build already installed. A word's `line` outside a
  32-bit integer is refused, as every port refuses it. A key repeated within one object
  keeps one of its values; which one is not promised and may differ between ports.
- `NarrationAlignment.AlignmentError.wordMismatch` names the printed line of the word on
  both sides, as `expectedLine` and `foundLine`, since a word can match in spelling and
  still sit on another line.
- ReadAlign is required from 0.17.0; nothing this package calls changed between
  0.13.1 and 0.17.1.
- Where a character ends and whether it is a letter follow the Unicode data of the
  system the code runs on; the documentation no longer suggests every platform cuts
  every character alike.

### Removed

- `WordTokenizer.latinScript`. The marks a script keeps inside a word come with the
  work's data: `WordTokenizer(interiorMarks: CharacterSet(charactersIn: work.interiorMarks))`.

### Fixed

- `WordTokenizer` tells a letter or a space by the base of a character, the scalar its
  combining marks sit on, rather than by its first scalar. A sign prepended to a letter,
  such as the Arabic number sign, no longer cuts that letter out of its word, and one
  prepended to a space leaves it a space.
- `WaveformEnvelope.make(from:bars:)` no longer traps when the number of bars times the
  number of samples outgrows `Int`.
- The README showed completeness as `faithful.count == matches.count`, which is true
  when a written word was not heard at all, because such a word makes no match. It
  now shows `SpokenLineTracker.progress(heard:).isComplete`.

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
