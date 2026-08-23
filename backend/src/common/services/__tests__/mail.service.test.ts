import { MailService } from "../mail.service";
import { AppError } from "../../errors/app-error";

const sendMail = jest.fn();

jest.mock("nodemailer", () => ({
  createTransport: jest.fn(() => ({ sendMail })),
}));

// eslint-disable-next-line @typescript-eslint/no-var-requires
const nodemailer = require("nodemailer");

describe("MailService.sendPasswordResetCode", () => {
  const ORIGINAL_ENV = process.env;

  beforeEach(() => {
    jest.clearAllMocks();
    process.env = { ...ORIGINAL_ENV };
  });

  afterAll(() => {
    process.env = ORIGINAL_ENV;
  });

  it("throws a 503 AppError when SMTP is not configured", async () => {
    delete process.env.SMTP_HOST;
    delete process.env.SMTP_PORT;
    delete process.env.SMTP_USER;
    delete process.env.SMTP_PASS;
    const service = new MailService();

    await expect(service.sendPasswordResetCode("a@x.com", "A", "123456")).rejects.toThrow(
      AppError
    );
    await expect(service.sendPasswordResetCode("a@x.com", "A", "123456")).rejects.toMatchObject({
      statusCode: 503,
    });
  });

  it("sends the reset code with the expected recipient, subject, and code embedded", async () => {
    process.env.SMTP_HOST = "smtp.example.com";
    process.env.SMTP_PORT = "587";
    process.env.SMTP_USER = "user@example.com";
    process.env.SMTP_PASS = "secret";
    process.env.MAIL_FROM = "noreply@example.com";
    sendMail.mockResolvedValue({});
    const service = new MailService();

    await service.sendPasswordResetCode("a@x.com", "Jane", "654321");

    expect(sendMail).toHaveBeenCalledWith(
      expect.objectContaining({
        from: '"Collabro" <noreply@example.com>',
        to: "a@x.com",
        subject: "Your Collabro password reset code",
        text: expect.stringContaining("654321"),
        html: expect.stringContaining("654321"),
      })
    );
  });

  it("reuses the same transporter across multiple sends", async () => {
    process.env.SMTP_HOST = "smtp.example.com";
    process.env.SMTP_PORT = "587";
    process.env.SMTP_USER = "user@example.com";
    process.env.SMTP_PASS = "secret";
    sendMail.mockResolvedValue({});
    const service = new MailService();

    await service.sendPasswordResetCode("a@x.com", "Jane", "111111");
    await service.sendPasswordResetCode("b@x.com", "Bob", "222222");

    expect(nodemailer.createTransport).toHaveBeenCalledTimes(1);
  });
});
