// @ts-check
import eslint from '@eslint/js';
import prettier from 'eslint-config-prettier';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['dist/', 'coverage/', 'eslint.config.mjs', 'jest.config.js'] },
  eslint.configs.recommended,
  tseslint.configs.strictTypeChecked,
  prettier,
  {
    languageOptions: {
      globals: { ...globals.node, ...globals.jest },
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // Nest modules are decorated empty classes.
      '@typescript-eslint/no-extraneous-class': 'off',
      // A failed query's message carries its parameter values (see
      // docs/agents/gotchas.md); logs go through messageOf() / stackOf().
      'no-restricted-syntax': [
        'error',
        {
          selector:
            "CallExpression[callee.object.property.name='logger'] MemberExpression[property.name=/^(message|stack)$/]",
          message:
            'Log errors through messageOf() / stackOf() from src/errors/message-of.ts.',
        },
      ],
    },
  },
);
