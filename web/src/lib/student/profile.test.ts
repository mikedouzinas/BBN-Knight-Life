import { describe, expect, it } from 'vitest';
import { parseTime12 } from '@/lib/schedule/time';
import type { ScheduleDay } from '@/lib/schedule/types';
import {
  isEmptyProfile,
  normalizeWave,
  nowAndNext,
  profileFromUserDoc,
  renderForStudent,
  type StudentProfile,
} from './profile';

/** A day where lunch splits D: 1st lunch eats, 2nd lunch is in D, and then they swap. */
const SPLIT_DAY: ScheduleDay = {
  type: 'blocks',
  blocks: [
    { type: 'block', block: 'a', name: 'A', startTime: '8:15 am', endTime: '9:00 am' },
    {
      type: 'specific',
      filter: ['L1'],
      matchMode: 'any',
      lunchBlock: 'd',
      contents: [{ type: 'lunch', startTime: '11:25 am', endTime: '11:55 am' }],
    },
    {
      type: 'specific',
      filter: ['L2'],
      matchMode: 'any',
      lunchBlock: 'd',
      contents: [{ type: 'block', block: 'd', name: 'D', startTime: '11:25 am', endTime: '11:55 am' }],
    },
  ],
};

function profile(overrides: Partial<StudentProfile> = {}): StudentProfile {
  return {
    classes: {},
    rooms: {},
    advisoryRoom: '',
    grade: null,
    lunchByBlock: {},
    ...overrides,
  };
}

describe('normalizeWave', () => {
  it('reads the strings the app actually writes', () => {
    expect(normalizeWave('1st Lunch')).toBe('L1');
    expect(normalizeWave('2nd Lunch')).toBe('L2');
  });

  it('treats "Not Set" and empty as unset', () => {
    // "Not Set" is a literal the app writes. Reading it as a wave hides half the day.
    expect(normalizeWave('Not Set')).toBeNull();
    expect(normalizeWave('')).toBeNull();
    expect(normalizeWave(undefined)).toBeNull();
  });
});

describe('renderForStudent lunch waves', () => {
  it('picks the wave by the block lunch splits, not by a single per-student wave', () => {
    const first = renderForStudent(SPLIT_DAY, profile({ lunchByBlock: { d: 'L1' } }));
    expect(first.map((r) => r.name)).toEqual(['A', 'Lunch']);

    const second = renderForStudent(SPLIT_DAY, profile({ lunchByBlock: { d: 'L2' } }));
    expect(second.map((r) => r.name)).toEqual(['A', 'D']);
  });

  it('reads a different wave for a different split block on the same student', () => {
    // This is the case a single `lunchWave` field cannot represent, and the reason this
    // module exists rather than reusing renderForAudience.
    const student = profile({ lunchByBlock: { d: 'L1', e: 'L2' } });
    const splitsE: ScheduleDay = {
      type: 'blocks',
      blocks: [
        {
          type: 'specific', filter: ['L1'], matchMode: 'any', lunchBlock: 'e',
          contents: [{ type: 'lunch', startTime: '12:00 pm', endTime: '12:30 pm' }],
        },
        {
          type: 'specific', filter: ['L2'], matchMode: 'any', lunchBlock: 'e',
          contents: [{ type: 'block', block: 'e', name: 'E', startTime: '12:00 pm', endTime: '12:30 pm' }],
        },
      ],
    };
    expect(renderForStudent(SPLIT_DAY, student).map((r) => r.name)).toEqual(['A', 'Lunch']);
    expect(renderForStudent(splitsE, student).map((r) => r.name)).toEqual(['E']);
  });

  it('shows both waves when the student has no wave for that block', () => {
    const rows = renderForStudent(SPLIT_DAY, profile());
    expect(rows.map((r) => r.name)).toEqual(['A', 'Lunch', 'D']);
  });
});

describe('renderForStudent grade filtering', () => {
  const gradeDay: ScheduleDay = {
    type: 'blocks',
    blocks: [{
      type: 'specific', filter: ['9', '10'], matchMode: 'any',
      contents: [{ type: 'block', block: 'other', name: 'Class Meeting', startTime: '10:00 am', endTime: '10:30 am' }],
    }],
  };

  it('hides a group aimed at other grades', () => {
    expect(renderForStudent(gradeDay, profile({ grade: '12' }))).toHaveLength(0);
  });

  it('shows every grade group when the student has no grade set', () => {
    expect(renderForStudent(gradeDay, profile({ grade: null }))).toHaveLength(1);
  });
});

describe('renderForStudent class names', () => {
  it('attaches the student class name to its block', () => {
    const rows = renderForStudent(SPLIT_DAY, profile({ classes: { A: 'AP Physics' }, rooms: { A: '212' } }));
    expect(rows[0]).toMatchObject({ block: 'A', className: 'AP Physics', room: '212' });
  });

  it('leaves the block letter alone when no class is set', () => {
    const rows = renderForStudent(SPLIT_DAY, profile());
    expect(rows[0].className).toBeUndefined();
    expect(rows[0].name).toBe('A');
  });

  it('does not let a stored room override one published on the event', () => {
    const day: ScheduleDay = {
      type: 'blocks',
      blocks: [{ type: 'block', block: 'a', name: 'A', startTime: '8:15 am', endTime: '9:00 am', room: 'Gym' }],
    };
    expect(renderForStudent(day, profile({ rooms: { A: '212' } }))[0].room).toBe('Gym');
  });
});

describe('profileFromUserDoc', () => {
  it('reads the shipped field names', () => {
    const p = profileFromUserDoc({
      A: 'AP Physics', B: '', grade: '11', 'l-d': '1st Lunch', 'room-advisory': '305',
    });
    expect(p.classes).toEqual({ A: 'AP Physics' });
    expect(p.grade).toBe('11');
    expect(p.lunchByBlock.d).toBe('L1');
    expect(p.advisoryRoom).toBe('305');
  });

  it('reports an untouched account as empty', () => {
    expect(isEmptyProfile(profileFromUserDoc({}))).toBe(true);
    expect(isEmptyProfile(profileFromUserDoc({ A: 'History' }))).toBe(false);
  });
});

describe('nowAndNext', () => {
  const rows = renderForStudent(SPLIT_DAY, profile({ lunchByBlock: { d: 'L2' } }));

  it('finds the block in progress', () => {
    const { current, next } = nowAndNext(rows, 8 * 60 + 30, parseTime12);
    expect(current?.name).toBe('A');
    expect(next?.name).toBe('D');
  });

  it('reports only what is next when nothing is in progress', () => {
    const { current, next } = nowAndNext(rows, 7 * 60, parseTime12);
    expect(current).toBeNull();
    expect(next?.name).toBe('A');
  });

  it('reports nothing after the last block ends', () => {
    const { current, next } = nowAndNext(rows, 23 * 60, parseTime12);
    expect(current).toBeNull();
    expect(next).toBeNull();
  });
});
