# Contributing to GSD Addon

Thank you for your interest in contributing to GSD Addon!

## How to Contribute

### Reporting Bugs

- Check existing issues before opening a new one
- Include:
  - Steps to reproduce
  - Expected vs actual behavior
  - Environment (OS, Python version, etc.)
  - Relevant logs or error messages

### Suggesting Enhancements

- Describe the enhancement and why it would be useful
- Provide examples of how it would work
- Link to related issues

### Code Contributions

1. **Fork the repository**

   ```bash
   git clone https://github.com/yourusername/gsd-addon.git
   cd gsd-addon
   ```

2. **Create a feature branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**

   - Follow the existing code style
   - Add tests for new functionality
   - Update documentation as needed

4. **Test locally**

   ```bash
   # Verify installation
   bash install.sh
   
   # Test changes
   gsd-config verify
   gsd-test --workflow booking-e2e.workflow.yml
   ```

5. **Commit with a clear message**

   ```bash
   git commit -m "feat: Add new feature description
   
   - Detailed explanation of changes
   - Why this change is needed
   
   Co-Authored-By: Your Name <your.email@example.com>"
   ```

6. **Push and create a Pull Request**

   ```bash
   git push origin feature/your-feature-name
   ```

   Then open a PR on GitHub with:
   - Clear description of changes
   - Link to related issues
   - Test plan

## Code Style

- Follow PEP 8 for Python code
- Use meaningful variable names
- Add docstrings to functions
- Keep functions focused and small
- Comment complex logic

## Testing

- Test your changes locally before submitting
- Include test cases for new features
- Ensure existing tests still pass

## Documentation

- Update README if adding features
- Document new workflows with examples
- Include comments for complex sections

## Questions?

- Open an issue for questions
- Check existing documentation first
- Ask in a GitHub Discussion if it's not a bug

---

**Thank you for contributing! 🙏**
