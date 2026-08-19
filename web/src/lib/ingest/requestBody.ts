/** The wire shape both ingest routes accept. Shared so the sandbox cannot drift wider. */
import { z } from 'zod';
import { isValidIsoDate } from '@/lib/schedule/dates';

/** 6 MB of base64 is about 4.5 MB of file. Bigger than any schedule email BB&N sends. */
const MAX_BASE64 = 6_000_000;

export const attachmentSchema = z.object({
  mediaType: z.enum(['application/pdf', 'image/png', 'image/jpeg', 'image/gif', 'image/webp']),
  data: z.string().min(1).max(MAX_BASE64),
  filename: z.string().max(200).optional(),
});

export const ingestBodySchema = z.object({
  text: z.string().max(80_000).optional(),
  attachments: z.array(attachmentSchema).max(4).optional(),
  hintDate: z.string().refine(isValidIsoDate, 'hintDate must be YYYY-MM-DD').optional(),
  notes: z.string().max(2000).optional(),
});

export const publishBodySchema = z.object({
  date: z.string().refine(isValidIsoDate, 'date must be YYYY-MM-DD'),
  day: z.unknown(),
});

export type IngestBody = z.infer<typeof ingestBodySchema>;
