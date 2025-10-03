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

puts "\nSeed completed successfully!"
puts "\nTest credentials:"
puts "Admin: admin@test.com / Admin@123456"
puts "Doctor: doctor@test.com / Doctor@123456"
puts "Researcher: researcher@test.com / Researcher@123456"
puts "Auditor: auditor@test.com / Auditor@123456"
