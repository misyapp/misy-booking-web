const { defineConfig } = require('eslint-define-config');

module.exports = defineConfig({
  languageOptions: {
    parserOptions: {
      ecmaVersion: 2020, // Set to the version you need
      sourceType: 'module', // Use 'module' if you're using ES modules
    },
    globals: {
      // Define any global variables your functions may need
    },
    // Environment settings
    env: {
      node: true, // Enable Node.js global variables
      mocha: true, // Enable Mocha globals if needed
    },
  },
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", { "allowTemplateLiterals": true }],
    // Add other specific rules as necessary for your project
  },
  // Instead of using overrides, use a custom configuration per file type
  files: ['**/*.spec.*'], // Pattern to match test files
  languageOptions: {
    env: {
      mocha: true, // Enable Mocha environment for test files
    },
  },
});
