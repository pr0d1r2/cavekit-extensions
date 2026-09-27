# Tended by an autonomous loop, deliberately and in the open

Commits and pull requests in this repository may be written by a machine, and
may be merged without a human reading the diff. The merge gate is this
repository's own checks plus an automated review, not human approval.

Some classes of change are held for a human by design: releases, anything
touching the loop's own safety rails, and anything that could publish to a
package registry. Everything else is not.

That is the disclaimer. The rest of this file is what a reader can check
without taking any of it on trust. It states no counts and no claims about this
repository that were not read off it when this file was written; where a fact
was absent, the section that would have asserted it is not here.

## Why say it at all

A machine-authored commit is indistinguishable from a human one. A contributor
opening a pull request expecting a human reviewer, a reader treating a merged
commit as human-reviewed evidence, and a downstream consumer sizing trust by
the commit log all have no way to discover the fact from the artefact.

The cost of that silence lands on someone who never chose to interact with an
autonomous system, which is why it is declared here rather than left to be
inferred.

## The audit trail is the commit log

The loop commits in small, logical pieces rather than one squashed drop, and
the commit message carries the reasoning: what was wrong, why this fix and not
the obvious one, what was rejected and on what evidence. The log is therefore
the review record, readable after the fact by someone who was not present when
the work happened.

Read it that way:

```sh
git log --format='%H %s%n%b'
```

A commit whose message explains nothing is a defect in its own right, and worth
reporting as one.

## What governs the loop here

[`SPEC.md`](../SPEC.md) is checked in beside the code and carries these
sections: `B C G I T V`. Where section B is present it is the defect log:
what got through, in the loop's own words, including defects that survived for
weeks and defects a gate itself caused.

Those entries are worth more than a green badge. A gate is a claim about what
it catches, and the only honest way to describe one is alongside what it
missed.

## The guardrails are the repository's CI gate

This repository's pull requests are gated by the reusable workflow referenced
from `.github/workflows/ci.yml`. That workflow supplies the repository's
checks; there is no checked-in `lefthook.yml` or local pre-commit command to
run here. A change the gate refuses is not pushed and no pull request is
opened for it.

Inspect the gate definition here:

```sh
sed -n '1,120p' .github/workflows/ci.yml
```

The workflow is the authoritative check for this repository; its reusable
workflow implementation lives in `pr0d1r2/set-and-setting`. Its checks can be
run from the pull request's Checks tab; this repository does not expose a
local command that reproduces the reusable workflow.

## What a reader should actually check

In the order it matters:

1. **Do the checks run for you?** If a claim here is false, that is where it
    shows.
2. **Do the commit messages explain the decisions?** That is the whole audit
    trail. If it reads as a series of assertions, treat the code the same way.
3. **Does the defect log read like a real one or a curated one?** Judge the
    rest of the record by its least flattering entry.
4. **Do the rules have runners?** A rule nothing executes is a comment with a
    number on it.

## Accountability

Marcin Nowicki is responsible for this repository, including the parts a
machine wrote and the parts nobody caught. "The loop did it" is an explanation
of provenance, never a transfer of responsibility.

Issues and pull requests from people are welcome and are read by a human. If
you need one, say so in the thread and a human will answer. Unflattering
reports are more useful than kind ones.
