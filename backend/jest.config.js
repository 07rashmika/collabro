//claude code generated file
/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: "node",
  transform: {
    "^.+\\.ts$": ["ts-jest", { tsconfig: "<rootDir>/../tsconfig.test.json" }],
  },
  rootDir: "src",
  testMatch: ["**/__tests__/**/*.test.ts"],
  forceExit: true,
  setupFiles: ["<rootDir>/../jest.setup.js"],
  collectCoverageFrom: [
    "**/*.ts",
    "!**/__tests__/**",
    "!infrastructure/database/prisma.service.ts",
  ],
};
