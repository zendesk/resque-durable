ActiveRecord::Schema.define(:version => 1) do

  drop_table(:durable_queue_audits) rescue nil
  create_table(:durable_queue_audits) do |t|
    t.string   :enqueued_id, :null => false
    t.string   :job_klass,  :null => false
    t.string   :payload,     :null => false
    t.integer  :enqueue_count, :default => 0
    t.datetime :enqueued_at, precision: 6
    t.datetime :completed_at, precision: 6
    t.datetime :timeout_at, precision: 6
    t.timestamps :null => true
  end
  add_index(:durable_queue_audits, :enqueued_id, :unique => true)

end
