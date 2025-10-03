class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :filename, null: false
      t.string :file_path, null: false
      t.string :file_type, null: false
      t.integer :file_size, null: false
      t.boolean :contains_phi, default: false, null: false
      t.string :classification
      t.string :content_hash, null: false
      t.string :status, default: 'pending', null: false
      t.datetime :processed_at

      t.timestamps
    end

    add_index :documents, :status
    add_index :documents, :contains_phi
    add_index :documents, :file_type
    add_index :documents, :content_hash, unique: true
    add_index :documents, [:user_id, :created_at]
  end
end
