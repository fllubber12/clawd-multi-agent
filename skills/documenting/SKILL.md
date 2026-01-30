---
name: documenting
description: Writes and updates documentation for code, projects, and processes. Use when asked to document, explain, write README, add comments, or create guides. Triggered by keywords like "document", "explain", "README", "docs", "comments", "guide", "describe".
---

# Documenting Code and Projects

## Workflow

1. **Understand the audience**
   - Who will read this? (developers, users, yourself later)
   - What do they need to know?
   - What's their knowledge level?

2. **Identify what needs documenting**
   - New code/features
   - Complex logic
   - Setup/installation
   - Usage examples

3. **Write clearly**
   - Use simple language
   - Be concise but complete
   - Include examples

4. **Verify accuracy**
   - Test any code examples
   - Check commands work
   - Review for clarity

## Documentation Types

### README.md
The entry point for any project.

```markdown
# Project Name

Brief description of what this project does.

## Installation

```bash
pip install project-name
```

## Quick Start

```python
from project import main_function
result = main_function("input")
```

## Usage

[More detailed usage instructions]

## Configuration

[Configuration options]

## Contributing

[How to contribute]

## License

[License information]
```

### Code Comments

**When to comment:**
- Non-obvious "why" (not "what")
- Complex algorithms
- Workarounds for bugs
- Important assumptions

**When NOT to comment:**
- Obvious code
- What the code does (the code shows that)
- Commented-out code (delete it)

```python
# ❌ Bad - explains what
# Loop through users
for user in users:
    process(user)

# ✅ Good - explains why
# Process in reverse order because dependencies must be removed
# before parents (see issue #123 for details)
for user in reversed(users):
    process(user)
```

### Docstrings

```python
def calculate_discount(price: float, customer_type: str) -> float:
    """
    Calculate the discounted price based on customer type.
    
    Args:
        price: Original price in dollars
        customer_type: One of 'regular', 'premium', 'vip'
    
    Returns:
        Discounted price. Returns original price if customer_type
        is not recognized.
    
    Raises:
        ValueError: If price is negative
    
    Examples:
        >>> calculate_discount(100, 'premium')
        90.0
        >>> calculate_discount(100, 'unknown')
        100.0
    """
```

### API Documentation

```markdown
## Endpoint: POST /api/users

Create a new user.

### Request

```json
{
  "name": "string (required)",
  "email": "string (required, valid email)",
  "role": "string (optional, default: 'user')"
}
```

### Response

**Success (201):**
```json
{
  "id": "uuid",
  "name": "string",
  "email": "string",
  "role": "string",
  "created_at": "ISO timestamp"
}
```

**Error (400):**
```json
{
  "error": "string",
  "details": ["list of validation errors"]
}
```
```

### Process Documentation

```markdown
# Deployment Process

## Prerequisites
- AWS CLI configured
- Docker installed
- Access to production cluster

## Steps

1. **Build the image**
   ```bash
   docker build -t app:latest .
   ```

2. **Run tests**
   ```bash
   docker run app:latest pytest
   ```

3. **Push to registry**
   ```bash
   docker push registry/app:latest
   ```

4. **Deploy**
   ```bash
   kubectl apply -f k8s/deployment.yaml
   ```

## Rollback

If issues occur:
```bash
kubectl rollout undo deployment/app
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Build fails | Check Dockerfile, run locally first |
| Tests fail | Check test logs, ensure deps updated |
| Deploy timeout | Check pod logs: `kubectl logs -l app=myapp` |
```

## Writing Guidelines

### Be Concise
```markdown
# ❌ Verbose
This function is used for the purpose of calculating the total sum
of all the numbers that are contained within the provided list.

# ✅ Concise
Calculates the sum of numbers in a list.
```

### Use Active Voice
```markdown
# ❌ Passive
The configuration file should be edited by the user.

# ✅ Active
Edit the configuration file.
```

### Include Examples
```markdown
# ❌ No example
The `--format` flag accepts various format strings.

# ✅ With example
The `--format` flag accepts format strings:
```bash
mycommand --format json
mycommand --format "csv,headers"
```
```

### Structure for Scanning
- Use headers to organize
- Use bullet points for lists
- Use code blocks for commands/code
- Bold important terms

## Documentation Quality Checklist

- [ ] Accurate (tested, up to date)
- [ ] Complete (covers main use cases)
- [ ] Clear (understandable by target audience)
- [ ] Concise (no unnecessary words)
- [ ] Examples included
- [ ] Formatting consistent

## Output Format

When documentation is complete, provide:

```markdown
## Documentation Summary

**Created/Updated:**
- path/to/README.md - [what was added]
- path/to/file.py - [docstrings added]

**Documentation type:**
- [README / API docs / Process guide / etc.]

**Target audience:**
- [Developers / Users / Both]

**Key sections:**
- [List of main sections added]
```

## When to Document

| Situation | Document |
|-----------|----------|
| New feature | README update, docstrings |
| Bug fix | Add comment explaining the fix if non-obvious |
| Process change | Update process docs |
| API change | Update API docs |
| Onboarding friction | Add setup/getting started guide |

## Reference

For project documentation standards:
- Check existing docs in `docs/` or `README.md`
- See `CLAUDE.md` for documentation conventions
- Match existing docstring style in the codebase
