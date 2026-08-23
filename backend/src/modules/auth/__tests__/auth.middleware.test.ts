import type { Request, Response } from "express";
import { authenticate } from "../auth.middleware";
import { TokenUtil } from "../../../common/utils/token.util";

function makeRes() {
  const res: Partial<Response> = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res as Response;
}

describe("authenticate middleware", () => {
  it("rejects a request with no Authorization header", () => {
    const req = { headers: {} } as Request;
    const res = makeRes();
    const next = jest.fn();

    authenticate(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({
      message: "Missing or malformed Authorization header",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("rejects a malformed Authorization header (no Bearer prefix)", () => {
    const req = { headers: { authorization: "Token abc" } } as Request;
    const res = makeRes();
    const next = jest.fn();

    authenticate(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it("rejects a garbage/invalid access token", () => {
    const req = { headers: { authorization: "Bearer not-a-real-token" } } as Request;
    const res = makeRes();
    const next = jest.fn();

    authenticate(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ message: "Invalid or expired access token" });
    expect(next).not.toHaveBeenCalled();
  });

  it("attaches the decoded payload to req.user and calls next() for a valid token", () => {
    const tokenUtil = new TokenUtil();
    const { accessToken } = tokenUtil.generateTokenPair({
      sub: "u1",
      email: "a@x.com",
      role: "STUDENT",
    });
    const req = { headers: { authorization: `Bearer ${accessToken}` } } as Request;
    const res = makeRes();
    const next = jest.fn();

    authenticate(req, res, next);

    expect(next).toHaveBeenCalled();
    expect(req.user).toMatchObject({ sub: "u1", email: "a@x.com", role: "STUDENT" });
    expect(res.status).not.toHaveBeenCalled();
  });
});
