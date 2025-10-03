class CreateEmbeddings < ActiveRecord::Migration[7.1]
  def change
    create_table :embeddings do |t|
      t.references :document, null: false, foreign_key: true
      t.text :chunk_text, null: false
      t.integer :chunk_index, null: false
      t.text :embedding, null: false
      t.string :embedding_model, null: false

      t.timestamps
    end

    add_index :embeddings, [:document_id, :chunk_index], unique: true
    add_index :embeddings, :embedding_model
  end
end
