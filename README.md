# s2ar assert / diff — a GitHub Action

Check what your pipeline produced before it ships, and keep the proof. One step calls `api.s2ar.dev` and writes the
signed record's link to the job summary: a JSON artifact against a schema and terms (`assert`), or two screenshots
against each other (`diff`, the golden frame against today's: structure, colour, texture). Anyone verifies the record
free at `https://api.s2ar.dev/v1/verify/<sha>`. No model sits behind a check.

```yaml
- uses: codylwalker/s2ar-action@v1
  with:
    key: ${{ secrets.S2AR_API_KEY }}
    tool: assert
    file: build/report.json
    schema: schemas/report.schema.json
    checks: '[{"check":"json_valid"},{"check":"no_terms","terms":["TODO","FIXME"]}]'
```

```yaml
- uses: codylwalker/s2ar-action@v1
  with:
    key: ${{ secrets.S2AR_API_KEY }}
    tool: diff
    a: golden/home.png
    b: shots/home.png
    fail-on: regression
```

Outputs `verdict` and `record`. The step fails when the verdict is in `fail-on` (default `fail,regression`), so a
regression blocks the merge and the record says which witness flagged it.

**The key.** Runners share addresses, so the keyless free samples do not apply in CI. A key comes from
https://api.s2ar.dev/login (an email sign-in, $1 on the account: about a hundred asserts at $0.005, or a hundred diffs);
put it in the repository's secrets as `S2AR_API_KEY`. A call that fails is never charged.

**What travels.** `assert` sends the artifact's text; `diff` sends the two images. Nothing is stored: the record keeps
inputs by hash, width, height and byte count, never the pixels or the text. The checks and their arguments:
https://api.s2ar.dev/v1/assert/checks · the diff witnesses: https://api.s2ar.dev/v1/diff/checks · worked examples:
https://s2ar.dev/examples/
