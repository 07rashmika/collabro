import type { Request, Response } from "express";
import { z } from "zod";
import { validate } from "../validation.pipe";

function makeRes() {
  const res: Partial<Response> = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res as Response;
}

const schema = z.object({ email: z.string().email(), age: z.number().min(0) });

describe("validate", () => {
  it("parses a valid body onto req.body and calls next()", () => {
    const req = { body: { email: "a@x.com", age: 20 } } as Request;
    const res = makeRes();
    const next = jest.fn();

    validate(schema)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.body).toEqual({ email: "a@x.com", age: 20 });
  });

  it("responds 400 with treeified errors for an invalid body", () => {
    const req = { body: { email: "not-an-email", age: -1 } } as Request;
    const res = makeRes();
    const next = jest.fn();

    validate(schema)(req, res, next);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ message: "Validation failed" })
    );
    expect(next).not.toHaveBeenCalled();
  });

  it("passes a non-Zod error through to next()", () => {
    const throwingSchema = {
      parse: () => {
        throw new Error("boom");
      },
    } as unknown as z.ZodSchema;
    const req = { body: {} } as Request;
    const res = makeRes();
    const next = jest.fn();

    validate(throwingSchema)(req, res, next);

    expect(next).toHaveBeenCalledWith(expect.any(Error));
    expect(res.status).not.toHaveBeenCalled();
  });
});
