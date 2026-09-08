'use client';

/**
 * Knight Life on the web.
 *
 * Phones are banned in class and in the hallways at BB&N, which removed the app's only
 * surface during exactly the hours it is for. This is the same schedule on whatever device
 * is already open in front of the student.
 *
 * Three states, in the order a student meets them: sign in, set up your seven blocks, then
 * see your day. The setup step exists because the end-of-year cleanup cleared everyone's
 * classes, so nearly every account arrives empty on the first day back.
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

  // Keep the session across a refresh. Firebase restores it asynchronously, so `ready`
  // gates the sign-in button: without it the page flashes "Sign in" at someone who is
  // already signed in.
  useEffect(() => {
    if (!configured) { setReady(true); return; }
    return clientAuth().onIdTokenChanged(async (user) => {
      setToken(user ? await user.getIdToken() : null);
      setReady(true);
    });
  }, [configured]);

  // The "now" marker moves on its own. A student watching the page through a passing
  // period should see it advance without touching anything.
  useEffect(() => {
    const id = setInterval(() => setClock(minutesNow()), 30_000);
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
      const message = (e as { code?: string }).code === 'auth/popup-blocked'
        ? 'Your browser blocked the sign-in window. Allow pop-ups for this page and try again.'
        : (e as Error).message;
      setError(message);
    } finally {
      setSigningIn(false);
    }
  }

  if (!configured) {
    return <p className="note">This deployment has no Firebase configuration, so sign-in is off.</p>;
  }

  if (!ready) return <p className="note">Checking your sign-in…</p>;

  if (!token) {
    return (
      <section className="card">
        <Glow size={280} intensity={0.13} color="255, 214, 130" />
        <h2>Your schedule, on any screen</h2>
        <p>
          Sign in with the same Google account you use in the Knight Life app and your classes come with
          you. If you have never set them up, you can pick them here.
        </p>
        <button type="button" className="primary" onClick={signIn} disabled={signingIn}>
          <Glow size={130} intensity={0.3} color="255, 214, 130" />
          {signingIn ? 'Opening Google…' : 'Sign in with Google'}
        </button>
        {error && <p className="error">{error}</p>}
        <p className="note">
          A personal Google account works. Knight Life has never required a school account.
        </p>
      </section>
    );
  }

  return (
    <>
      <div className="student-bar">
        <div className="switcher">
          <label className="switcher-label" htmlFor="date">Day</label>
          <input id="date" type="date" value={date} onChange={(e) => setDate(e.target.value || localToday())} />
          {date !== localToday() && (
            <button type="button" className="secondary" onClick={() => setDate(localToday())}>Today</button>
          )}
        </div>
        <div className="student-bar-right">
          <button type="button" className="secondary" onClick={() => setEditing((v) => !v)}>
            {editing ? 'Done editing' : 'My classes'}
          </button>
          <button type="button" className="secondary" onClick={() => { void signOutOfGoogle(); setData(null); }}>
            Sign out
          </button>
        </div>
      </div>

      {error && <p className="error">{error}</p>}

      {editing && token && (
        <ClassSetup
          token={token}
          onSaved={() => { setEditing(false); void load(token, date); }}
        />
      )}

      {data && !editing && (
        <>
          <DayView day={data.today} clock={clock} isToday={date === localToday()} />
          <WeekView week={data.week} current={date} onPick={setDate} />
          <Export token={token} from={date} />
        </>
      )}
    </>
  );
}

function DayView({ day, clock, isToday }: { day: DayPayload; clock: number; isToday: boolean }) {
  const { current, next } = useMemo(
    () => (isToday ? nowAndNext(day.rows, clock, parseTime12) : { current: null, next: null }),
    [day.rows, clock, isToday],
  );

  return (
    <section className="card day">
      <Glow size={280} intensity={0.13} color="255, 214, 130" />
      <header>
        <h3>{day.label}</h3>
        {day.reason && <p className="reason">{day.reason}</p>}
      </header>

      {day.closed ? (
        <p className="note">No classes{day.reason ? ` — ${day.reason}` : ''}.</p>
      ) : day.rows.length === 0 ? (
        <p className="note">Nothing is published for this day yet.</p>
      ) : (
        <>
          {isToday && (current || next) && (
            <div className="nownext">
              <div>
                <span className="nownext-label">Now</span>
                <strong>{current ? label(current) : 'Nothing right now'}</strong>
                {current?.room && <span className="room">{current.room}</span>}
              </div>
              <div>
                <span className="nownext-label">Next</span>
                <strong>{next ? label(next) : 'Nothing left today'}</strong>
                {next && <span className="band-time">{next.startTime}</span>}
              </div>
            </div>
          )}
          <ul className="student-rows">
            {day.rows.map((row, i) => {
              const isNow = isToday && current === row;
              return (
                <li key={`${row.name}-${row.startTime}-${i}`} className={isNow ? 'student-row now' : 'student-row'}>
                  {row.block ? <span className="band-letter">{row.block}</span> : <span className="band-letter blank" />}
                  <span className="band-name">{label(row)}</span>
                  {row.room && <span className="room">{row.room}</span>}
                  {row.audienceLabel && <span className="band-meta">{row.audienceLabel}</span>}
                  <span className="band-time">{row.startTime}–{row.endTime}</span>
                </li>
              );
            })}
          </ul>
        </>
      )}
      {day.imageUrl && (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={day.imageUrl} alt="Published schedule" className="day-image" />
      )}
    </section>
  );
}

function label(row: StudentRow): string {
  return row.className ?? row.name;
}

function WeekView({ week, current, onPick }: { week: DayPayload[]; current: string; onPick: (iso: string) => void }) {
  return (
    <section className="card">
      <Glow size={280} intensity={0.1} color="255, 214, 130" />
      <h3>This week</h3>
      <div className="week">
        {week.map((day) => (
          <button
            key={day.date}
            type="button"
            className={`week-day${day.date === current ? ' current' : ''}${day.closed ? ' closed' : ''}`}
            onClick={() => onPick(day.date)}
          >
            <span className="week-day-name">{day.label.split(',')[0].slice(0, 3)}</span>
            <span className="week-day-num">{day.date.slice(8)}</span>
            <span className="week-day-count">
              {day.closed ? (day.reason ?? 'No school') : `${day.rows.filter((r) => r.block).length} blocks`}
            </span>
          </button>
        ))}
      </div>
    </section>
  );
}

function Export({ token, from }: { token: string; from: string }) {
  return (
    <section className="card">
      <Glow size={280} intensity={0.1} color="255, 214, 130" />
      <h3>Put it in your calendar</h3>
      <p className="note">
        Downloads every class from {from} to the end of the term as a calendar file. Add it to Google
        Calendar, Apple Calendar, or Outlook and your schedule is there without opening anything.
      </p>
      <p>
        {/* A plain anchor, not next/link: this is a file download, and it needs the base
            path written by hand. */}
        <a className="download" href={withBasePath(`/api/student/ics?from=${from}&token=${encodeURIComponent(token)}`)}>
          Download my calendar (.ics)
        </a>
      </p>
      <p className="note">
        It is a snapshot. If BB&amp;N publishes a schedule change after you download it, download it again.
      </p>
    </section>
  );
}

/* ---------- setup -------------------------------------------------------- */

function ClassSetup({ token, onSaved }: { token: string; onSaved: () => void }) {
  const [catalogue, setCatalogue] = useState<CatalogueEntry[] | null>(null);
  const [classes, setClasses] = useState<Partial<Record<BlockLetter, string>>>({});
  const [rooms, setRooms] = useState<Partial<Record<BlockLetter, string>>>({});
  const [grade, setGrade] = useState<string>('');
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

  async function save() {
    setSaving(true);
    setError(null);
    const res = await fetch(withBasePath('/api/student/profile'), {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ classes, rooms, grade: grade || null }),
    });
    setSaving(false);
    if (!res.ok) { setError((await res.json()).error ?? 'Could not save.'); return; }
    onSaved();
  }

  if (error) return <p className="error">{error}</p>;
  if (!catalogue) return <p className="note">Loading the class list…</p>;

  return (
    <section className="card">
      <Glow size={280} intensity={0.13} color="255, 214, 130" />
      <h3>Your classes</h3>
      <p className="note">
        Pick the class you have in each block. The room comes with it. This saves to your Knight Life
        account, so the app gets it too.
      </p>

      <div className="field setup-grade">
        <label htmlFor="grade">Grade</label>
        <select id="grade" value={grade} onChange={(e) => setGrade(e.target.value)}>
          <option value="">Not set</option>
          {['9', '10', '11', '12'].map((g) => <option key={g} value={g}>{g}</option>)}
          <option value="teacher">Faculty</option>
        </select>
      </div>

      {BLOCK_LETTERS.map((letter) => {
        const options = byBlock.get(letter) ?? [];
        const value = classes[letter] ?? '';
        return (
          <div className="setup-row" key={letter}>
            <span className="band-letter">{letter}</span>
            <div className="field">
              <select
                aria-label={`Block ${letter}`}
                value={options.some((o) => o.name === value) ? value : (value ? '__other' : '')}
                onChange={(e) => {
                  const picked = e.target.value;
                  if (picked === '__other') return;
                  const entry = options.find((o) => o.name === picked);
                  setClasses((c) => ({ ...c, [letter]: picked }));
                  setRooms((r) => ({ ...r, [letter]: entry?.room ?? '' }));
                }}
              >
                <option value="">Free block</option>
                {value && !options.some((o) => o.name === value) && (
                  <option value="__other">{value} (typed in)</option>
                )}
                {options.map((o) => (
                  <option key={o.id} value={o.name}>
                    {o.name}{o.teacher ? ` — ${o.teacher}` : ''}
                  </option>
                ))}
              </select>
            </div>
            <input
              className="setup-room"
              aria-label={`Room for block ${letter}`}
              placeholder="Room"
              value={rooms[letter] ?? ''}
              onChange={(e) => setRooms((r) => ({ ...r, [letter]: e.target.value }))}
            />
          </div>
        );
      })}

      <div className="confirm">
        <button type="button" className="primary" onClick={save} disabled={saving}>
          <Glow size={130} intensity={0.3} color="255, 214, 130" />
          {saving ? 'Saving…' : 'Save my classes'}
        </button>
      </div>
    </section>
  );
}
