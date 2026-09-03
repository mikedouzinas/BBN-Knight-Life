/**
 * A real call to the model, on a real BB&N schedule. Skipped unless ANTHROPIC_API_KEY is set,
 * so `npm test` stays offline and free. Same pattern as extract.live.test.ts.
 *
 *   ANTHROPIC_API_KEY=... npx vitest run src/lib/ingest/extractStudentClasses.live.test.ts
 *
 * THIS IS THE TEST THAT WAS MISSING, and its absence is the whole reason HQ-656 needed
 * rewriting. The offline suite next door has fifty-odd cases and every one of them stubs the
 * model, so all of them passed while the prompt itself was wrong about three separate things.
 * A stubbed test proves the plumbing around a prompt. Only this proves the prompt.
 *
 * The fixture is the real Grade 11 sheet with the student's name, advisor and print date
 * removed, rendered to a PDF - see __fixtures__/real-schedule-2025.md for the full
 * transcription and what it taught. The original photo is deliberately not in this public
 * repository: it is one identifiable student's timetable.
 *
 * What this does NOT cover is reading a crooked phone photo, which is how a student will
 * actually use the feature. It covers the harder-to-get-right half - deciding what on the page
 * is a class, what is a free period, and what is lunch.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { extractStudentClasses } from './extractStudentClasses';

const live = process.env.ANTHROPIC_API_KEY ? describe : describe.skip;

/**
 * The real sheet, anonymised and rendered to a PDF - a supported input, so this goes through
 * exactly the path a student's upload does rather than around it.
 *
 * A PDF rather than the original photo on purpose: the photo is one identifiable student's
 * timetable and this repo is public. The format is what is under test, and the format survives
 * the anonymisation - "Unscheduled (Block F)", "Lunch-2nd (Block L2)", "Ms. Lieberman - 285"
 * are all still there.
 */
const SHEET = readFileSync(join(__dirname, '__fixtures__', 'real-schedule-anonymised.pdf')).toString('base64');

live('extractStudentClasses against the live model', () => {
  it(
    'reads the real sheet as five classes, two frees and five lunch waves',
    { timeout: 180_000 },
    async () => {
      const result = await extractStudentClasses({
        attachments: [{ mediaType: 'application/pdf', data: SHEET }],
      });

      const byBlock = Object.fromEntries(result.classes.map((c) => [c.block, c]));

      // 1. Five classes, and exactly five.
      expect(Object.keys(byBlock).sort()).toEqual(['a', 'b', 'c', 'd', 'e']);

      // 2. Nothing called Unscheduled anywhere. This is the failure that would have put every
      //    student with a free F block onto one shared roster.
      expect(result.classes.some((c) => /unscheduled/i.test(c.subject))).toBe(false);
      expect(byBlock.f).toBeUndefined();
      expect(byBlock.g).toBeUndefined();

      // 3. Lunch is read, per weekday, and this student is second wave on all five.
      expect(result.lunch).toEqual({
        monday: 2,
        tuesday: 2,
        wednesday: 2,
        thursday: 2,
        friday: 2,
      });

      // 4. Teacher and room come out split, not fused. A fused "Ms. Lieberman - 285" makes a
      //    different class document than the split version, which is how duplicates start.
      expect(byBlock.a.teacher).toMatch(/Lieberman/);
      expect(byBlock.a.room).toBe('285');
      expect(byBlock.a.teacher).not.toMatch(/285/);
      expect(byBlock.e.teacher).toMatch(/Turnbull/);
      expect(byBlock.e.room).toBe('283');

      // 5. Subjects are transcribed, not expanded or tidied.
      expect(byBlock.b.subject).toBe('AP English Masks');
      expect(byBlock.e.subject).toBe('United States History (Honors)');

      // 6. No retries were needed, which is what the budget is spent on.
      expect(result.rejected).toEqual([]);
    },
  );
});
