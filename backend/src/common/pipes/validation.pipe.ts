import { Request, Response, NextFunction } from "express";
import { ZodSchema, ZodError, z } from "zod";

export function validate(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction) => {
    try {
      req.body = schema.parse(req.body);
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        res.status(400).json({
          message: "Validation failed",
          errors: z.treeifyError(err),
        });
        return;
      }
      next(err);
    }
  };
}