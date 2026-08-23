import {
  encryptSessionPassword,
  decryptSessionPassword,
} from "../session-password.util";

describe("session-password.util", () => {
  it("decrypts back to the original plaintext", () => {
    const plaintext = "study-room-42";
    const cipherText = encryptSessionPassword(plaintext);

    expect(cipherText).not.toBe(plaintext);
    expect(decryptSessionPassword(cipherText)).toBe(plaintext);
  });

  it("produces a different ciphertext for the same plaintext on each call", () => {
    // IV is random per call — two encryptions of the same password must not
    // be comparable/linkable by ciphertext alone.
    const a = encryptSessionPassword("same-password");
    const b = encryptSessionPassword("same-password");

    expect(a).not.toBe(b);
    expect(decryptSessionPassword(a)).toBe("same-password");
    expect(decryptSessionPassword(b)).toBe("same-password");
  });

  it("rejects a tampered ciphertext instead of returning corrupted plaintext", () => {
    const cipherText = encryptSessionPassword("correct-horse-battery-staple");
    const bytes = Buffer.from(cipherText, "base64");
    // Flip a bit inside the encrypted payload (past IV + auth tag).
    bytes[bytes.length - 1] ^= 0xff;
    const tampered = bytes.toString("base64");

    // GCM's auth tag check must fail closed, not silently decrypt garbage.
    expect(() => decryptSessionPassword(tampered)).toThrow();
  });

  it("handles empty-string passwords round-trip", () => {
    const cipherText = encryptSessionPassword("");
    expect(decryptSessionPassword(cipherText)).toBe("");
  });
});
