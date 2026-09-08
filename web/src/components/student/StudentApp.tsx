'use client';

/**
 * Knight Life on the web.
 *
 * Phones are banned in class and in the hallways at BB&N, which removed the app's only
 * surface during exactly the hours it is for. This is the same schedule on whatever device
 * is already open in front of the student.
 *
 * The design answers ONE question first: what do I have right now, and what room. A student
 * reads this while walking, in a four-minute passing period, so the current block is the only
 * filled surface on the page and it is set large. Everything else is quiet rows on hairlines.
 * The first version made every element the same size inside identical cards, which left the
 * eye no entry point at all.
 *
 * Past blocks dim and the current row carries a marker, because a school day genuinely is a
 * sequence in time, and "where am I in it" is information worth drawing rather than decoration.
 */
import { useCallback, useEffect, useMemo, useState } from 'react';
import { withBasePath } from '@/lib/basePath';
import { clientAuth, firebaseConfigured, signInWithGoogle, signOutOfGoogle } from '@/lib/firebase/client';
import { Glow } from '@/components/Glow';
import { parseTime12 } from '@/lib/schedule/time';
import { BLOCK_LETTERS, nowAndNext, type BlockLetter, type StudentRow } from '@/lib/student/profile';

interface DayPayload {
  date: string;
  label: string;
  source: string;
  closed: boolean;
  reason: string | null;
  imageUrl: string | null;
  rows: StudentRow[];
}

interface DayResponse {
  setUp: boolean;
  grade: string | null;
  today: DayPayload;
  week: DayPayload[];
}

interface CatalogueEntry {
  id: string;
  name: string;
  block: BlockLetter;
  teacher: string;
  room: string;
  period: string;
}

/** Today where the student is standing. The server runs in UTC and must not guess this. */
function localToday(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}

function minutesNow(): number {
  const now = new Date();
  return now.getHours() * 60 + now.getMinutes();
}

/** "9:55 am" -> "9:55". The suffix is noise in a column that is obviously a school day. */
function bare(time: string): string {
  return time.replace(/\s*[ap]\.?m\.?$/i, '');
}

function shortDay(label: string): string {
  return label.split(',')[0].slice(0, 3);
}

/** What a student calls this row: their own class name if they set one. */
function rowLabel(row: StudentRow): string {
  return row.className ?? row.name;
}

function isLunch(row: StudentRow): boolean {
  return row.name.toLowerCase().includes('lunch');
}

export function StudentApp() {
  const [token, setToken] = useState<string | null>(null);
  const [signingIn, setSigningIn] = useState(false);
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [date, setDate] = useState(localToday());
  const [data, setData] = useState<DayResponse | null>(null);
  const [editing, setEditing] = useState(false);
  const [clock, setClock] = useState(minutesNow());

  const configured = firebaseConfigured();
  const isToday = date === localToday();

  // Keep the session across a refresh. Firebase restores it asynchronously, so `ready` gates
  // the sign-in screen: without it the page flashes "Sign in" at someone already signed in.
  useEffect(() => {
    if (!configured) { setReady(true); return; }
    return clientAuth().onIdTokenChanged(async (user) => {
      setToken(user ? await user.getIdToken() : null);
      setReady(true);
    });
  }, [configured]);

  // The countdown moves on its own. A student watching through a passing period should see it
  // advance without touching anything. Every 20s, so "1 min left" is honest when it says it.
  useEffect(() => {
    const id = setInterval(() => setClock(minutesNow()), 20_000);
    return () => clearInterval(id);
  }, []);

  const load = useCallback(async (authToken: string, iso: string) => {
    setError(null);
    const res = await fetch(withBasePath(`/api/student/day?date=${iso}`), {
      headers: { authorization: `Bearer ${authToken}` },
    });
    const body = await res.json();
    if (!res.ok) { setError(body.error ?? 'Could not load your schedule.'); return; }
    setData(body as DayResponse);
    if (!body.setUp) setEditing(true);
  }, []);

  useEffect(() => {
    if (token) void load(token, date);
  }, [token, date, load]);

  async function signIn() {
    setSigningIn(true);
    setError(null);
    try {
      setToken(await signInWithGoogle());
    } catch (e) {
      const code = (e as { code?: string }).code;
      setError(
        code === 'auth/popup-blocked'
          ? 'Your browser blocked the sign-in window. Allow pop-ups for this page, then try again.'
          : code === 'auth/popup-closed-by-user'
            ? 'The sign-in window closed before it finished. Try again.'
            : (e as Error).message,
      );
    } finally {
      setSigningIn(false);
    }
  }

  if (!configured) {
    return <p className="kl-note">This deployment has no Firebase configuration, so sign-in is off.</p>;
  }
  if (!ready) return <p className="kl-note">Checking your sign-in.</p>;
  if (!token) return <SignIn onSignIn={signIn} busy={signingIn} error={error} />;

  // Two modes, never both. Editing is a full takeover rather than a panel that opens inside
  // the schedule: a student who is halfway through changing their classes must not be looking
  // at a schedule built from the old ones, and the two read as different screens on purpose.
  if (editing && token) {
    return (
      <div className="kl kl-mode-edit">
        {error && <p className="kl-error">{error}</p>}
        <ClassSetup
          token={token}
          canCancel={Boolean(data?.setUp)}
          onDone={() => { setEditing(false); void load(token, date); }}
        />
      </div>
    );
  }

  return (
    <div className="kl kl-mode-view">
      {error && <p className="kl-error">{error}</p>}

      {data ? (
        <>
          {isToday && !data.today.closed && data.today.rows.length > 0 && (
            <Headline day={data.today} clock={clock} />
          )}

          <DaySheet
            day={data.today}
            week={data.week}
            clock={clock}
            isToday={isToday}
            onPick={setDate}
            onToday={() => setDate(localToday())}
          />

          <Footer token={token} from={date} onEdit={() => setEditing(true)} />
        </>
      ) : (
        <p className="kl-note">Loading your day.</p>
      )}
    </div>
  );
}

/* ---------- sign in ------------------------------------------------------ */

function SignIn({ onSignIn, busy, error }: { onSignIn: () => void; busy: boolean; error: string | null }) {
  return (
    <div className="kl">
      <section className="kl-hero kl-hero-quiet kl-signin">
        <Glow size={140} intensity={0.09} color="255, 214, 130" />
        <p className="kl-hero-class">Your schedule,<br />on any screen.</p>
        <p className="kl-signin-body">
          Sign in with the Google account you use in the Knight Life app and your classes come with you.
        </p>
        <button type="button" className="kl-primary" onClick={onSignIn} disabled={busy}>
          {busy ? 'Opening Google' : 'Sign in with Google'}
        </button>
        {error && <p className="kl-error">{error}</p>}
        <p className="kl-note">A personal Google account works too.</p>
      </section>
    </div>
  );
}

/* ---------- the answer --------------------------------------------------- */

/**
 * What is happening right now, or what is next, or that the day is over.
 *
 * The room number is set nearly as large as the class name, because in week one the room is
 * the half a student has not memorised and it is the reason they are looking at this at all.
 */
function Headline({ day, clock }: { day: DayPayload; clock: number }) {
  const { current, next } = useMemo(() => nowAndNext(day.rows, clock, parseTime12), [day.rows, clock]);

  const firstStart = day.rows.length ? parseTime12(day.rows[0].startTime) : null;
  const beforeSchool = firstStart !== null && clock < firstStart;

  if (!current && !next) {
    return (
      <section className="kl-hero kl-hero-quiet">
        <p className="kl-hero-class">{beforeSchool ? 'School has not started yet.' : "You're done for today."}</p>
        {beforeSchool && day.rows[0] && (
          <p className="kl-hero-then">
            First up is {rowLabel(day.rows[0])} at {bare(day.rows[0].startTime)}
            {day.rows[0].room ? ` in ${day.rows[0].room}` : ''}.
          </p>
        )}
      </section>
    );
  }

  if (!current && next) {
    return (
      <section className="kl-hero kl-hero-quiet">
        <Glow size={140} intensity={0.08} color="255, 214, 130" />
        <p className="kl-hero-eyebrow">Between classes</p>
        <div className="kl-hero-top">
          <p className="kl-hero-class">{rowLabel(next)}</p>
          {next.room && <p className="kl-hero-room">{next.room}</p>}
        </div>
        <p className="kl-hero-then">
          Starts at {bare(next.startTime)}{next.block ? `, ${next.block} block` : ''}
        </p>
      </section>
    );
  }

  const row = current!;
  const start = parseTime12(row.startTime);
  const end = parseTime12(row.endTime);
  const minutesLeft = end === null ? null : Math.max(0, end - clock);
  const elapsed = start !== null && end !== null && end > start
    ? Math.min(100, Math.max(0, ((clock - start) / (end - start)) * 100))
    : null;

  return (
    <>
      <section className="kl-hero kl-hero-now">
        <div className="kl-hero-top">
          <p className="kl-hero-class">{rowLabel(row)}</p>
          {row.room && <p className="kl-hero-room">{row.room}</p>}
        </div>

        <p className="kl-hero-meta">
          {row.block ? `${row.block} block` : isLunch(row) ? 'Lunch' : 'Right now'}
          {', until '}{bare(row.endTime)}
          {minutesLeft !== null && minutesLeft <= 60 && (
            <>{' — '}<strong>{minutesLeft === 0 ? 'ending now' : `${minutesLeft} min left`}</strong></>
          )}
        </p>

        {elapsed !== null && (
          <div className="kl-progress"><span style={{ width: `${elapsed}%` }} /></div>
        )}
      </section>

      {next && (
        <p className="kl-then">
          Then {rowLabel(next)}{next.room ? ` in ${next.room}` : ''} at {bare(next.startTime)}
        </p>
      )}
    </>
  );
}

/* ---------- the day ------------------------------------------------------ */

/* ---------- a real calendar --------------------------------------------
 * The week strip covers the common case (some other day this week). This covers every other
 * case: a Monday in November, the day before a break, whatever.
 *
 * An expanding panel rather than a floating popover, so it pushes the day down instead of
 * covering it. A popover over a schedule is a popover hiding the thing you opened it to
 * compare against.
 */
const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'];

function monthGrid(year: number, month: number): (string | null)[] {
  const first = new Date(Date.UTC(year, month, 1));
  const lead = first.getUTCDay();
  const days = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  const cells: (string | null)[] = Array.from({ length: lead }, () => null);
  for (let d = 1; d <= days; d++) {
    cells.push(`${year}-${String(month + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`);
  }
  return cells;
}

function Calendar({ selected, onPick }: { selected: string; onPick: (iso: string) => void }) {
  const [y, m] = useMemo(() => {
    const [year, month] = selected.split('-').map(Number);
    return [year, month - 1];
  }, [selected]);
  const [view, setView] = useState({ y, m });

  // Follow the selection when it moves to another month, so opening the calendar always
  // lands on the month you are looking at rather than wherever it was left.
  useEffect(() => setView({ y, m }), [y, m]);

  const cells = monthGrid(view.y, view.m);
  const today = localToday();

  const step = (delta: number) => {
    const next = new Date(Date.UTC(view.y, view.m + delta, 1));
    setView({ y: next.getUTCFullYear(), m: next.getUTCMonth() });
  };

  return (
    <div className="kl-cal">
      <div className="kl-cal-head">
        <button type="button" className="kl-cal-step" onClick={() => step(-1)} aria-label="Previous month">
          &lsaquo;
        </button>
        <span className="kl-cal-month">{MONTHS[view.m]} {view.y}</span>
        <button type="button" className="kl-cal-step" onClick={() => step(1)} aria-label="Next month">
          &rsaquo;
        </button>
      </div>

      <div className="kl-cal-dow" aria-hidden>
        {['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d, i) => <span key={i}>{d}</span>)}
      </div>

      <div className="kl-cal-grid">
        {cells.map((iso, i) => {
          if (!iso) return <span key={`pad-${i}`} className="kl-cal-pad" />;
          const dow = new Date(`${iso}T00:00:00Z`).getUTCDay();
          const weekend = dow === 0 || dow === 6;
          return (
            <button
              key={iso}
              type="button"
              className={[
                'kl-cal-day',
                iso === selected ? 'is-selected' : '',
                iso === today ? 'is-today' : '',
                weekend ? 'is-weekend' : '',
              ].filter(Boolean).join(' ')}
              onClick={() => onPick(iso)}
              aria-current={iso === selected ? 'date' : undefined}
            >
              {Number(iso.slice(8))}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function DaySheet({
  day, week, clock, isToday, onPick, onToday,
}: {
  day: DayPayload;
  week: DayPayload[];
  clock: number;
  isToday: boolean;
  onPick: (iso: string) => void;
  onToday: () => void;
}) {
  const [calOpen, setCalOpen] = useState(false);
  const { current } = useMemo(
    () => (isToday ? nowAndNext(day.rows, clock, parseTime12) : { current: null, next: null }),
    [day.rows, clock, isToday],
  );

  return (
    <section className="kl-sheet">
      <header className="kl-sheet-head">
        <h2>{day.label.replace(/,\s*\d{4}$/, '')}</h2>
        <div className="kl-sheet-nav">
          <nav className="kl-week" aria-label="Pick a day this week">
            {week.map((d) => (
              <button
                key={d.date}
                type="button"
                className={`kl-week-day${d.date === day.date ? ' is-current' : ''}${d.closed ? ' is-closed' : ''}`}
                onClick={() => onPick(d.date)}
                aria-current={d.date === day.date}
              >
                <span>{shortDay(d.label)}</span>
                <em>{Number(d.date.slice(8))}</em>
              </button>
            ))}
          </nav>
          <button
            type="button"
            className={`kl-cal-toggle${calOpen ? ' is-open' : ''}`}
            onClick={() => setCalOpen((v) => !v)}
            aria-expanded={calOpen}
          >
            {calOpen ? 'Close calendar' : 'Another day'}
          </button>
        </div>
      </header>

      {calOpen && (
        <Calendar
          selected={day.date}
          onPick={(iso) => { onPick(iso); setCalOpen(false); }}
        />
      )}

      {!isToday && <button type="button" className="kl-link" onClick={onToday}>Back to today</button>}

      {day.closed ? (
        <p className="kl-closed">No school{day.reason ? <>. <span>{day.reason}</span></> : '.'}</p>
      ) : day.rows.length === 0 ? (
        <p className="kl-note">Nothing is published for this day yet.</p>
      ) : (
        <ol className="kl-rows">
          {day.rows.map((row, i) => {
            const end = parseTime12(row.endTime);
            const past = isToday && end !== null && clock >= end;
            const now = isToday && current === row;
            const free = Boolean(row.block) && !row.className;
            return (
              <li
                key={`${row.startTime}-${row.name}-${i}`}
                className={[
                  'kl-row',
                  now ? 'is-now' : '',
                  past && !now ? 'is-past' : '',
                  isLunch(row) ? 'is-lunch' : '',
                  free ? 'is-free' : '',
                ].filter(Boolean).join(' ')}
              >
                <span className="kl-row-time">{bare(row.startTime)}</span>
                <span className="kl-row-block">{row.block ?? ''}</span>
                <span className="kl-row-name">
                  {free ? 'Free' : rowLabel(row)}
                  {row.audienceLabel && <em> {row.audienceLabel}</em>}
                </span>
                <span className="kl-row-room">{row.room ?? ''}</span>
              </li>
            );
          })}
        </ol>
      )}

      {day.imageUrl && (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={day.imageUrl} alt="Published schedule for this day" className="kl-day-image" />
      )}
    </section>
  );
}

/* ---------- footer ------------------------------------------------------- */

function Footer({ token, from, onEdit }: { token: string; from: string; onEdit: () => void }) {
  return (
    <footer className="kl-foot">
      <a
        className="kl-primary kl-download"
        href={withBasePath(`/api/student/ics?from=${from}&token=${encodeURIComponent(token)}`)}
      >
        Add my classes to a calendar
      </a>
      <p className="kl-note">
        Downloads the rest of the term as one file. It is a snapshot, so download it again if BB&amp;N
        changes a schedule.
      </p>
      <div className="kl-foot-links">
        <button type="button" className="kl-link" onClick={onEdit}>Change my classes</button>
        <button type="button" className="kl-link" onClick={() => void signOutOfGoogle()}>Sign out</button>
      </div>
    </footer>
  );
}

/* ---------- setup -------------------------------------------------------- */

function ClassSetup({ token, canCancel, onDone }: { token: string; canCancel: boolean; onDone: () => void }) {
  const [catalogue, setCatalogue] = useState<CatalogueEntry[] | null>(null);
  const [classes, setClasses] = useState<Partial<Record<BlockLetter, string>>>({});
  const [rooms, setRooms] = useState<Partial<Record<BlockLetter, string>>>({});
  const [grade, setGrade] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void (async () => {
      const res = await fetch(withBasePath('/api/student/profile'), {
        headers: { authorization: `Bearer ${token}` },
      });
      const body = await res.json();
      if (!res.ok) { setError(body.error ?? 'Could not load the class list.'); return; }
      setCatalogue(body.catalogue ?? []);
      setClasses(body.classes ?? {});
      setRooms(body.rooms ?? {});
      setGrade(body.grade ?? '');
    })();
  }, [token]);

  const byBlock = useMemo(() => {
    const map = new Map<BlockLetter, CatalogueEntry[]>();
    for (const letter of BLOCK_LETTERS) map.set(letter, []);
    for (const entry of catalogue ?? []) map.get(entry.block)?.push(entry);
    return map;
  }, [catalogue]);

  const chosen = BLOCK_LETTERS.filter((l) => classes[l]).length;

  async function save() {
    setSaving(true);
    setError(null);
    const res = await fetch(withBasePath('/api/student/profile'), {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ classes, rooms, grade: grade || null }),
    });
    setSaving(false);
    if (!res.ok) { setError((await res.json()).error ?? 'Could not save your classes.'); return; }
    onDone();
  }

  if (error) return <p className="kl-error">{error}</p>;
  if (!catalogue) return <p className="kl-note">Loading the class list.</p>;

  return (
    <section className="kl-setup">
      {/* An explicit banner, because the schedule and this screen are the same page and a
          student needs to know which one they are looking at without reading the content. */}
      <div className="kl-setup-bar">
        <span className="kl-setup-bar-title">
          {canCancel ? 'Editing your classes' : 'Set up your classes'}
        </span>
        {canCancel && (
          <button type="button" className="kl-link" onClick={onDone}>
            Leave without saving
          </button>
        )}
      </div>

      <p className="kl-setup-lede">
        One class per block, from BB&amp;N&apos;s real list. The room fills in for you. Leave a block on
        Free if you do not have a class then.
      </p>

      <div className="kl-fieldset">
        <h3 className="kl-fieldset-title">Your grade</h3>
        <p className="kl-fieldset-why">Some days run differently for each grade, so this changes what you see.</p>
        <select
          aria-label="Your grade"
          className="kl-grade-select"
          value={grade}
          onChange={(e) => setGrade(e.target.value)}
        >
          <option value="">Pick your grade</option>
          {['9', '10', '11', '12'].map((g) => <option key={g} value={g}>{g}th grade</option>)}
          <option value="teacher">Faculty</option>
        </select>
      </div>

      <div className="kl-fieldset">
        <h3 className="kl-fieldset-title">Your seven blocks</h3>
        <p className="kl-fieldset-why">{chosen} of 7 filled in.</p>

        <ol className="kl-setup-rows">
          {BLOCK_LETTERS.map((letter) => {
            const options = byBlock.get(letter) ?? [];
            const value = classes[letter] ?? '';
            const known = options.some((o) => o.name === value);
            return (
              <li className={`kl-setup-row${value ? ' is-set' : ''}`} key={letter}>
                <span className="kl-setup-letter">{letter}</span>

                <div className="kl-setup-fields">
                  <select
                    aria-label={`Class in block ${letter}`}
                    value={known ? value : value ? '__typed' : ''}
                    onChange={(e) => {
                      const picked = e.target.value;
                      if (picked === '__typed') return;
                      const entry = options.find((o) => o.name === picked);
                      setClasses((c) => ({ ...c, [letter]: picked }));
                      setRooms((r) => ({ ...r, [letter]: entry?.room ?? '' }));
                    }}
                  >
                    <option value="">Free</option>
                    {value && !known && <option value="__typed">{value}</option>}
                    {options.map((o) => (
                      <option key={o.id} value={o.name}>
                        {o.name}{o.teacher ? ` — ${o.teacher}` : ''}
                      </option>
                    ))}
                  </select>

                  <input
                    aria-label={`Room for block ${letter}`}
                    placeholder="Room"
                    value={rooms[letter] ?? ''}
                    onChange={(e) => setRooms((r) => ({ ...r, [letter]: e.target.value }))}
                  />
                </div>
              </li>
            );
          })}
        </ol>
      </div>

      {/* Sticky, so Save is reachable from anywhere in a seven-row form on a short screen. */}
      <div className="kl-setup-actions">
        <button type="button" className="kl-primary" onClick={save} disabled={saving}>
          {saving ? 'Saving' : 'Save and see my schedule'}
        </button>
        <span className="kl-note">Saves to your Knight Life account, so the app gets it too.</span>
      </div>
    </section>
  );
}
