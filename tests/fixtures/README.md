# Public MDG fixture

`cucumber_reference.feature.md` reproduces the Markdown with Gherkin example from [Cucumber's MDG reference](https://github.com/cucumber/gherkin/blob/main/MARKDOWN_WITH_GHERKIN.md). It is covered by `tests/features/markdown.feature`.

`cucumber_datatables.feature.md` and `cucumber_docstrings.feature.md` reproduce Cucumber's [DataTables](https://github.com/cucumber/gherkin/blob/main/testdata/good/datatables.feature.md) and [DocString](https://github.com/cucumber/gherkin/blob/main/testdata/good/docstrings.feature.md) conformance fixtures. The DataTables copy removes one trailing space after the step text. Assertions use the semantics and source locations in Cucumber's corresponding `.ast.ndjson` files, without depending on generated IDs or the JSON envelope shape.
