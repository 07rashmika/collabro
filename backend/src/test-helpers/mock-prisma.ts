import { PrismaService } from "../infrastructure/database/prisma.service";

/// A hand-rolled stand-in for PrismaService used across the unit/integration
/// suite. Every model method a test needs is a jest.fn(); anything a given
/// test doesn't touch is left undefined, so an accidental extra call fails
/// loudly (`... is not a function`) instead of silently resolving undefined.
export function createMockPrismaService(
  client: Record<string, unknown>
): PrismaService {
  return { client } as unknown as PrismaService;
}

export function mockModel(overrides: Record<string, unknown> = {}) {
  return {
    findUnique: jest.fn(),
    findFirst: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    createMany: jest.fn(),
    update: jest.fn(),
    updateMany: jest.fn(),
    upsert: jest.fn(),
    delete: jest.fn(),
    deleteMany: jest.fn(),
    count: jest.fn(),
    ...overrides,
  };
}
