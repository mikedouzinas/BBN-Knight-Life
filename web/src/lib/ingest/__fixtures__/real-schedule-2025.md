# What a real BB&N schedule printout actually contains

Transcribed from a photo of a real Upper School trimester schedule, used as the ground truth
for the HQ-656 scan tests. Every claim the tests in `extractStudentClasses.test.ts` make about
"what a sheet looks like" comes from here rather than from imagination, because the first
version of that prompt was written without one and got three things wrong.

**The photo itself is deliberately not in this repository, and should not be added.** This is a
public repo and that sheet is one identifiable student's timetable. The student's name, their
advisor and the print date are stripped below for the same reason. What the tests need is the
SHAPE of the document, and the shape is all that is here.

## Header

```
Buckingham Browne & Nichols School
<student name> — US Trimester 1
Grade 11
Advisor: <name>
Date Printed: <date>
```

Note **US Trimester 1**. BB&N runs trimesters, so a sheet scanned in September describes the
first third of the year and a student's classes can change at the trimester boundary. Nothing
in the app models that yet; see the open question at the bottom.

## The grid

Five columns, one per weekday, each a list of rows. Every row has a label, a time range, and a
block in parentheses. Rows that are classes also carry a teacher and room on one line.

### Monday
| Row | Time | Block | Teacher and room |
|---|---|---|---|
| Precalculus | 8:15 - 9:00 | A | Ms. Lieberman - 285 |
| AP English Masks | 9:05 - 9:50 | B | Ms. Kornet - 258 |
| Assembly - Special Programs | 9:55 - 10:30 | SP | |
| Physics | 10:35 - 11:20 | C | Ms. Courtemanche - 134 |
| Spanish III | 11:25 - 12:10 | D | Ms. Rose - 380 |
| Lunch-2nd | 12:15 - 12:45 | L2 | |
| United States History (Honors) | 12:50 - 1:55 | E | Mr. Turnbull - 283 |
| Community Activity | 2:00 - 2:35 | CAB | |
| Unscheduled | 2:40 - 3:25 | F | |
| After school | 3:30 - 4:00 | Aft | |

### Tuesday
| Row | Time | Block | Teacher and room |
|---|---|---|---|
| Unscheduled | 8:50 - 9:35 | G | |
| United States History (Honors) | 9:40 - 10:25 | E | Mr. Turnbull - 283 |
| Unscheduled | 10:35 - 11:20 | F | |
| Physics | 11:25 - 12:10 | C | Ms. Courtemanche - 134 |
| Lunch-2nd | 12:15 - 12:45 | L2 | |
| Precalculus | 12:50 - 1:55 | A | Ms. Lieberman - 285 |
| Advisory | 2:00 - 2:35 | Adv | |
| AP English Masks | 2:40 - 3:25 | B | Ms. Kornet - 258 |
| After school | 3:30 - 4:00 | Aft | |

### Wednesday
| Row | Time | Block | Teacher and room |
|---|---|---|---|
| United States History (Honors) | 8:15 - 9:00 | E | Mr. Turnbull - 283 |
| Physics | 9:05 - 10:10 | C | Ms. Courtemanche - 134 |
| Class Mtg | 10:15 | | |
| Spanish III | 10:35 - 11:20 | D | Ms. Rose - 380 |
| Unscheduled | 11:25 - 12:10 | G | |
| Lunch-2nd | 12:15 - 12:45 | L2 | |
| Community Activity | 12:50 - 1:35 | CAB | |

### Thursday
| Row | Time | Block | Teacher and room |
|---|---|---|---|
| Spanish III | 8:15 - 9:00 | D | Ms. Rose - 380 |
| Unscheduled | 9:05 - 10:10 | F | |
| Advisory | 10:15 | | |
| AP English Masks | 10:35 - 11:20 | B | Ms. Kornet - 258 |
| Precalculus | 11:25 - 12:10 | A | Ms. Lieberman - 285 |
| Lunch-2nd | 12:15 - 12:45 | L2 | |
| Unscheduled | 12:50 - 1:55 | G | |
| Community Activity | 2:00 - 2:35 | CAB | |
| United States History (Honors) | 2:40 - 3:25 | E | Mr. Turnbull - 283 |
| After school | 3:30 - 4:00 | Aft | |

### Friday
| Row | Time | Block | Teacher and room |
|---|---|---|---|
| Unscheduled | 8:15 - 9:00 | G | |
| AP English Masks | 9:05 - 10:10 | B | Ms. Kornet - 258 |
| Long Passing | 10:15 | | |
| Precalculus | 10:35 - 11:20 | A | Ms. Lieberman - 285 |
| Unscheduled | 11:25 - 12:10 | F | |
| Lunch-2nd | 12:15 - 12:45 | L2 | |
| Spanish III | 12:50 - 1:55 | D | Ms. Rose - 380 |
| Physics | 2:00 - 2:45 | C | Ms. Courtemanche - 134 |
| Community Activity | 2:50 - 3:25 | CAB | |

## The correct output for this sheet

Five classes, two blank blocks, five lunch waves.

| Block | Subject | Teacher | Room |
|---|---|---|---|
| A | Precalculus | Ms. Lieberman | 285 |
| B | AP English Masks | Ms. Kornet | 258 |
| C | Physics | Ms. Courtemanche | 134 |
| D | Spanish III | Ms. Rose | 380 |
| E | United States History (Honors) | Mr. Turnbull | 283 |
| F | *(blank - free period)* | | |
| G | *(blank - free period)* | | |

Lunch: 2nd on all five weekdays, so `l-d`, `l-c`, `l-g`, `l-a`, `l-f` are all `2nd Lunch`.

## What this sheet taught, and what it did not

**The one real gap: the lunch wave is on the page and there was nowhere to put it.** One row per
weekday, "Lunch-2nd" / "Lunch-1st", sometimes with "(Block L2)". Students have always set these
five by hand in Settings. The original tool had no field for a lunch wave at all, so this was
structural rather than a prompting problem - no amount of prompt tuning would have captured it.

**Two things that looked like bugs and measured clean.** Both were predicted from reading this
sheet, and neither reproduced.

- A free period is printed WITH its block letter ("Unscheduled (Block F)"), and the original
  prompt only said to skip a block "the source does not show" - which is the wrong rule for a
  sheet that shows all seven letters. The expectation was two classes called "Unscheduled".
- Teacher and room arrive fused as `Ms. Lieberman - 285`, and nothing told the model to split
  them.

The original prompt was then run against this sheet four times - once on the anonymised PDF and
three times on the original crooked phone photo. Every run returned the same five classes, no
free periods, and teacher and room correctly split. So these were risks on paper, not observed
failures, and the guards that now exist for them are insurance.

They are still worth the paragraph, because the cost is asymmetric. A class document is keyed by
its display text, so ONE student whose scan emits "Unscheduled" for a free F block creates an
`Unscheduled~~~F` document that every other student with a free F block then joins - one shared
roster across ~645 accounts, needing a manual cleanup to undo. Same for a fused teacher string:
it silently makes a second document for a class that already exists, which is exactly HQ-877's
duplicate problem.

**The thing that made all of the above knowable** is that the prompt can now be run against a
real sheet at all. Before this, every one of the fifty-odd tests around it stubbed the model, so
the prompt itself had never been executed by anything.

## Cross-checks against the app

**The block schedule in the app matches this sheet exactly.** `regularSchedule` in
`defaultVariables.swift` agrees with all five columns, minute for minute: Monday A 8:15-9:00,
B 9:05-9:50, Assembly 9:55-10:30, C 10:35-11:20, and so on. Worth knowing, because the app's
copy is hardcoded and the obvious worry is that it has drifted from what the school prints.

**The lunch pairing agrees too.** `regularSchedule` puts lunch against D on Monday, C on
Tuesday, G on Wednesday, A on Thursday, F on Friday, and the sheet's Monday lunch does sit
either side of D block. The app now derives that pairing from `regularSchedule` rather than
listing it again (`lunchBlockByWeekday()`), so a year in which BB&N moves lunch moves the
Settings rows and the scan together.

**The times also confirm the wave independently.** Under L1, Monday is lunch 11:25-11:55 then
D2 12:00-12:45. Under L2 it is D1 11:25-12:10 then lunch 12:15-12:45. This sheet shows Spanish
III in D at 11:25-12:10, which is the L2 pattern - so the label and the clock agree.

## Still open

- **The sheet is a trimester.** Scanning in September captures Trimester 1 only, and nothing
  prompts a student to rescan when the trimester turns. Not handled.
- **This is one sheet, from one grade, from one year.** It is evidence about the format, not
  proof that every printout looks like this. A 9th-grade sheet, or a sheet with a double period
  or a lab block, may well carry rows this transcription does not.
