# MariaDB Analysis Context

MariaDB is a binary drop-in replacement for MySQL, but it has evolved with its own features and optimizations.

## Charset and Collation
*   **utf8 vs utf8mb4**: Ensure `utf8mb4` is used for full Unicode support (emojis, rare characters). In MariaDB, `utf8` is often an alias for `utf8mb3`, which only supports 3 bytes.
*   **Collation**: `unicode_ci` vs `general_ci`. `unicode_ci` is more accurate for sorting but slightly slower.

## MariaDB Features
*   **JSON Support**: MariaDB 10.2.7+ supports JSON via a `LONGTEXT` column with a `JSON` alias and `JSON_VALID` constraints.
*   **Virtual Columns**: Useful for indexing parts of a JSON document or computed values.
*   **Storage Engines**: InnoDB is the default, but MariaDB supports Aria (for temporary tables) and ColumnStore (for analytics).

## Common Performance Issues
*   **Missing Indexes**: Audit `db/schema.rb` or `db/structure.sql` for foreign keys without indexes.
*   **Full Group By**: MariaDB defaults to `ONLY_FULL_GROUP_BY` in newer versions. Audit raw SQL for non-deterministic `GROUP BY` clauses.
*   **N+1 Queries**: Standard ActiveRecord N+1 issues apply. Check for `find` in loops.

## Upgrade Notes
*   **MySQL 5.7 to MariaDB 10.x**: Mostly compatible, but check for differences in default system variables.
