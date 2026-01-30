---
name: testing
description: Writes and runs tests to verify code behavior. Use when asked to test, verify, validate, write tests, or check functionality. Triggered by keywords like "test", "verify", "validate", "write tests", "check", "assert", "coverage".
---

# Testing Code

## Workflow

1. **Understand what to test**
   - Identify the function/module under test
   - Determine expected behavior
   - Note edge cases and error conditions

2. **Check existing tests**
   - Look for existing test files
   - Understand testing patterns used
   - Identify gaps in coverage

3. **Write tests**
   - Follow existing test structure
   - Cover happy path first
   - Add edge cases and error cases

4. **Run and verify**
   - Execute the tests
   - Confirm they pass
   - Check coverage if tools available

## Test Structure (AAA Pattern)

```python
def test_descriptive_name():
    # Arrange - set up test data and conditions
    input_data = create_test_data()
    expected = "expected result"
    
    # Act - perform the action being tested
    result = function_under_test(input_data)
    
    # Assert - verify the result
    assert result == expected
```

## What to Test

### ✅ Should Test
- **Happy path**: Normal inputs produce expected outputs
- **Edge cases**: Empty inputs, boundaries, limits
- **Error cases**: Invalid inputs, exceptions
- **State changes**: Side effects are correct

### ❌ Don't Test
- Third-party library internals
- Language/framework behavior
- Private implementation details
- Trivial getters/setters

## Test Naming

Use descriptive names that explain what's being tested:

```python
# ❌ Bad
def test_1():
def test_function():

# ✅ Good  
def test_add_returns_sum_of_two_numbers():
def test_login_fails_with_invalid_password():
def test_empty_list_returns_none():
```

## Common Test Patterns

### Testing Functions
```python
def test_calculate_total_with_discount():
    items = [{"price": 100}, {"price": 50}]
    discount = 0.1
    
    result = calculate_total(items, discount)
    
    assert result == 135  # (100 + 50) * 0.9
```

### Testing Exceptions
```python
def test_divide_by_zero_raises_error():
    with pytest.raises(ValueError, match="Cannot divide by zero"):
        divide(10, 0)
```

### Testing with Mocks
```python
def test_fetch_user_calls_api(mocker):
    mock_api = mocker.patch('module.api_client')
    mock_api.get.return_value = {"id": 1, "name": "Test"}
    
    result = fetch_user(1)
    
    mock_api.get.assert_called_once_with("/users/1")
    assert result["name"] == "Test"
```

### Parameterized Tests
```python
@pytest.mark.parametrize("input,expected", [
    ("hello", "HELLO"),
    ("", ""),
    ("Hello World", "HELLO WORLD"),
])
def test_uppercase(input, expected):
    assert uppercase(input) == expected
```

## Running Tests

### Python (pytest)
```bash
# Run all tests
pytest

# Run specific file
pytest tests/test_module.py

# Run specific test
pytest tests/test_module.py::test_function_name

# Run with coverage
pytest --cov=src --cov-report=html

# Run with verbose output
pytest -v

# Stop on first failure
pytest -x
```

### JavaScript (Jest)
```bash
# Run all tests
npm test

# Run specific file
npm test -- path/to/test.js

# Run with coverage
npm test -- --coverage

# Watch mode
npm test -- --watch
```

## Test File Organization

```
project/
├── src/
│   ├── module_a.py
│   └── module_b.py
└── tests/
    ├── test_module_a.py
    └── test_module_b.py
```

Or colocated:
```
project/
├── module_a.py
├── module_a_test.py
├── module_b.py
└── module_b_test.py
```

Match the project's existing convention.

## Test Quality Checklist

- [ ] Tests have descriptive names
- [ ] Each test tests one thing
- [ ] Tests are independent (no shared state)
- [ ] Tests are deterministic (same result every run)
- [ ] Edge cases are covered
- [ ] Error cases are covered
- [ ] Tests run fast (<100ms each ideally)

## Output Format

When testing is complete, provide:

```markdown
## Testing Summary

**Module tested**: [path/to/module]

**Tests written/updated:**
- test_function_happy_path - [what it tests]
- test_function_edge_case - [what it tests]
- test_function_error - [what it tests]

**Coverage** (if available):
- Lines: X%
- Branches: X%

**Test results:**
- Passed: X
- Failed: 0
- Skipped: X

**Notes:**
- [Any caveats or recommendations]
```

## When to Write Tests

| Situation | Recommendation |
|-----------|----------------|
| New feature | Write tests alongside or immediately after |
| Bug fix | Write a test that reproduces the bug first |
| Refactoring | Ensure tests exist before refactoring |
| Legacy code | Add tests for code you're modifying |

## Reference

For project-specific testing patterns:
- Check existing tests in `tests/` or `*_test.py` files
- See `CLAUDE.md` for testing conventions
- Look for `pytest.ini`, `setup.cfg`, or `jest.config.js` for configuration
