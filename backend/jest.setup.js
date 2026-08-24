// Test-only environment values — never used against a real database or a
// real Firebase project. Prisma access is always mocked per-test-file
// (see src/**/__tests__), so DATABASE_URL just needs to be present, not valid.
process.env.NODE_ENV = "test";
process.env.DATABASE_URL = "postgresql://test:test@localhost:5432/test";
process.env.JWT_ACCESS_SECRET = "test-access-secret";
process.env.JWT_REFRESH_SECRET = "test-refresh-secret";
process.env.SESSION_PASSWORD_KEY = "bpOllSMF0WGlCV9mSx228c/n2Qo7DfRlNyFgXS9jPUM=";
process.env.ADMIN_EMAIL = "admin@test.local";
process.env.ADMIN_PASSWORD = "test-admin-password";
process.env.ADMIN_JWT_SECRET = "test-admin-jwt-secret";
