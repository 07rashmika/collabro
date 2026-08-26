import { PrismaService } from "../infrastructure/database/prisma.service";

export function createMockPrismaService(
  client: Record<string, unknown>,
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
