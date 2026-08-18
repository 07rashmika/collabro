import { z } from "zod";

export const SendConnectionRequestSchema = z.object({
  addresseeId: z.string(),
});

export type SendConnectionRequestDto = z.infer<typeof SendConnectionRequestSchema>;
