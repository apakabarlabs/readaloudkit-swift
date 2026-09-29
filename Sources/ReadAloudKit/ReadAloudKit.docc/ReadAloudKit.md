# ``ReadAloudKit``

Tokenize printed passages, compare them with speech-recognizer output, and map
recorded audio back to the words on the page.

## Start with a reading check

Create a ``SpokenLineTracker`` from the printed lines and from what the work's data
says about its language, then pass it the complete recognized transcript. A piece is
complete only when every printed word is faithful; alignment may be loose enough to
pair a near miss without crediting it.

```swift
let tokenizer = WordTokenizer(interiorMarks: CharacterSet(charactersIn: work.interiorMarks))
let elisions = Elisions(fullForms: work.elisions)
let tracker = SpokenLineTracker(
    lines: ["Will be a tatter’d weed", "of small worth held"],
    elisions: elisions,
    tokenizer: tokenizer
)
let progress = tracker.progress(heard: "will be a tattered weed of small worth held")
let completed = progress.isComplete
```

`work` stands for the work's data: the marks its script keeps inside a word, and the
full form of each elided spelling it prints. ``WordTokenizer`` and ``Elisions`` hold no
language of their own.

Use ``RecognizerQuirks`` only for repeatable output of a named recognizer build.
Quirks are not pronunciation rules, and a table published for another build is
refused rather than taken for this one.

## Map audio to print

``PublishedAlignment`` reads the word timings the server publishes for a recording,
and ``NarrationAlignment`` refuses a passage whose words no longer match them. ``NarrationTimeline`` estimates a temporary
timeline when no alignment exists, adjusts measured boundaries using audio, and
queries the word or line at a playback position.

## Preserve the printed page

``WordTokenizer`` returns words and drawable ``LineSegment`` values without losing
punctuation or spacing. Where a character ends and whether it is a letter follow the
Unicode data of the platform the code runs on. ``VerseLayoutPlanner`` chooses turnovers for all lines
together so one awkward line does not determine the page by itself.

## Topics

### Check a reading

- ``SpokenLineTracker``
- ``SpokenWords``
- ``Elisions``
- ``RecognizerQuirks``
- ``WordCheck``
- ``WordAttempt``

### Tokenize printed text

- ``Passage``
- ``WordTokenizer``
- ``SpokenWord``
- ``LineSegment``

### Align and follow recordings

- ``PublishedAlignment``
- ``NarrationAlignment``
- ``NarrationTimeline``
- ``WordTiming``

### Track a staged reading

- ``PieceProgress``
- ``PieceProgressState``
- ``StageState``

### Lay out and display audio

- ``VerseLayoutPlanner``
- ``VerseLayoutPlan``
- ``PlaybackEnvelope``
- ``WaveformEnvelope``
