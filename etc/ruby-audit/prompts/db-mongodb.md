# MongoDB Analysis Context (Mongoid)

MongoDB is a document-oriented NoSQL database. In Rails, it is typically accessed via the `Mongoid` ODM.

## Schema-less Pitfalls
*   **Missing Fields**: Since MongoDB is schema-less, older documents might lack fields defined in the model. Ensure `default` values or presence validations are used.
*   **Dynamic Fields**: Be cautious with dynamic fields (`include Mongoid::Attributes::Dynamic`) as they can lead to unstructured data.

## Performance and Indexing
*   **Indexes**: MongoDB requires explicit indexes for performance. Audit models for `index` declarations.
*   **Background Indexes**: Ensure `background: true` is used for index creation to prevent blocking the database.
*   **N+1 Queries**: Mongoid has its own N+1 pitfalls. Check for `.includes(:relation)` usage.
*   **Aggregation Framework**: Complex logic should use the aggregation pipeline (`collection.aggregate`) rather than fetching all documents into Ruby memory.

## Modeling Patterns
*   **Embeds vs References**: `embeds_one`/`embeds_many` vs `has_one`/`has_many`. Embedding is faster but leads to large documents. Referencing requires manual cleanup of orphaned documents (no foreign keys).
*   **Atomic Updates**: Use `inc`, `set`, `push` for atomic updates to avoid race conditions.

## Operational Hygiene
*   **Capped Collections**: Useful for logging or transient data.
*   **TTL Indexes**: Automatically expire documents after a certain time.
