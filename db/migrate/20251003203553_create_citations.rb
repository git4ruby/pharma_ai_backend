class CreateCitations < ActiveRecord::Migration[7.1]
  def change
    create_table :citations do |t|
      t.references :query, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.references :embedding, null: false, foreign_key: true
      t.float :relevance_score, null: false

      t.timestamps
    end

    add_index :citations, [:query_id, :relevance_score]
  end
end
