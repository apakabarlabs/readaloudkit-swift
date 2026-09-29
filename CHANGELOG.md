# Changelog

ReadAloudKit checks a reading aloud of a printed text against that text: which written
words were said, where in the text the reader is, and when each word sounds in a
recorded narration.

## 0.3.0

Two JSON documents your server may publish are read here: a *narration alignment*, the
start and end time of every word in a recorded reading, and a *hearing table*, the
spellings one speech-recognition model build is known to write for particular words
(a modern spelling for an old one, say). `RecognizerQuirks` holds a hearing table.

### Added

- `Elisions`: the elided spellings your text prints, words with a letter left out such
  as `tatter’d`, each with the full forms a recogniser writes for it, such as
  `tattered`. Any of a spelling's full forms counts as saying it. `Elisions.none` lists
  no elision.
- `PublishedAlignment`: a narration alignment together with the version string it was
  published under.
- `UnknownStageState`, thrown by `StageState(stored:)`; see Changed.
- `NotUTF8`, thrown when a narration alignment or hearing table is not UTF-8 text. A
  byte order mark at the start is accepted. A second byte order mark, a lone surrogate
  escaped in a string, and a control character written raw inside a string are refused
  with a `DecodingError`, as JSON forbids them.

### Changed

- `StageState`, where one stage of a staged reading drill stands, is restored from its
  stored number by `StageState(stored:)`, which now throws `UnknownStageState` for a
  number other than 0, 1 or 2, such as one a newer version of your app wrote. It used
  to crash the app; what to show instead is now your decision.

  Before:

  ```swift
  let stage = StageState(stored: raw)
  ```

  After:

  ```swift
  let stage = try StageState(stored: raw)
  ```

- `NarrationAlignment.sonnet: Int` is now `piece: String`, and the JSON key `sonnet` is
  now `piece`: a text names its pieces by ids of its own, and a play or a book of poems
  has no sonnet numbers.

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
  removed: a transcript split by another rule than the printed lines cannot be matched
  against them word for word.

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

- No argument defaults to English or to Latin script any more, so the same code serves
  texts in other languages. These now take a `tokenizer` with no default:
  `SpokenLineTracker(line:…)`, `SpokenLineTracker(lines:…)`,
  `SpokenLineTracker.wordsPerLine(of:tokenizer:)`,
  `NarrationAlignment.timings(for:tokenizer:)` and
  `NarrationTimeline.estimate(for:duration:tokenizer:weighting:)`. The estimate also
  takes its `weighting`, the language's rule for how long each word takes to say, with
  no default, and `TranscriptAligner.timings` gains a required `weighting`. The English
  weighting that used to be the default is `EnglishSyllableWeighting()` from ReadAlign;
  to name it, add readalign-swift to your package and `import ReadAlign`.

  Before:

  ```swift
  SpokenLineTracker(lines: lines)
  NarrationTimeline.estimate(for: passage, duration: duration)
  TranscriptAligner.timings(for: words, heard: heard, duration: duration)
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

  `TranscriptAligner.timings` takes its weighting the same way:
  `TranscriptAligner.timings(for: words, heard: heard, duration: duration, weighting: EnglishSyllableWeighting())`.

  `work` stands for your text's own data, which this library does not supply:
  `work.interiorMarks` is a `String` of the marks its script keeps inside a word, such
  as `"'’-"` for English, and `work.elisions` is a `[String: [String]]` from each elided
  spelling to its full forms, such as `["tatter’d": ["tattered"]]`.

- `SpokenLineTracker(line:…)` and `SpokenLineTracker(lines:…)` take `quirks` with no
  default, as they take `tokenizer` and `elisions`. Pass the `RecognizerQuirks` read from
  the hearing table for your recogniser, or `.none` if you have none.
- An elided spelling counts as said only when the heard word is one of the full forms
  you pass for it as `Elisions`. `SpokenLineTracker(line:…)`,
  `SpokenLineTracker(lines:…)`, `SpokenWords.check` and `SpokenLineTracker.isFaithful`
  take `elisions`. The library no longer restores one or two of the vowels `aeiou` at
  an apostrophe on its own: that rule only held for English.

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

- Decoding a `NarrationAlignment` throws `NarrationAlignment.TimingError`, naming the
  word and its printed line, for word times that cannot describe one recording read in
  order: a negative start, an end before its start, or a start before the previous
  word's. An alignment built in code is not checked.
- A narration alignment is read in the shape it is published in,
  `{"version": ..., "alignment": {...}}`, by `PublishedAlignment.decode(_:)`, which
  returns the version beside the alignment. `NarrationAlignment.decode(_:)`, which read
  a bare alignment, is removed.

  Before:

  ```swift
  let alignment = try NarrationAlignment.decode(data)
  ```

  After:

  ```swift
  let alignment = try PublishedAlignment.decode(data).alignment
  ```

- A hearing table is published for one recogniser build and read in the shape
  `{"build": ..., "version": ..., "words": {written: [{"heard": ..., "after": ...}]}}`.
  `RecognizerQuirks.decode(_:build:)` takes the name of the build your app ships, the
  same name the table was published under, and throws `RecognizerQuirks.WrongBuild` for
  a table published for another build. `decode(_:model:)`, its `UnknownModel` error, the
  table keyed by model and a bare heard string in place of `{"heard": ...}` are removed.

  Before:

  ```swift
  let quirks = try RecognizerQuirks.decode(data, model: "parakeet")
  ```

  After:

  ```swift
  let quirks = try RecognizerQuirks.decode(data, build: "parakeet-tdt-0.6b-v3-sherpa-int8")
  ```

  `"parakeet-tdt-0.6b-v3-sherpa-int8"` names one such build, the Parakeet TDT 0.6B v3
  model quantised to int8 and run by sherpa-onnx; pass the name of yours.

- Decoding a narration alignment or a hearing table throws for a missing field or a
  value of the wrong type, but skips a field it does not know, so that a field added to
  the documents later does not break an app already installed. A word's `line` outside
  the 32-bit integer range is refused. When a key repeats within one JSON object, one of
  its values is kept; which one is not promised and may differ from readaloudkit-kotlin.
- `NarrationAlignment.AlignmentError.wordMismatch` gives the printed line of the word on
  both sides, as `expectedLine` and `foundLine`, since a word can match in spelling and
  still sit on another line.
- Requires ReadAlign 0.17.0 or later, up from 0.13.1. Nothing ReadAloudKit uses from
  ReadAlign changed between those versions; the rise only matters if your app pins an
  older ReadAlign itself.

### Removed

- `WordTokenizer.latinScript`. Build the tokenizer from your text's data;
  `WordTokenizer(interiorMarks: CharacterSet(charactersIn: "'’-"))` is what it was.

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
