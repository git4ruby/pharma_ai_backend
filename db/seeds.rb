# Create default users for testing
puts "Creating seed users..."

# Admin user
admin = User.find_or_create_by!(email: 'admin@test.com') do |user|
  user.password = 'Admin@123456'
  user.password_confirmation = 'Admin@123456'
  user.first_name = 'Admin'
  user.last_name = 'User'
  user.role = :admin
end
puts "Created admin user: #{admin.email}"

# Doctor user
doctor = User.find_or_create_by!(email: 'doctor@test.com') do |user|
  user.password = 'Doctor@123456'
  user.password_confirmation = 'Doctor@123456'
  user.first_name = 'John'
  user.last_name = 'Doe'
  user.role = :doctor
end
puts "Created doctor user: #{doctor.email}"

# Researcher user
researcher = User.find_or_create_by!(email: 'researcher@test.com') do |user|
  user.password = 'Researcher@123456'
  user.password_confirmation = 'Researcher@123456'
  user.first_name = 'Jane'
  user.last_name = 'Smith'
  user.role = :researcher
end
puts "Created researcher user: #{researcher.email}"

# Auditor user
auditor = User.find_or_create_by!(email: 'auditor@test.com') do |user|
  user.password = 'Auditor@123456'
  user.password_confirmation = 'Auditor@123456'
  user.first_name = 'Bob'
  user.last_name = 'Johnson'
  user.role = :auditor
end
puts "Created auditor user: #{auditor.email}"

puts "\nCreating sample documents..."

# Sample documents for doctor
doc1 = Document.find_or_create_by!(content_hash: 'hash_clinical_trial_001') do |doc|
  doc.user = doctor
  doc.title = 'Phase III Clinical Trial Results - Drug XYZ'
  doc.filename = 'clinical_trial_xyz.pdf'
  doc.file_path = '/uploads/documents/clinical_trial_xyz.pdf'
  doc.file_type = 'application/pdf'
  doc.file_size = 2_500_000
  doc.contains_phi = true
  doc.classification = 'confidential'
  doc.status = 'completed'
  doc.processed_at = 2.days.ago
end
puts "Created document: #{doc1.title}"

doc2 = Document.find_or_create_by!(content_hash: 'hash_adverse_events_002') do |doc|
  doc.user = doctor
  doc.title = 'Adverse Events Report Q1 2025'
  doc.filename = 'adverse_events_q1.pdf'
  doc.file_path = '/uploads/documents/adverse_events_q1.pdf'
  doc.file_type = 'application/pdf'
  doc.file_size = 1_800_000
  doc.contains_phi = true
  doc.classification = 'restricted'
  doc.status = 'completed'
  doc.processed_at = 1.day.ago
end
puts "Created document: #{doc2.title}"

doc3 = Document.find_or_create_by!(content_hash: 'hash_research_paper_003') do |doc|
  doc.user = researcher
  doc.title = 'Novel Drug Discovery Methods'
  doc.filename = 'drug_discovery.docx'
  doc.file_path = '/uploads/documents/drug_discovery.docx'
  doc.file_type = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  doc.file_size = 500_000
  doc.contains_phi = false
  doc.classification = 'public'
  doc.status = 'completed'
  doc.processed_at = 3.days.ago
end
puts "Created document: #{doc3.title}"

puts "\nCreating sample embeddings..."

# Embeddings for doc1
embedding1_1 = Embedding.find_or_create_by!(document: doc1, chunk_index: 0) do |emb|
  emb.chunk_text = 'The Phase III clinical trial for Drug XYZ showed significant efficacy with a 78% response rate in the treatment group compared to 45% in the placebo group.'
  emb.embedding_model = 'llama3.2:3b'
  emb.embedding = [0.23, 0.45, 0.67, 0.12, 0.89, 0.34, 0.56, 0.78].to_json
end

embedding1_2 = Embedding.find_or_create_by!(document: doc1, chunk_index: 1) do |emb|
  emb.chunk_text = 'Safety profile was acceptable with mild to moderate side effects reported in 32% of participants. No serious adverse events were attributed to the study drug.'
  emb.embedding_model = 'llama3.2:3b'
  emb.embedding = [0.34, 0.56, 0.23, 0.89, 0.12, 0.67, 0.45, 0.78].to_json
end

embedding1_3 = Embedding.find_or_create_by!(document: doc1, chunk_index: 2) do |emb|
  emb.chunk_text = 'The primary endpoint of progression-free survival at 12 months was met with statistical significance (p<0.001).'
  emb.embedding_model = 'llama3.2:3b'
  emb.embedding = [0.45, 0.23, 0.89, 0.34, 0.78, 0.12, 0.56, 0.67].to_json
end

puts "Created #{doc1.embeddings.count} embeddings for: #{doc1.title}"

# Embeddings for doc2
embedding2_1 = Embedding.find_or_create_by!(document: doc2, chunk_index: 0) do |emb|
  emb.chunk_text = 'During Q1 2025, a total of 127 adverse events were reported. Of these, 12 were classified as serious adverse events requiring immediate medical intervention.'
  emb.embedding_model = 'llama3.2:3b'
  emb.embedding = [0.12, 0.78, 0.34, 0.56, 0.23, 0.89, 0.45, 0.67].to_json
end

embedding2_2 = Embedding.find_or_create_by!(document: doc2, chunk_index: 1) do |emb|
  emb.chunk_text = 'Most common adverse events included headache (23%), nausea (18%), and fatigue (15%). All were managed successfully with supportive care.'
  emb.embedding_model = 'llama3.2:3b'
  emb.embedding = [0.67, 0.12, 0.45, 0.78, 0.89, 0.23, 0.34, 0.56].to_json
end

puts "Created #{doc2.embeddings.count} embeddings for: #{doc2.title}"

# Embeddings for doc3
embedding3_1 = Embedding.find_or_create_by!(document: doc3, chunk_index: 0) do |emb|
  emb.chunk_text = 'Machine learning algorithms are revolutionizing drug discovery by predicting molecular interactions and identifying potential drug candidates faster than traditional methods.'
  emb.embedding_model = 'llama3.2:3b'
  emb.embedding = [0.89, 0.34, 0.12, 0.67, 0.45, 0.56, 0.78, 0.23].to_json
end

puts "Created #{doc3.embeddings.count} embeddings for: #{doc3.title}"

puts "\nCreating sample queries..."

# Query 1 with citations
query1 = Query.find_or_create_by!(question: 'What were the efficacy results of the Drug XYZ clinical trial?') do |q|
  q.user = doctor
  q.answer = 'The Phase III clinical trial for Drug XYZ demonstrated significant efficacy with a 78% response rate in the treatment group compared to 45% in the placebo group. The primary endpoint of progression-free survival at 12 months was met with statistical significance (p<0.001).'
  q.status = 'completed'
  q.processing_time = 2.3
  q.metadata = { model: 'llama3.2:3b', tokens_used: 150 }
end
puts "Created query: #{query1.question}"

Citation.find_or_create_by!(query: query1, embedding: embedding1_1) do |c|
  c.document = doc1
  c.relevance_score = 0.95
end

Citation.find_or_create_by!(query: query1, embedding: embedding1_3) do |c|
  c.document = doc1
  c.relevance_score = 0.88
end

# Query 2
query2 = Query.find_or_create_by!(question: 'What are the common adverse events reported?') do |q|
  q.user = doctor
  q.answer = 'The most common adverse events included headache (23%), nausea (18%), and fatigue (15%). All were managed successfully with supportive care. During Q1 2025, 127 adverse events were reported in total, with 12 classified as serious adverse events.'
  q.status = 'completed'
  q.processing_time = 1.8
  q.metadata = { model: 'llama3.2:3b', tokens_used: 120 }
end
puts "Created query: #{query2.question}"

Citation.find_or_create_by!(query: query2, embedding: embedding2_2) do |c|
  c.document = doc2
  c.relevance_score = 0.92
end

Citation.find_or_create_by!(query: query2, embedding: embedding2_1) do |c|
  c.document = doc2
  c.relevance_score = 0.85
end

# Query 3
query3 = Query.find_or_create_by!(question: 'How is machine learning being used in drug discovery?') do |q|
  q.user = researcher
  q.answer = 'Machine learning algorithms are revolutionizing drug discovery by predicting molecular interactions and identifying potential drug candidates faster than traditional methods. This approach significantly reduces the time and cost associated with early-stage drug development.'
  q.status = 'completed'
  q.processing_time = 2.1
  q.metadata = { model: 'llama3.2:3b', tokens_used: 135 }
end
puts "Created query: #{query3.question}"

Citation.find_or_create_by!(query: query3, embedding: embedding3_1) do |c|
  c.document = doc3
  c.relevance_score = 0.97
end

puts "\nSeed completed successfully!"
puts "\nTest credentials:"
puts "Admin: admin@test.com / Admin@123456"
puts "Doctor: doctor@test.com / Doctor@123456"
puts "Researcher: researcher@test.com / Researcher@123456"
puts "Auditor: auditor@test.com / Auditor@123456"
puts "\nSeed data summary:"
puts "- #{User.count} users"
puts "- #{Document.count} documents"
puts "- #{Embedding.count} embeddings"
puts "- #{Query.count} queries"
puts "- #{Citation.count} citations"
