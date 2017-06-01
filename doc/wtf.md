From https://superuser.com/questions/142099/get-function-into-ps1-zsh

Regarding using double quotes and single quotes when evaluating functions
inside prompt strings.

> Actually your problem was not just setting PROMPT_SUBST: you use double
> quotes in your script forcing the evaluation of the function when you set the
> PROMPT variables. You only want evaluation when the prompt is computed that
> is you must use single quotes.
