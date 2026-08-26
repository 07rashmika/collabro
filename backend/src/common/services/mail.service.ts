import nodemailer, { Transporter } from "nodemailer";
import { AppError } from "../errors/app-error";

export class MailService {
  private transporter: Transporter | null = null;

  private getTransporter(): Transporter {
    if (this.transporter) return this.transporter;

    const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS } = process.env;
    if (!SMTP_HOST || !SMTP_PORT || !SMTP_USER || !SMTP_PASS) {
      throw new AppError(
        "Email sending is not configured on this server. Set SMTP_HOST, SMTP_PORT, " +
          "SMTP_USER, SMTP_PASS and MAIL_FROM in backend/.env — see the comments there for setup notes.",
        503
      );
    }

    this.transporter = nodemailer.createTransport({
      host: SMTP_HOST,
      port: Number(SMTP_PORT),
      secure: Number(SMTP_PORT) === 465,
      auth: { user: SMTP_USER, pass: SMTP_PASS },
    });
    return this.transporter;
  }

  async sendPasswordResetCode(to: string, name: string, code: string) {
    const from = process.env.MAIL_FROM || process.env.SMTP_USER;

    await this.getTransporter().sendMail({
      from: `"Collabro" <${from}>`,
      to,
      subject: "Your Collabro password reset code",
      text:
        `Hi ${name},\n\n` +
        `Your Collabro password reset code is ${code}. It expires in 15 minutes.\n\n` +
        `If you didn't request this, you can safely ignore this email.`,
      html: `
        <div style="font-family: -apple-system, Segoe UI, Roboto, sans-serif; max-width: 480px; margin: 0 auto;">
          <h2 style="color: #2C6E63;">Reset your password</h2>
          <p>Hi ${name},</p>
          <p>Use this code to reset your Collabro password. It expires in <strong>15 minutes</strong>.</p>
          <p style="font-size: 32px; font-weight: 700; letter-spacing: 8px; text-align: center;
                     background: #F1F3EE; border-radius: 8px; padding: 16px 0; margin: 24px 0;">
            ${code}
          </p>
          <p style="color: #5B675F; font-size: 13px;">
            If you didn't request this, you can safely ignore this email.
          </p>
        </div>
      `,
    });
  }
}
