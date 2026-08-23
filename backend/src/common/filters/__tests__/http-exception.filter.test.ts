import type { Request, Response } from "express";
import { httpExceptionFilter } from "../http-exception.filter";
import { AppError } from "../../errors/app-error";

function makeRes() {
  const res: Partial<Response> = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res as Response;
}

describe("httpExceptionFilter", () => {
  let consoleErrorSpy: jest.SpyInstance;

  beforeEach(() => {
    consoleErrorSpy = jest.spyOn(console, "error").mockImplementation(() => {});
  });

  afterEach(() => {
    consoleErrorSpy.mockRestore();
  });

  it("maps an AppError to its own status code and message", () => {
    const req = { method: "GET", path: "/notes/1" } as Request;
    const res = makeRes();

    httpExceptionFilter(new AppError("Not found", 404), req, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({ message: "Not found" });
  });

  it("maps a generic Error to a 500 with its message", () => {
    const req = { method: "POST", path: "/notes" } as Request;
    const res = makeRes();

    httpExceptionFilter(new Error("Something broke"), req, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({ message: "Something broke" });
  });

  it("maps a non-Error thrown value to a generic 500 message", () => {
    const req = { method: "POST", path: "/notes" } as Request;
    const res = makeRes();

    httpExceptionFilter("plain string throw", req, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({ message: "Internal server error" });
  });
});
