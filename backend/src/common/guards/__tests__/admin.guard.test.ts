import type { Request, Response } from "express";
import { adminGuard } from "../admin.guard";

function makeRes() {
  const res: Partial<Response> = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res as Response;
}

describe("adminGuard", () => {
  it("allows an ADMIN caller through", () => {
    const req = { user: { sub: "u1", email: "a@x.com", role: "ADMIN" } } as Request;
    const res = makeRes();
    const next = jest.fn();

    adminGuard(req, res, next);

    expect(next).toHaveBeenCalled();
    expect(res.status).not.toHaveBeenCalled();
  });

  it("rejects a non-admin caller with 403", () => {
    const req = { user: { sub: "u1", email: "a@x.com", role: "STUDENT" } } as Request;
    const res = makeRes();
    const next = jest.fn();

    adminGuard(req, res, next);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({ message: "Access restricted to admins only" });
    expect(next).not.toHaveBeenCalled();
  });

  it("rejects when req.user is missing entirely", () => {
    const req = {} as Request;
    const res = makeRes();
    const next = jest.fn();

    adminGuard(req, res, next);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(next).not.toHaveBeenCalled();
  });
});
