import crypto from "crypto";
import {
  generateResetCode,
  generateResetSessionToken,
  hashToken,
} from "../password-reset-code.util";

describe("generateResetCode", () => {
  it("returns a 6-digit numeric string", () => {
    for (let i = 0; i < 20; i++) {
      expect(generateResetCode()).toMatch(/^\d{6}$/);
    }
  });

  it("pads a short random value with leading zeros", () => {
    const spy = jest.spyOn(crypto, "randomInt").mockReturnValue(42 as never);

    expect(generateResetCode()).toBe("000042");

    spy.mockRestore();
  });
});

describe("generateResetSessionToken", () => {
  it("returns a 64-character hex string", () => {
    expect(generateResetSessionToken()).toMatch(/^[0-9a-f]{64}$/);
  });

  it("returns a different value on each call", () => {
    expect(generateResetSessionToken()).not.toBe(generateResetSessionToken());
  });
});

describe("hashToken", () => {
  it("is deterministic for the same input", () => {
    expect(hashToken("abc")).toBe(hashToken("abc"));
  });

  it("produces different hashes for different inputs", () => {
    expect(hashToken("abc")).not.toBe(hashToken("xyz"));
  });

  it("returns a 64-character hex sha256 digest", () => {
    expect(hashToken("abc")).toMatch(/^[0-9a-f]{64}$/);
  });
});
