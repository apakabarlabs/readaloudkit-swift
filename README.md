[![Tests](https://github.com/apakabarlabs/readaloudkit-swift/actions/workflows/tests.yml/badge.svg)](https://github.com/apakabarlabs/readaloudkit-swift/actions/workflows/tests.yml)
[![Documentation](https://github.com/apakabarlabs/readaloudkit-swift/actions/workflows/documentation.yml/badge.svg)](https://apakabarlabs.github.io/readaloudkit-swift/documentation/readaloudkit/)
# readaloudkit-swift

Decides whether a person reading a printed text aloud said what is written, and
holds that decision in one place so that every side of a product answers the
same way.

A recogniser does not return the text that was read. It returns today's spelling
for an old one, a word boundary in the wrong place, and now and then a different
word for the same sound. What counts as having said a word is therefore a rule,
not a comparison, and a rule that lives in two places drifts: the phone clears a
line the server holds, and nobody can say which is right.

## What it decides

- **Whether a word was said.** The recogniser's output is lined up against the
  text, and each pair is the written word itself or a spelling written down for
  the build that misheard it.
- **What a build is allowed to mishear.** `RecognizerQuirks` carries those
  spellings, narrowed where a word is only misheard in one turn of phrase.
- **What a recogniser answers.** `SpokenLineTracker.corrected(_:)` applies a build's
  table to its own transcript, so a transcript leaves the recogniser already patched
  and whatever checks it needs no table of the build that heard it.
- **Where the reader is.** Which line is being read, which words of it are
  already behind, and which word the narration is on.
- **Whether a piece is finished**, and what a stage of a drill still owes.

## Use

```swift
let tokenizer = WordTokenizer(interiorMarks: CharacterSet(charactersIn: work.interiorMarks))
let elisions = Elisions(fullForms: work.elisions)
let tracker = SpokenLineTracker(
    lines: lines,
    quirks: quirks,
    elisions: elisions,
    tokenizer: tokenizer
)
let saidEveryWord = tracker.progress(heard: transcript).isComplete
```

`work` stands for the data that comes with the work, not with this library: the marks
its script keeps inside a word, such as an apostrophe or a hyphen, and the full forms of
each elided spelling it prints, such as `tattered` for `tatter’d`. Nothing here knows a
language or picks one for you, and an elision the work does not list is not restored.

A written word nothing was heard for is left out of `SpokenWords.check(...).matches`
altogether, so comparing how many matches were faithful with how many there were
does not show that every word was said; `isComplete` does.

Where a character ends and whether it is a letter follow the Unicode data of the
platform the code runs on. Two systems of different ages can cut a character Unicode
has since changed in different places, and nothing here promises otherwise.

Every Swift example in this README is code the tests run, and a test fails when one is
not.

## Cases

What the library answers for a given input is written down in YAML under
`Tests/ReadAloudKitTests/Resources/`, one file per subject, and every port is held
to the same files. What stays in Swift is the runner, and the tests that are about
the shape of the Swift API rather than about an answer. The documents the server
publishes are read as served: `make served` fetches them beside the cases, from the
endpoints the apps read.

## Reading what the server publishes

`PublishedAlignment.decode` and `RecognizerQuirks.decode` refuse a document that lacks a
field or holds a value of another type, and read past a field they do not know. An app
already installed cannot learn a field the server adds later, so such a field must not
stop it. A key repeated within one object keeps one of its values; which one is not
promised and may differ between ports.

That leniency rests on a contract with the server. It may add a field, but never one
that changes the meaning of a field the library already reads, such as a field that
narrows an allowance, and it never renames or drops a field. The library cannot tell a
break of that contract from an added field: an allowance whose `after` is misspelt is
read as an allowance with no `after`, allowed after any word.

## The measure belongs here

A tool that hears our own recordings back before they ship uses this same code,
so that the bar a reader is held to is the bar the recordings are held to. A
recording that would fail a reader is caught before anyone reads it.

## Documentation

The [Swift-DocC API reference](https://apakabarlabs.github.io/readaloudkit-swift/documentation/readaloudkit/)
is generated from the public API on every push to `main`.

## Lines of Code

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/apakabarlabs/readaloudkit-swift/main/.github/loc-history-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/apakabarlabs/readaloudkit-swift/main/.github/loc-history-light.svg">
  <img src="https://raw.githubusercontent.com/apakabarlabs/readaloudkit-swift/main/.github/loc-history.svg" alt="Lines of code over time">
</picture>
