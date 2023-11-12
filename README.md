# webpage_extractors
web page html content extractors

The goal is providing serveral extractors and compare their performance.

Note: Under development, Apis can be changed at any time.

## Apis

Basic content extractor, no need for language detection and stop words.

```nim
proc extractContentBasic*(s: string, textOnly = false): string =
```
