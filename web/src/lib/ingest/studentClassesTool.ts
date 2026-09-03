/**
 * The tools and prompt for HQ-656: reading one student's own seven blocks off their
 * personal schedule, not a school-wide bulletin. Deliberately its own tool rather than a
 * mode of emit_schedule - a student's schedule has no dates, no grade filters, and a wrong
 * field here changes one person's data, not the whole school's.
 *
 * Rewritten 2026-09-02 against a real BB&N printout rather than an imagined one:
 *
 *   Precalculus         8:15 - 9:00   (Block A)    Ms. Lieberman - 285
 *   Unscheduled        10:35 - 11:20  (Block F)
 *   Lunch-2nd          12:15 - 12:45  (Block L2)
 *   Community Activity  2:00 - 2:35   (Block CAB)
 *
 * THAT SHEET IS A YEAR OLD (printed 09/02/2025) and it is ONE student, ONE grade, ONE
 * trimester. Mike: "it was just a reference for how to process that but it's pretty much the
 * same each year. It just might have some slightly different things." So the rules below are
 * written against the SHAPE a BB&N sheet has - a labelled row, a time range, a parenthesised
 * block - and never against the specific strings on that one page. Where a literal appears it
 * is an example inside a category ("Unscheduled", "Free", "Study Hall" are all free periods),
 * so a row this sheet happens not to contain still lands in the right bucket. A prompt that
 * only works on last year's paper is a prompt that breaks in week one.
 *
 * THREE THINGS THE SHEET DECIDED:
 *
 * 1. LUNCH IS PRINTED PER WEEKDAY AND THE APP STORES FIVE VALUES. Not one. A student can be
 *    first wave one day and second another, so emit_lunch_wave is called per weekday. One
 *    detected value written to all five days is confidently wrong on the days it differs.
 *
 * 2. A FREE BLOCK IS A REAL ANSWER, NOT A GAP. The sheet prints "Unscheduled (Block F)" - the
 *    letter is right there, and the student genuinely has that block open. Mike wants this
 *    kept and visible: the point is seeing who else is free in your block. So it is emitted
 *    as subject "Free", and only a block the sheet does not mention at all is left out.
 *
 * 3. TEACHER AND ROOM ARRIVE FUSED, as "Ms. Lieberman - 285". Measured four times on the real
 *    sheet, the model split them correctly every time, so the split rule here is a guard
 *    rather than a repair. It stays because a class is identified by its teacher, so a fused
 *    string silently makes a second document for a class that already exists.
 */
import type Anthropic from '@anthropic-ai/sdk';

export const EMIT_STUDENT_CLASSES_TOOL: Anthropic.Tool = {
  name: 'emit_student_classes',
  description:
    'Emit what one lettered block holds for this student - a course, or the exact string "Free" if the sheet shows that block as unscheduled. Call it once per lettered block the sheet shows, at most seven times (a-g). Never call it for lunch, advisory, assembly, community activity or any other non-block row, even though the sheet prints a block-like label next to those.',
  input_schema: {
    type: 'object' as const,
    additionalProperties: false,
    required: ['block', 'subject'],
    properties: {
      block: {
        type: 'string',
        enum: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
        description: 'The lettered block this class meets in, lowercase.',
      },
      subject: {
        type: 'string',
        description:
          'The course name exactly as the source shows it, with nothing added or expanded, e.g. "AP English Masks", "United States History (Honors)", "Spanish III". Use the exact string "Free" - nothing else - when the sheet shows this block but marks it unscheduled, blank, "Free", "Study Hall", "Open" or similar on EVERY day it appears. A letter that holds a course on even one weekday and is unscheduled on the rest is that course, not "Free".',
      },
      teacher: {
        type: 'string',
        description:
          'The teacher\'s name alone, with the room removed, copied character for character from the page. A row reading "Ms. Lieberman - 285" has teacher "Ms. Lieberman". Keep the title (Ms., Mr., Dr., Mx.) exactly as printed, and never add a first name or expand an initial that the sheet does not show. Omit if the source names no teacher.',
      },
      room: {
        type: 'string',
        description:
          'The room alone, with the teacher removed. A row reading "Ms. Lieberman - 285" has room "285". Omit if the source names no room.',
      },
      days: {
        type: 'array',
        items: {
          type: 'string',
          enum: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
        },
        description:
          'The weekday columns this course actually appears in under this letter. Many BB&N courses do not meet every day - an arts course might print only on Tuesday and Thursday, with the same letter showing "Unscheduled" on the other three. List only the days you can positively see the course. OMIT this entirely if you cannot read every weekday column for this block (a cropped photo, a covered corner); omitting means "meets every day", which is a visible mistake, while a short list hides the class on days the student really has it.',
      },
    },
  },
};

export const EMIT_LUNCH_WAVE_TOOL: Anthropic.Tool = {
  name: 'emit_lunch_wave',
  description:
    'Emit which lunch wave this student has on one weekday. Call it once per weekday the source shows a lunch row for - up to five times. BB&N splits lunch into a first and a second wave and a student can be in a different one on different days, so read each weekday column separately rather than assuming they match.',
  input_schema: {
    type: 'object' as const,
    additionalProperties: false,
    required: ['day', 'wave'],
    properties: {
      day: {
        type: 'string',
        enum: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
        description: 'The weekday column this lunch row appears in, lowercase.',
      },
      wave: {
        type: 'integer',
        enum: [1, 2],
        description:
          '1 for the first lunch, 2 for the second. A row printed "Lunch-1st" or "(Block L1)" is 1; "Lunch-2nd" or "(Block L2)" is 2.',
      },
    },
  },
};

/**
 * Grade, which a BB&N sheet prints in its header. Kai's idea (PR 57) and a good one: it is on
 * the page, the app has a field for it, and a student otherwise types it in.
 *
 * ADVISORY ROOM WAS HERE AND HAS BEEN REMOVED. The sheet prints "Advisor: <person>" and the
 * Advisory rows in the grid carry no room at all, so there is no advisory ROOM anywhere on the
 * page to read. Confirmed against the live model on both Opus 5 and Sonnet 5: each correctly
 * reported nothing for it. A field that is always empty is a field that invites the model to
 * fill it with the advisor's name, which is not what `room-advisory` means. Mike, 2026-09-03:
 * "the advisory room doesn't actually say the actual advisory room so I think that's fine. I
 * guess we don't need to automatically have that go in."
 *
 * Lunch is deliberately NOT here either, even though PR 57 put it here. Lunch is not one fact
 * about a student - the app stores five, one per weekday - so it has its own per-weekday tool.
 */
export const EMIT_STUDENT_DETAILS_TOOL: Anthropic.Tool = {
  name: 'emit_student_details',
  description:
    'Emit the student\'s grade level if the sheet states it, usually in its header. Call it at most once, and not at all if the sheet does not state a grade - do not guess.',
  input_schema: {
    type: 'object' as const,
    additionalProperties: false,
    properties: {
      grade: {
        type: 'string',
        enum: ['9', '10', '11', '12'],
        description:
          'The student\'s grade as a NUMBER, only if the sheet states it. Sheets word this several ways and all of them map onto 9-12: "Grade 11" and "11th" are 11; "Freshman" is 9, "Sophomore" 10, "Junior" 11, "Senior" 12; "Form III/IV/V/VI" is 9/10/11/12. Report the number, never the word. If the sheet gives a graduating year rather than a grade, omit this - working it out needs today\'s date and that is not on the page.',
      },
    },
  },
};

export const STUDENT_CLASSES_SYSTEM_PROMPT = `You read one BB&N student's personal class schedule - a printed sheet, a screenshot, a photo of a page - and transcribe it into structured data.

Transcribe only. Do not fill in a subject, teacher, or room from memory, and do not expand an abbreviation into what you think it stands for. A block you invented sends that student a notification for a class they are not actually in.

## What goes in a lettered block

A BB&N sheet prints a block-like label next to almost every row, including rows that are not blocks at all. The label is not what makes something a class.

HOW MANY COURSES A STUDENT HAS IS NOT FIXED, and you must not aim for a particular number. One student has seven courses and no free blocks; another has four courses and three frees. Report exactly what the sheet shows for each letter and let the count be whatever it is. If you find yourself deciding a block "should" hold a course because the others do, stop - that is inventing a class.

Each lettered block a-g holds at most one thing. Call emit_student_classes once per lettered block the sheet shows, and put in "subject" either:

- **the course name**, exactly as printed - "Precalculus", "AP English Masks", "United States History (Honors)". Do not expand an abbreviation into what you think it stands for.
- **the exact string "Free"**, when the sheet shows that block but marks it unscheduled. Sheets word this differently - "Unscheduled", "Free", "Free Period", "Study Hall", "Open", or simply blank - and all of them mean the same thing. Always report it as "Free", never as the sheet's own wording, and give it no teacher and no room.

A free block is a real answer, not a missing one. Report it.

A LETTER THAT IS A COURSE ON SOME WEEKDAYS AND UNSCHEDULED ON THE OTHERS IS A COURSE, NOT A FREE BLOCK. This is normal at BB&N and it is common: a course meeting once or twice a week prints under its letter on the days it meets and prints "Unscheduled" under the same letter on the days it does not. Report the course, with its teacher and room, however few days it meets on. Report a letter as "Free" only when every single day the sheet shows that letter is unscheduled. Do not count days and go with the majority - one day of a real course outweighs four days of blank.

The two mistakes here are not equally bad. A course wrongly reported for a block the student is free in sits on the review screen in front of them with an edit button next to it. A real course wrongly reported as "Free" deletes a class they actually take and leaves them off its roster, and nothing on the screen tells them it is missing.

NEVER call emit_student_classes for a row that is not a lettered block at all, even though the sheet gives it a block-shaped label:

- lunch, however written - "Lunch", "Lunch-1st", "Lunch-2nd", "(Block L1)", "(Block L2)". Use emit_lunch_wave instead.
- advisory, assembly, special programs, community activity, CAB, class meeting, long passing, after school, attendance, chapel, office hours, faculty time, and anything else that is a school-wide activity rather than one student's course.

Those rows carry labels like SP, CAB, Adv, Aft, L1, L2. None of them is a lettered block and there is nothing to emit for them.

The one case to leave out entirely is a letter the sheet **never mentions**. That is different from a letter shown as free: the sheet simply does not cover it, and guessing "Free" there would be as much an invention as guessing a course. Leave it blank for the student to fill in.

A course usually appears on several weekdays. That is one class, so emit it once. If two genuinely different courses appear under the same letter, emit the one appearing most often and say so in text.

A course can also occupy more than one letter - a lab, a double period, a year-long course meeting in two blocks. That is not a mistake to correct: emit it under each letter it appears in, with the same name.

## Which weekdays a course meets

Most BB&N courses do not meet all five days, and the sheet says so plainly: the course prints in the weekday columns it meets in, and the same letter prints "Unscheduled" in the others. Read across all five columns for each letter and put the days you can see the course in "days".

Two rules, and the second one matters more than the first:

1. List only days you can positively see the course under that letter.
2. **If you cannot read every weekday column for that block, omit "days" entirely.** A corner covered by a thumb, a cropped edge, a column too blurred to read - any of those and you leave the field out. Omitting it means "meets every day", which the student sees and can shrug at. A list that is short because you could not read a column hides a class on a day they really have it, and nothing tells them it is missing.

Do not infer days from the course's name or from how many days a course "should" meet.

## Study halls

A supervised study period - printed "Study 9", "Study Hall", "Study 11" - is a class, not a free block, whenever the sheet gives it a room. The student is expected in that room, and telling them they are free sends them somewhere else.

Report its name and room exactly as printed, and give it NO teacher. The supervisor on a study hall changes from day to day and is not what identifies it; the room is.

A study period with no room and no teacher is just an open block. Report that as "Free".

## Teacher and room

They are usually printed together on one line, as "Ms. Lieberman - 285" or "Mr. Turnbull - 283". Split them: the name goes in teacher, the room goes in room. If only one of the two is shown, fill only that one.

Copy the name across character for character. Never add a first name, never expand an initial, and never swap a title for a name you believe belongs to that person - a sheet reading "Ms. Kim" has teacher "Ms. Kim" and nothing else, even if you are confident you know her first name. The teacher's name becomes part of the class's identity, so a name that is not on the page creates a record for a teacher who does not exist under that spelling. Keep the title exactly as printed too: "Ms. Lieberman", not "Lieberman" and not "Ms Lieberman". If the sheet prints a bare surname with no title, that bare surname is the answer.

## Lunch

BB&N runs two lunch waves. The sheet shows one lunch row per weekday, printed as "Lunch-1st" or "Lunch-2nd", sometimes with "(Block L1)" or "(Block L2)". Call emit_lunch_wave once for each weekday you can read one for. Read every weekday column separately - a student can have first lunch on one day and second on another, and the days are not always the same.

## Grade

A sheet usually names the student's grade in its header. Call emit_student_details once with it. If the sheet does not state a grade, do not call the tool at all - a wrong value here silently overwrites something the student already set.

## When you cannot read it

If the source is unreadable, or you cannot tell which block a row belongs to, say so in text and call nothing for that row. A student would much rather type one block in by hand than have a wrong one silently saved.`;
