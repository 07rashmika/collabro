import { createCipheriv } from "crypto";

// Adapted from ZEGOCLOUD's official token04 reference implementation:
// https://github.com/ZEGOCLOUD/zego_server_assistant/blob/master/token/nodejs/server/zegoServerAssistant.ts
// Kept close to the original so it stays verifiable against ZEGOCLOUD's docs.

function randomInt32(): number {
  return Math.ceil(-2147483648 + 4294967295 * Math.random());
}

function randomIv(): string {
  const chars = "0123456789abcdefghijklmnopqrstuvwxyz";
  let result = "";
  for (let i = 0; i < 16; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

function algorithmForKeyLength(keyBase64: string): string {
  const key = Buffer.from(keyBase64);
  switch (key.length) {
    case 16:
      return "aes-128-cbc";
    case 24:
      return "aes-192-cbc";
    case 32:
      return "aes-256-cbc";
    default:
      throw new Error(`Invalid ZEGO_SERVER_SECRET length: ${key.length} (must be 16, 24, or 32 bytes)`);
  }
}

function aesEncrypt(plainText: string, key: string, iv: string): Buffer {
  const cipher = createCipheriv(algorithmForKeyLength(key), key, iv);
  cipher.setAutoPadding(true);
  return Buffer.concat([cipher.update(plainText), cipher.final()]);
}

/** Mints a ZEGOCLOUD token04 string for a user, valid for `effectiveTimeInSeconds`. */
export function generateZegoToken04(
  appId: number,
  userId: string,
  secret: string,
  effectiveTimeInSeconds: number,
  payload = ""
): string {
  if (secret.length !== 32) {
    throw new Error("ZEGO_SERVER_SECRET must be a 32-character string");
  }

  const createTime = Math.floor(Date.now() / 1000);
  const tokenInfo = {
    app_id: appId,
    user_id: userId,
    nonce: randomInt32(),
    ctime: createTime,
    expire: createTime + effectiveTimeInSeconds,
    payload,
  };

  const iv = randomIv();
  const encrypted = aesEncrypt(JSON.stringify(tokenInfo), secret, iv);

  const expireBuf = Buffer.alloc(8);
  expireBuf.writeBigInt64BE(BigInt(tokenInfo.expire));

  const ivLenBuf = Buffer.alloc(2);
  ivLenBuf.writeUInt16BE(iv.length);

  const cipherLenBuf = Buffer.alloc(2);
  cipherLenBuf.writeUInt16BE(encrypted.length);

  const packed = Buffer.concat([
    expireBuf,
    ivLenBuf,
    Buffer.from(iv),
    cipherLenBuf,
    encrypted,
  ]);

  return "04" + packed.toString("base64");
}
