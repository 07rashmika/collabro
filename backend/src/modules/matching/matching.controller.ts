// import { Request, Response } from "express";
// import { MatchingService } from "./matching.service";
// import { MatchingQuerySchema } from "./matching.schema";
// import { ZodError, z } from "zod";

// export class MatchingController {
//   constructor(private readonly matchingService: MatchingService) {}

//   async getSuggestions(req: Request, res: Response) {
//     try {
//       const query = MatchingQuerySchema.parse(req.query);
//       const result = await this.matchingService.getSuggestions(
//         req.user!.sub,
//         query
//       );
//       res.status(200).json(result);
//     } catch (err) {
//       if (err instanceof ZodError) {
//         res.status(400).json({
//           message: "Validation failed",
//           errors: z.treeifyError(err),
//         });
//         return;
//       }
//       res.status(400).json({ message: (err as Error).message });
//     }
//   }

//   async getMatchById(req: Request, res: Response) {
//     try {
//       const result = await this.matchingService.getMatchById(
//         req.user!.sub,
//         req.params.userId as string
//       );
//       res.status(200).json(result);
//     } catch (err) {
//       res.status(404).json({ message: (err as Error).message });
//     }
//   }
// }