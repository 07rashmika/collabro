import { Request, Response, NextFunction } from "express";

export function responseInterceptor(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const originalJson = res.json.bind(res);

  res.json = (body: unknown) => {
    // don't wrap error responses (4xx, 5xx)
    if (res.statusCode >= 400) {
      return originalJson(body);
    }

    return originalJson({
      success: true,
      data: body,
      timestamp: new Date().toISOString(),
    });
  };

  next();
}