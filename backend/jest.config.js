/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  testMatch: ['<rootDir>/test/**/*.spec.ts'],
  moduleFileExtensions: ['js', 'json', 'ts'],
  transform: { '^.+\\.(t|j)s$': 'ts-jest' },
  // Tests de integración/concurrencia (test/integration, test/concurrency)
  // requieren DATABASE_URL apuntando a una BD de test local — nunca a
  // DEV/PROD. Se documenta en test/README.md.
  testTimeout: 30000,
};
