/**
 * A real call to the model, on a real BB&N schedule. Skipped unless ANTHROPIC_API_KEY is set,
 * so `npm test` stays offline and free. Same pattern as extract.live.test.ts.
 *
 *   ANTHROPIC_API_KEY=... npx vitest run src/lib/ingest/extractStudentClasses.live.test.ts
 *
 * THIS IS THE TEST THAT WAS MISSING. The offline suite next door has sixty-odd cases and every
 * one of them stubs the model, so all of them passed while the prompt had no way to report a
 * lunch wave at all. A stubbed test proves the plumbing around a prompt. Only this proves the
 * prompt.
 *
 * It is also what kept the rest of this honest: two further failures were predicted from
 * reading the sheet - free periods being read as courses, and a fused "Ms. Lieberman - 285" -
 * and running the OLD prompt here four times showed the model getting both right every time.
 * Those guards stayed, as guards rather than repairs.
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
    'reads the real sheet as five courses, two frees, five lunch waves and a grade',
    { timeout: 180_000 },
    async () => {
      const result = await extractStudentClasses({
        attachments: [{ mediaType: 'application/pdf', data: SHEET }],
      });

      const byBlock = Object.fromEntries(result.classes.map((c) => [c.block, c]));

      // 1. All seven blocks accounted for: five courses and two frees.
      expect(Object.keys(byBlock).sort()).toEqual(['a', 'b', 'c', 'd', 'e', 'f', 'g']);

      // 2. The blocks the sheet marks "Unscheduled" come back as free, under the canonical
      //    spelling. The sheet's own wording must never survive, because the subject is part
      //    of the document id - "Unscheduled" would start a second roster beside "Free".
      expect(byBlock.f.subject).toBe('Free');
      expect(byBlock.g.subject).toBe('Free');
      expect(result.classes.some((c) => /unscheduled/i.test(c.subject))).toBe(false);

      // 3. A free block carries no teacher and no room, or the roster splits by whatever the
      //    model happened to attach to it.
      expect(byBlock.f.teacher).toBeUndefined();
      expect(byBlock.f.room).toBeUndefined();

      // 4. Lunch, advisory, assembly and community activity all carry block-shaped labels on
      //    this sheet (L2, Adv, SP, CAB). None of them is one of the student's seven blocks.
      expect(result.skipped).toEqual([]);
      for (const c of result.classes) {
        expect(c.subject).not.toMatch(/lunch|advisory|assembly|community|passing|after school/i);
      }

      // 5. Grade comes off the header. This sheet says Grade 11.
      expect(result.details.grade).toBe('11');

      // 6. Lunch is read, per weekday, and this student is second wave on all five.
      expect(result.lunch).toEqual({
        monday: 2,
        tuesday: 2,
        wednesday: 2,
        thursday: 2,
        friday: 2,
      });

      // 7. Teacher and room come out split, not fused. A fused "Ms. Lieberman - 285" makes a
      //    different class document than the split version, which is how duplicates start.
      expect(byBlock.a.teacher).toMatch(/Lieberman/);
      expect(byBlock.a.room).toBe('285');
      expect(byBlock.a.teacher).not.toMatch(/285/);
      expect(byBlock.e.teacher).toMatch(/Turnbull/);
      expect(byBlock.e.room).toBe('283');

      // 8. Subjects are transcribed, not expanded or tidied.
      expect(byBlock.b.subject).toBe('AP English Masks');
      expect(byBlock.e.subject).toBe('United States History (Honors)');

      // 9. No retries were needed, which is what the budget is spent on.
      expect(result.rejected).toEqual([]);
    },
  );
});
