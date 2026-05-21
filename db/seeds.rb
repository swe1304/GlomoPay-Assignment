puts "Clearing existing users..."
User.destroy_all

puts "Creating users..."

alice = User.create!(
  name: "Alice",
  email: "alice@example.com",
  pin: "1234",
  balance: 1000.00
)
puts "Created Alice (balance: #{alice.balance})"

bob = User.create!(
  name: "Bob",
  email: "bob@example.com",
  pin: "5678",
  balance: 500.00
)
puts "Created Bob (balance: #{bob.balance})"

puts "Seeding complete!"
