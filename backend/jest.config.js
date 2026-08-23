/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: "node",
  transform: {
    "^.+\\.ts$": ["ts-jest", { tsconfig: "<rootDir>/../tsconfig.test.json" }],
  },
  rootDir: "src",
  testMatch: ["**/__tests__/**/*.test.ts"],
  // sessions.routes.ts registers a process-lifetime setInterval (the stale-
  // session sweep) the moment app.ts is imported for the integration suite —
  // harmless in prod, but it's a handle Jest would otherwise wait on forever.
  forceExit: true,
  setupFiles: ["<rootDir>/../jest.setup.js"],
  collectCoverageFrom: [
    "**/*.ts",
    "!**/__tests__/**",
    "!infrastructure/database/prisma.service.ts",
  ],
};
