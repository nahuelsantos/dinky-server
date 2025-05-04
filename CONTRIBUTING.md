# Contributing to Dinky Server

Thank you for considering contributing to Dinky Server! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, please include as many details as possible:

- Use a clear and descriptive title
- Describe the exact steps to reproduce the issue
- Describe the behavior you observed and what you expected
- Include screenshots if applicable
- Include details about your environment (OS, hardware, etc.)

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

- A clear and concise description of what you want to happen
- Any specific examples of how the enhancement would work
- Explain why this enhancement would be useful to most Dinky Server users

### Pull Requests

1. Fork the repository
2. Create a new branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`make test` and `make test-all`)
5. Commit your changes (`git commit -m 'Add some amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Style Guidelines

- Follow the existing code style and conventions
- Use meaningful variable and function names
- Include comments for complex code sections
- Update documentation to reflect your changes

### Development Setup

Follow these steps to set up a development environment:

1. Clone the repository
   ```bash
   git clone https://github.com/nahuelsantos/dinky-server.git
   cd dinky-server
   ```

2. Initialize the environment
   ```bash
   sudo ./scripts/initialize.sh
   ```

3. Configure your environment
   ```bash
   cp .env.example .env
   # Edit .env file with your settings
   ```

4. Use the provided make commands
   ```bash
   # Show available commands
   make help
   
   # Set up development environment
   make setup
   
   # Run tests
   make test
   make test-all
   ```

## Documentation

If you're changing features, remember to update the documentation:

- Update README.md if appropriate
- Update wiki_content/ documentation to reflect changes
- Add screenshots or diagrams if they help explain your changes

## Additional Resources

- [Project README](README.md)
- [Documentation Wiki](wiki_content/)

Thank you for contributing to Dinky Server! 