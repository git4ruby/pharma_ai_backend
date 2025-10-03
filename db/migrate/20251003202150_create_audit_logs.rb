class CreateAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.string :resource_type
      t.integer :resource_id
      t.string :ip_address
      t.text :user_agent
      t.jsonb :metadata, default: {}
      t.datetime :performed_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    # Indexes for fast querying (HIPAA compliance requires quick audit trail access)
    add_index :audit_logs, :action
    add_index :audit_logs, :resource_type
    add_index :audit_logs, :performed_at
    add_index :audit_logs, [:user_id, :performed_at]
    add_index :audit_logs, [:resource_type, :resource_id]
    add_index :audit_logs, :metadata, using: :gin  # For JSONB queries
  end
end
