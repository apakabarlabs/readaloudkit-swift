# ``ReadAloudKit``

Tokenize printed passages, compare them with speech-recognizer output, and map
recorded audio back to the words on the page.

## Start with a reading check

Create a ``SpokenLineTracker`` from the printed lines, then pass it the complete
recognized transcript. A piece is complete only when every printed word is
faithful; alignment may be loose enough to pair a near miss without crediting it.

```swift
let tracker = SpokenLineTracker(lines: ["From fairest creatures", "we desire increase"])
let progress = tracker.progress(heard: "From fairest creatures we desire increase")
let completed = progress.isComplete
```

Use ``RecognizerQuirks`` only for repeatable output of a named recognizer build.
Quirks are not pronunciation rules and an unknown model is refused rather than
treated as a model with no quirks.

## Map audio to print

``NarrationAlignment`` imports word timings supplied with a recording and refuses
a passage whose words no longer match. ``NarrationTimeline`` estimates a temporary
timeline when no alignment exists, adjusts measured boundaries using audio, and
queries the word or line at a playback position.

## Preserve the printed page

``WordTokenizer`` returns words and drawable ``LineSegment`` values without losing
punctuation or spacing. ``VerseLayoutPlanner`` chooses turnovers for all lines
together so one awkward line does not determine the page by itself.

## Topics

### Check a reading

- ``SpokenLineTracker``
- ``SpokenWords``
- ``RecognizerQuirks``
- ``WordCheck``
- ``WordAttempt``

### Tokenize printed text

- ``Passage``
- ``WordTokenizer``
- ``SpokenWord``
- ``LineSegment``

### Align and follow recordings

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
