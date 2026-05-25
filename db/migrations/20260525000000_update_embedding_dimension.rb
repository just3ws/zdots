# frozen_string_literal: true

# Qwen3-8B has n_embd=4096 vs Qwen2.5-7B's 3584.
# Safe to run: zero existing embeddings, so no data loss or reindexing needed.
Sequel.migration do
  up do
    run "ALTER TABLE methodologies ALTER COLUMN embedding TYPE vector(4096)"
    run "ALTER TABLE lessons ALTER COLUMN embedding TYPE vector(4096)"
  end

  down do
    run "ALTER TABLE methodologies ALTER COLUMN embedding TYPE vector(3584)"
    run "ALTER TABLE lessons ALTER COLUMN embedding TYPE vector(3584)"
  end
end
