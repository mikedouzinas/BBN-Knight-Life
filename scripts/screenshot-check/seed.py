# LOCAL VERIFY ONLY: seeds a test student into the Firebase EMULATORS (127.0.0.1). Never production.
import datetime, json, sys, urllib.request

# Dates are relative to today so the seed works on any run: NEXT is the next
# school day (the app's "Tomorrow"), PAST1/PAST2 are overdue.
today = datetime.date.today()
NEXT = today + datetime.timedelta(days=1)
while NEXT.weekday() >= 5:
    NEXT += datetime.timedelta(days=1)
AFTER = NEXT + datetime.timedelta(days=1)
while AFTER.weekday() >= 5:
    AFTER += datetime.timedelta(days=1)
D = lambda d: d.isoformat()
PAST1, PAST2 = D(today - datetime.timedelta(days=2)), D(today - datetime.timedelta(days=1))

AUTH = "http://127.0.0.1:9099"
FS = "http://127.0.0.1:8080/v1/projects/bbn-daily/databases/(default)/documents"
EMAIL, PASSWORD = "test.student@bbns.org", "verify-only-123"


def req(method, url, body=None, owner=True):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("Content-Type", "application/json")
    if owner:
        r.add_header("Authorization", "Bearer owner")
    with urllib.request.urlopen(r) as resp:
        return json.loads(resp.read() or b"{}")


def val(v):
    if isinstance(v, bool): return {"booleanValue": v}
    if isinstance(v, int): return {"integerValue": str(v)}
    if isinstance(v, dict) and "__ts" in v: return {"timestampValue": v["__ts"]}
    if isinstance(v, list): return {"arrayValue": {"values": [val(x) for x in v]}}
    return {"stringValue": str(v)}


def put(path, fields):
    req("PATCH", f"{FS}/{path}", {"fields": {k: val(v) for k, v in fields.items()}})


# wipe
req("DELETE", "http://127.0.0.1:8080/emulator/v1/projects/bbn-daily/databases/(default)/documents")
req("DELETE", f"{AUTH}/emulator/v1/projects/bbn-daily/accounts")
u = req("POST", f"{AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake",
        {"email": EMAIL, "password": PASSWORD, "displayName": "Test Student", "returnSecureToken": True}, owner=False)
uid = u["localId"]

TERM = "2026/9/8"
put("schedules/term", {"start": TERM, "end": "2027/6/10", "reason": "Summer break"})
put("ifstatements/ifstatements", {"shouldUseOnlineClasses": False})
put(f"users/{uid}", {
    "A": "Math~Smith~101~A", "B": "History~Jones~202~B", "C": "English~Lee~303~C",
    "D": "Free~ ~ ~D", "E": "Chemistry~Patel~404~E", "F": "Spanish~Garcia~505~F", "G": "Art~Kim~606~G",
    "grade": "11", "l-monday": "2nd Lunch", "l-tuesday": "2nd Lunch", "l-wednesday": "2nd Lunch",
    "l-thursday": "2nd Lunch", "l-friday": "2nd Lunch", "l-a": "", "l-b": "", "l-c": "", "l-d": "", "l-e": "",
    "l-f": "", "l-g": "", "googlePhoto": "false", "lockerNum": "", "notifs": "true", "room-advisory": "",
    "uid": uid, "classesSetForTermStart": TERM,
})

TS = {"__ts": (today - datetime.timedelta(days=5)).isoformat() + "T12:00:00Z"}
items = {
    # The next school day: Math has 3 homework + a test; History has only tests.
    "hwA1": dict(kind="homework", title="Problem set 4.2", dueDate=D(NEXT), classBlock="A"),
    "hwA2": dict(kind="homework", title="Read chapter 5 and take notes", dueDate=D(NEXT), classBlock="A"),
    "hwA3": dict(kind="homework", title="Derivatives worksheet", dueDate=D(NEXT), classBlock="A"),
    "tA1": dict(kind="test", title="Unit 4 test", dueDate=D(NEXT), classBlock="A"),
    "tB1": dict(kind="test", title="Map quiz", dueDate=D(NEXT), classBlock="B"),
    "tB2": dict(kind="test", title="Industrial Revolution DBQ", dueDate=D(NEXT), classBlock="B"),
    # English: one homework with a long title.
    "hwC1": dict(kind="homework", title="Write the thesis paragraph for the Gatsby essay and bring two printed copies to class", dueDate=D(NEXT), classBlock="C"),
    # Upcoming filler
    "hwG1": dict(kind="homework", title="Sketchbook page", dueDate=D(AFTER), classBlock="G"),
    "apD1": dict(kind="appointment", title="Meet with advisor", dueDate=D(today), classBlock="D"),
    # Past: overdue, unfinished, one with a step
    "pE1": dict(kind="homework", title="Lab report draft", dueDate=PAST1, classBlock="E"),
    "pE1s": dict(kind="homework", title="Outline the lab report", dueDate=D(today - datetime.timedelta(days=3)), classBlock="E", parentId="pE1"),
    "pF1": dict(kind="homework", title="Vocab list 3", dueDate=PAST2, classBlock="F"),
}
for iid, it in items.items():
    put(f"users/{uid}/planner/{iid}", {**it, "completed": False, "createdAt": TS})
print("seeded", uid, len(items), "planner items")
