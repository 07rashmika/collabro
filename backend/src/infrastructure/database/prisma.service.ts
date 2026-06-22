import { PrismaClient } from "@prisma/client";
import { PrismaNeon } from "@prisma/adapter-neon";
import { WebSocket } from "ws";
import { neonConfig } from "@neondatabase/serverless";

// tell Neon serverless driver to use the ws package in Node.js
neonConfig.webSocketConstructor = WebSocket;

export class PrismaService {
  private static instance: PrismaService;
  public readonly client: PrismaClient;

  private constructor() {
    const adapter = new PrismaNeon({
      connectionString: process.env.DATABASE_URL!,
    });
    this.client = new PrismaClient({ adapter });
  }

  static getInstance(): PrismaService {
    if (!PrismaService.instance) {
      PrismaService.instance = new PrismaService();
    }
    return PrismaService.instance;
  }

  async disconnect() {
    await this.client.$disconnect();
  }
}