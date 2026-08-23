import type { Request, Response } from "express";
import { responseInterceptor } from "../response.interceptor";

describe("responseInterceptor", () => {
  it("wraps a successful (2xx) json body in the success envelope", () => {
    const originalJson = jest.fn().mockReturnThis();
    const res = { statusCode: 200, json: originalJson } as unknown as Response;
    const req = {} as Request;
    const next = jest.fn();

    responseInterceptor(req, res, next);
    res.json({ id: "1" });

    expect(next).toHaveBeenCalled();
    expect(originalJson).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: { id: "1" },
        timestamp: expect.any(String),
      })
    );
  });

  it("passes an error (>=400) json body through unwrapped", () => {
    const originalJson = jest.fn().mockReturnThis();
    const res = { statusCode: 404, json: originalJson } as unknown as Response;
    const req = {} as Request;
    const next = jest.fn();

    responseInterceptor(req, res, next);
    res.json({ message: "Not found" });

    expect(originalJson).toHaveBeenCalledWith({ message: "Not found" });
  });
});
