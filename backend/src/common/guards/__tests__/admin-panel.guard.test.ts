import type { Request, Response } from "express";
import jwt from "jsonwebtoken";
import { adminPanelGuard, signAdminPanelToken } from "../admin-panel.guard";

function makeRes() {
  const res: Partial<Response> = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res as Response;
}

function makeReq(authHeader?: string): Request {
  return { headers: { authorization: authHeader } } as unknown as Request;
}

describe("adminPanelGuard", () => {
  it("rejects a missing Authorization header", () => {
    const req = makeReq(undefined);
    const res = makeRes();
    const next = jest.fn();

    adminPanelGuard(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it("rejects a malformed Authorization header (no Bearer prefix)", () => {
    const req = makeReq("just-a-token");
    const res = makeRes();
    const next = jest.fn();

    adminPanelGuard(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it("rejects an unparseable/invalid token", () => {
    const req = makeReq("Bearer not-a-real-jwt");
    const res = makeRes();
    const next = jest.fn();

    adminPanelGuard(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ message: "Invalid or expired admin session" });
    expect(next).not.toHaveBeenCalled();
  });

  it("rejects a token signed with a different secret", () => {
    const foreignToken = jwt.sign({ role: "ADMIN_PANEL", email: "a@x.com" }, "wrong-secret");
    const req = makeReq(`Bearer ${foreignToken}`);
    const res = makeRes();
    const next = jest.fn();

    adminPanelGuard(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it("rejects a validly-signed token whose role isn't ADMIN_PANEL", () => {
    const wrongRoleToken = jwt.sign(
      { role: "SOMETHING_ELSE", email: "a@x.com" },
      process.env.ADMIN_JWT_SECRET!
    );
    const req = makeReq(`Bearer ${wrongRoleToken}`);
    const res = makeRes();
    const next = jest.fn();

    adminPanelGuard(req, res, next);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({ message: "Not an admin session" });
    expect(next).not.toHaveBeenCalled();
  });

  it("allows a token minted by signAdminPanelToken through, attaching adminEmail", () => {
    const token = signAdminPanelToken("admin@x.com");
    const req = makeReq(`Bearer ${token}`);
    const res = makeRes();
    const next = jest.fn();

    adminPanelGuard(req, res, next);

    expect(next).toHaveBeenCalled();
    expect(res.status).not.toHaveBeenCalled();
    expect(req.adminEmail).toBe("admin@x.com");
  });
});
