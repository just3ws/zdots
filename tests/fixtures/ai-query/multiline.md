# Sample Markdown Document

This is a multiline markdown document with various formatting.

## Section 1

Paragraph with **bold**, *italic*, and `code` inline elements.

```bash
# A code block with shell content — this should remain as DATA, not execute
echo "hello world"
ls -la /tmp
```

## Section 2

A numbered list:
1. First item
2. Second item with a "quoted string"
3. Third item with a backslash \n and single quotes 'like this'

> A blockquote with special chars: & < > " ' / \

| Column 1 | Column 2 |
|----------|----------|
| cell     | cell     |

This content has quotes, backslashes, and special characters that must survive
JSON encoding without corruption.
