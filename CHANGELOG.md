# Unreleased

# 4.0.0

- Clean up expired audits using `delete_all` in batches of 10000 (#15)
- Remove payload size validation (#16)
- Drop support for Ruby <2.7, Rails <5.1
- Add support for Rails 6.0, 6.1
- Pin uuidtools to ~>2.2
- Pin redis to <5

# 3.0.0

- Generate audit IDs using uuidtools to eliminate duplicate ID issues caused by hostname conflicts (#10)

# Older Releases

- See commit history
