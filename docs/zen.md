---
id: zen
title: "The Zen of Zsh"
purpose: Philosophical foundation for the Zdots control plane.
rationale: Adapts PEP 20 for the unique flexibility and interactive power of the Z shell.
links:
  - id: architecture
    rel: parent
---

# The Zen of Zsh

*Adapted from PEP 20 (The Zen of Python) for the Zsh philosophy.*

* **Interactive is better than scripted.**
* The shell is a conversation; prioritize features that make the live prompt smarter, not just the script faster.
* **Implicit is better than explicit (for the fingers).**
* Let the shell assume the `**/` or the `.git` extension. If it saves ten keystrokes, the magic is worth it.
* **Recursive is better than flat.**
* `**/*` is a honking great idea—let’s do more of those.
* **Completion counts.**
* If you have to type the whole filename, the shell has failed you.
* **Special cases are special enough to break the rules.**
* Shell work is messy; your aliases should be messier if they get the job done.
* **Practicality beats purity.**
* It is better to have a 500-line `.zshrc` that works perfectly for you than a "pure" 10-line one that does nothing.
* **Errors should never pass silently...**
* ...unless you're using `2>/dev/null` because you know exactly what you're doing.
* **In the face of ambiguity, refuse the temptation to guess.**
* This is why we have Approximate Completion—to ask, "Did you mean this?" instead of just failing.
* **There should be many ways to do it, and you should know the shortest one.**
* Unlike Python's "one way", Zsh is the TMTOWTDI (There's More Than One Way To Do It) of shells.
* **Now is better than never.**
* Automate that command now before you have to type it a third time.
* **If the implementation is hard to explain, it’s probably a powerful alias.**
* If it's easy to explain, it might just be a Bash function.

---

## Key Philosophical Differences

| Principle | Zen of Python | Zen of Zsh |
|---|---|---|
| **Approach** | Explicit is better than implicit. | Globbing and expansions are life. |
| **Variety** | One obvious way to do it. | Every user has a unique `.zshrc`. |
| **Complexity** | Simple is better than complex. | Complex one-liners are a badge of honor. |
| **Focus** | Readability and maintenance. | Speed and interactive efficiency. |
