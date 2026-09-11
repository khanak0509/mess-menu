from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Query
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import io
import os
import html
import re
from datetime import datetime

app = FastAPI(title="IITJ Mess Menu API")


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

try:
    if not firebase_admin._apps:
        current_dir = os.path.dirname(os.path.abspath(__file__))
        cred_path = os.path.join(current_dir, "admin.json")
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("Firebase connected successfully.")
except Exception as e:
    print(f"Firebase initialization failed: {e}")
    db = None

MENU_COLLECTION = "mess_menu"
CONFIG_COLLECTION = "app_config"
VEG_DOC = "current_month_veg"
NONVEG_DOC = "current_month_nonveg"
CONFIG_DOC = "current"

DEFAULT_CONFIG = {
    "timings": {
        "weekday_breakfast": "07:30-10:00",
        "weekend_breakfast": "08:00-10:30",
        "lunch": "12:15-14:45",
        "snacks": "17:30-18:30",
        "dinner": "19:30-22:30",
    },
    "special_dinner": {
        "date": "",
        "veg_text": "",
        "nonveg_text": "",
    },
    "exam_schedule": {
        "start_date": "",
        "end_date": "",
        "breakfast_time": "",
        "note": "",
        "breakfasts": {},
        "breakfasts_raw": "",
    },
    "app_update": {
        "latest_version": "1.0.0",
        "latest_build": 1,
        "apk_url": "https://github.com/khanak0509/mess-menu/releases/download/v1/IITJ.menu",
        "message": "",
    },
}

_MONTH_LOOKUP = {
    "january": 1,
    "jan": 1,
    "february": 2,
    "feb": 2,
    "march": 3,
    "mar": 3,
    "april": 4,
    "apr": 4,
    "may": 5,
    "june": 6,
    "jun": 6,
    "july": 7,
    "jul": 7,
    "august": 8,
    "aug": 8,
    "september": 9,
    "sept": 9,
    "sep": 9,
    "october": 10,
    "oct": 10,
    "november": 11,
    "nov": 11,
    "december": 12,
    "dec": 12,
}


def _get_menu_doc_name(preference: str) -> str:
    return NONVEG_DOC if preference.lower() == "nonveg" else VEG_DOC


def _clean_cell(cell):
    if pd.isna(cell):
        return ""
    text = str(cell).strip()
    if text in {"—", "-", "–", "nan", "NaN", "None"}:
        return ""
    return text


def _find_column(columns, *candidates):
    """Match a column by exact name, case-insensitive name, or common aliases."""
    normalized = {str(col).strip().lower(): col for col in columns}
    for candidate in candidates:
        key = candidate.strip().lower()
        if key in normalized:
            return normalized[key]
    return None


def _iso_date(year: int, month: int, day: int) -> str:
    return f"{year:04d}-{month:02d}-{day:02d}"


def _parse_exam_breakfasts(raw_text: str, default_year=None) -> dict:
    """Parse vendor-mail style lines into {YYYY-MM-DD: breakfast item}."""
    year = default_year or datetime.now().year
    breakfasts = {}
    for raw_line in (raw_text or "").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        lower = line.lower()
        if lower.startswith("date") and "breakfast" in lower:
            continue
        if lower in {"date", "breakfast"}:
            continue

        m = re.match(
            r"^(\d{4})-(\d{1,2})-(\d{1,2})\s*[|\-–—:]\s*(.+)$",
            line,
        )
        if m:
            y, mo, d, item = m.groups()
            breakfasts[_iso_date(int(y), int(mo), int(d))] = item.strip()
            continue

        m = re.match(
            r"^(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\s*[|\-–—:]\s*(.+)$",
            line,
        )
        if m:
            d, mo, y, item = m.groups()
            y_int = int(y) if y else year
            if y_int < 100:
                y_int += 2000
            breakfasts[_iso_date(y_int, int(mo), int(d))] = item.strip()
            continue

        m = re.match(
            r"^(\d{1,2})\s+([A-Za-z]+)\.?\s*(\d{4})?\s*[|\-–—:\t]+\s*(.+)$",
            line,
        )
        if m:
            d, mon, y, item = m.groups()
            mo = _MONTH_LOOKUP.get(mon.lower())
            if mo:
                y_int = int(y) if y else year
                breakfasts[_iso_date(y_int, mo, int(d))] = item.strip()
            continue

        # "15 September Idli & Fried Idli" (single spaces)
        m = re.match(r"^(\d{1,2})\s+([A-Za-z]+)\.?\s+(\d{4})\s+(.+)$", line)
        if m:
            d, mon, y, item = m.groups()
            mo = _MONTH_LOOKUP.get(mon.lower())
            if mo:
                breakfasts[_iso_date(int(y), mo, int(d))] = item.strip()
            continue

        m = re.match(r"^(\d{1,2})\s+([A-Za-z]+)\.?\s+(.+)$", line)
        if m:
            d, mon, item = m.groups()
            mo = _MONTH_LOOKUP.get(mon.lower())
            if mo and item.strip():
                breakfasts[_iso_date(year, mo, int(d))] = item.strip()

    return breakfasts


def _process_csv_to_menu(file_bytes: bytes):
    mess_table = pd.read_csv(io.BytesIO(file_bytes))
    mess_table.columns = mess_table.columns.str.strip()
    mess_table["Day"] = mess_table["Day"].ffill().str.strip()
    mess_table["Meal"] = mess_table["Meal"].str.strip()

    cols = list(mess_table.columns)
    main_col = _find_column(cols, "Unnamed: 2", "Main", "MAIN")
    # Excel exports often leave complimentary header blank -> Unnamed: 4
    complimentary_col = _find_column(
        cols,
        "Complimentary items",
        "Complimentary",
        "COMPLIMENTARY ITEMS",
        "Unnamed: 4",
    )
    compulsory_col = _find_column(
        cols, "COMPULSORY ITEMS", "Compulsory items", "Compulsory"
    )
    jain_col = _find_column(cols, "JAIN", "Jain")
    nonveg_col = _find_column(
        cols, "NON-VEG", "NON VEG", "Non-Veg", "Non Veg", "NONVEG"
    )

    beautiful_menu = {}

    for _, meal_row in mess_table.iterrows():
        current_day = meal_row["Day"]
        current_meal = meal_row["Meal"]

        if pd.isna(current_day) or pd.isna(current_meal):
            continue

        if current_day not in beautiful_menu:
            beautiful_menu[current_day] = {}

        beautiful_menu[current_day][current_meal] = {
            "Main": _clean_cell(meal_row[main_col]) if main_col else "",
            "Complimentary": _clean_cell(meal_row[complimentary_col])
            if complimentary_col
            else "",
            "Compulsory": _clean_cell(meal_row[compulsory_col])
            if compulsory_col
            else "",
            "Jain": _clean_cell(meal_row[jain_col]) if jain_col else "",
            "NonVeg": _clean_cell(meal_row[nonveg_col]) if nonveg_col else "",
        }

    return beautiful_menu


def _get_config():
    if not db:
        return DEFAULT_CONFIG
    doc_ref = db.collection(CONFIG_COLLECTION).document(CONFIG_DOC)
    config_doc = doc_ref.get()
    if not config_doc.exists:
        doc_ref.set(DEFAULT_CONFIG)
        return DEFAULT_CONFIG

    raw = config_doc.to_dict() or {}
    merged = {
        "timings": {
            **DEFAULT_CONFIG["timings"],
            **(raw.get("timings") or {}),
        },
        "special_dinner": {
            **DEFAULT_CONFIG["special_dinner"],
            **(raw.get("special_dinner") or {}),
        },
        "exam_schedule": {
            **DEFAULT_CONFIG["exam_schedule"],
            **(raw.get("exam_schedule") or {}),
        },
        "app_update": {
            **DEFAULT_CONFIG["app_update"],
            **(raw.get("app_update") or {}),
        },
    }
    if raw.get("special_dinner_text") and not merged["special_dinner"]["veg_text"]:
        merged["special_dinner"]["veg_text"] = raw.get("special_dinner_text", "")

    breakfasts = merged["exam_schedule"].get("breakfasts") or {}
    if not isinstance(breakfasts, dict):
        breakfasts = {}
    merged["exam_schedule"]["breakfasts"] = {
        str(k): str(v) for k, v in breakfasts.items() if str(v).strip()
    }

    try:
        merged["app_update"]["latest_build"] = int(
            merged["app_update"].get("latest_build") or 1
        )
    except (TypeError, ValueError):
        merged["app_update"]["latest_build"] = 1

    return merged


def _save_config(partial: dict):
    """Merge partial config into existing Firestore config and save."""
    current = _get_config()
    for key, value in partial.items():
        if isinstance(value, dict) and isinstance(current.get(key), dict):
            current[key] = {**current[key], **value}
        else:
            current[key] = value
    db.collection(CONFIG_COLLECTION).document(CONFIG_DOC).set(current)
    return current


def _success_html(title: str, message: str) -> HTMLResponse:
    return HTMLResponse(
        content=f"""
        <body style="background:#111318;color:white;font-family:sans-serif;text-align:center;padding-top:100px;">
            <h1 style="font-size:40px;">{html.escape(title)}</h1>
            <p style="font-size:18px;color:#ccc;max-width:500px;margin:auto;">{html.escape(message)}</p>
            <br><br>
            <a href="/admin" style="background:#6200EE;color:white;padding:14px 28px;border-radius:10px;text-decoration:none;font-weight:bold;transition:0.2s;">← Back to Dashboard</a>
        </body>
        """
    )
@app.get("/menu")
async def get_entire_months_menu(preference: str = Query(default="veg")):
    """Return monthly menu for the selected preference."""
    if not db:
        raise HTTPException(status_code=500, detail="Database is not initialized.")
    
    try:
        pref = preference.lower()
        if pref not in {"veg", "nonveg"}:
            pref = "veg"
        doc_ref = db.collection(MENU_COLLECTION).document(_get_menu_doc_name(pref))
        monthly_menu = doc_ref.get()
        if monthly_menu.exists:
            return {
                "preference": pref,
                "menu": monthly_menu.to_dict(),
                "config": _get_config(),
            }
        else:
            raise HTTPException(status_code=404, detail="Menu not found for this month.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/menu/{day}")
async def get_menu_for_specific_day(day: str, preference: str = Query(default="veg")):
    """Return menu for a specific day and preference."""
    if not db:
        raise HTTPException(status_code=500, detail="Database is not initialized.")
    
    try:
        pref = preference.lower()
        if pref not in {"veg", "nonveg"}:
            pref = "veg"
        doc_ref = db.collection(MENU_COLLECTION).document(_get_menu_doc_name(pref))
        monthly_menu = doc_ref.get()
        if monthly_menu.exists:
            everyone_eats_this = monthly_menu.to_dict()
            day_to_check = day.lower()
            for the_day, meals_that_day in everyone_eats_this.items():
                if the_day.lower() == day_to_check:
                    return {
                        "preference": pref,
                        "day": day,
                        "menu": meals_that_day,
                        "config": _get_config(),
                    }
            
            raise HTTPException(status_code=404, detail=f"Menu not found for {day}.")
        else:
            raise HTTPException(status_code=404, detail="Menu data is empty.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/admin", response_class=HTMLResponse)
async def friendly_admin_dashboard():
    """Render admin dashboard."""
    config = _get_config()
    timings = config["timings"]
    special = config.get("special_dinner", {})
    exam = config.get("exam_schedule", {})
    app_update = config.get("app_update", {})
    special_date = special.get("date", "")
    special_veg_text = special.get("veg_text", "")
    special_nonveg_text = special.get("nonveg_text", "")
    exam_breakfasts_raw = exam.get("breakfasts_raw", "")
    if not exam_breakfasts_raw and exam.get("breakfasts"):
        exam_breakfasts_raw = "\n".join(
            f"{date} | {item}" for date, item in sorted(exam["breakfasts"].items())
        )

    html_content = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Mess Menu Admin</title>
        <style>
            body {{ font-family: -apple-system, system-ui, sans-serif; background: #111318; color: #fff; margin: 0; padding: 30px 14px; }}
            .wrap {{ max-width: 960px; margin: 0 auto; display: grid; gap: 16px; }}
            .card {{ background: #1e1e1e; padding: 24px; border-radius: 16px; box-shadow: 0 10px 30px rgba(0,0,0,0.35); border: 1px solid #333; }}
            h2, h3 {{ margin-top: 0; }}
            p {{ color: #bdbdbd; }}
            .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 14px; }}
            label {{ display: block; font-size: 13px; color: #c8c8c8; margin-bottom: 6px; }}
            input[type="file"], input[type="text"], input[type="number"], textarea {{ background: #2a2a2a; color: #fff; width: 100%; box-sizing: border-box; border: 1px solid #444; border-radius: 10px; padding: 12px; }}
            input[type="file"] {{ border-style: dashed; }}
            textarea {{ min-height: 100px; resize: vertical; }}
            textarea.tall {{ min-height: 160px; }}
            button {{ background: #6200EE; color: white; border: none; padding: 12px 16px; border-radius: 10px; font-weight: bold; font-size: 14px; cursor: pointer; transition: 0.2s; width: 100%; margin-top: 10px; }}
            button:hover {{ background: #7C4DFF; transform: scale(1.01); }}
            .danger {{ background: #b00020; }}
            .danger:hover {{ background: #cf2746; }}
            code {{ background:#2a2a2a; padding:2px 6px; border-radius:6px; }}
        </style>
    </head>
    <body>
        <div class="wrap">
            <div class="card">
                <h2>Mess Dashboard</h2>
                <p>Upload menus, set timings, paste exam breakfast changes, and publish app updates.</p>
            </div>

            <div class="grid">
                <div class="card">
                    <h3>Upload Veg Menu CSV</h3>
                    <form action="/upload-csv/veg" enctype="multipart/form-data" method="post">
                        <input name="file" type="file" accept=".csv" required>
                        <button type="submit">Upload Veg Menu</button>
                    </form>
                </div>

                <div class="card">
                    <h3>Upload Non-Veg Menu CSV</h3>
                    <form action="/upload-csv/nonveg" enctype="multipart/form-data" method="post">
                        <input name="file" type="file" accept=".csv" required>
                        <button class="danger" type="submit">Upload Non-Veg Menu</button>
                    </form>
                </div>
            </div>

            <div class="card">
                <h3>Meal Timings & Special Dinner</h3>
                <p>Use 24-hour format (HH:MM-HH:MM). These values are used directly in the app.</p>
                <form action="/update-config" method="post">
                    <div class="grid">
                        <div>
                            <label>Weekday Breakfast (Mon-Fri)</label>
                            <input type="text" name="weekday_breakfast" value="{html.escape(timings.get('weekday_breakfast', ''))}" required>
                        </div>
                        <div>
                            <label>Weekend Breakfast (Sat-Sun)</label>
                            <input type="text" name="weekend_breakfast" value="{html.escape(timings.get('weekend_breakfast', ''))}" required>
                        </div>
                        <div>
                            <label>Lunch</label>
                            <input type="text" name="lunch" value="{html.escape(timings.get('lunch', ''))}" required>
                        </div>
                        <div>
                            <label>Snacks</label>
                            <input type="text" name="snacks" value="{html.escape(timings.get('snacks', ''))}" required>
                        </div>
                        <div>
                            <label>Dinner</label>
                            <input type="text" name="dinner" value="{html.escape(timings.get('dinner', ''))}" required>
                        </div>
                    </div>
                    <div style="margin-top:14px;">
                        <label>Special Dinner Date (YYYY-MM-DD)</label>
                        <input type="text" name="special_dinner_date" value="{html.escape(special_date)}" placeholder="Example: 2026-04-29">
                    </div>
                    <div style="margin-top:14px;">
                        <label>Special Dinner Text (Veg)</label>
                        <textarea name="special_dinner_veg_text" placeholder="Example: Special dinner (veg) - Paneer Tikka + Kheer">{html.escape(special_veg_text)}</textarea>
                    </div>
                    <div style="margin-top:14px;">
                        <label>Special Dinner Text (Non-Veg)</label>
                        <textarea name="special_dinner_nonveg_text" placeholder="Example: Special dinner (non-veg) - Chicken Biryani + Sheermal">{html.escape(special_nonveg_text)}</textarea>
                    </div>
                    <button type="submit">Save App Settings</button>
                </form>
            </div>

            <div class="card">
                <h3>Exam Breakfast Schedule</h3>
                <p>Paste the vendor mail list (one day per line). No CSV needed. Example:</p>
                <p><code>15 September  Idli &amp; Fried Idli</code><br>
                <code>16 September  Poha</code></p>
                <form action="/update-exam-schedule" method="post">
                    <div class="grid">
                        <div>
                            <label>Start Date (YYYY-MM-DD)</label>
                            <input type="text" name="exam_start_date" value="{html.escape(exam.get('start_date', ''))}" placeholder="2026-09-15">
                        </div>
                        <div>
                            <label>End Date (YYYY-MM-DD)</label>
                            <input type="text" name="exam_end_date" value="{html.escape(exam.get('end_date', ''))}" placeholder="2026-09-20">
                        </div>
                        <div>
                            <label>Exam Breakfast Time (HH:MM-HH:MM)</label>
                            <input type="text" name="exam_breakfast_time" value="{html.escape(exam.get('breakfast_time', ''))}" placeholder="07:00-09:00">
                        </div>
                    </div>
                    <div style="margin-top:14px;">
                        <label>Note (shown as banner in app)</label>
                        <input type="text" name="exam_note" value="{html.escape(exam.get('note', ''))}" placeholder="Minor exam schedule — breakfast changed">
                    </div>
                    <div style="margin-top:14px;">
                        <label>Breakfast list (paste from mail)</label>
                        <textarea class="tall" name="exam_breakfasts_raw" placeholder="15 September  Idli & Fried Idli&#10;16 September  Poha&#10;17 September  Suji Upma & Daliya">{html.escape(exam_breakfasts_raw)}</textarea>
                    </div>
                    <button type="submit">Save Exam Schedule</button>
                </form>
            </div>

            <div class="card">
                <h3>App Update (GitHub APK)</h3>
                <p>After you upload a new APK to GitHub Releases, set the version here. The app will show “Update available” and open the download link.</p>
                <form action="/update-app-version" method="post">
                    <div class="grid">
                        <div>
                            <label>Latest Version Name</label>
                            <input type="text" name="latest_version" value="{html.escape(str(app_update.get('latest_version', '')))}" placeholder="1.1.0" required>
                        </div>
                        <div>
                            <label>Latest Build Number</label>
                            <input type="number" name="latest_build" value="{html.escape(str(app_update.get('latest_build', 1)))}" min="1" required>
                        </div>
                    </div>
                    <div style="margin-top:14px;">
                        <label>APK Download URL</label>
                        <input type="text" name="apk_url" value="{html.escape(str(app_update.get('apk_url', '')))}" placeholder="https://github.com/khanak0509/mess-menu/releases/download/..." required>
                    </div>
                    <div style="margin-top:14px;">
                        <label>Update Message</label>
                        <textarea name="update_message" placeholder="Exam schedule support and bug fixes">{html.escape(str(app_update.get('message', '')))}</textarea>
                    </div>
                    <button type="submit">Publish Update Info</button>
                </form>
            </div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.post("/upload-csv/{menu_type}")
async def upload_csv_by_menu_type(menu_type: str, file: UploadFile = File(...)):
    """Upload CSV and store parsed menu in Firestore."""
    if not db:
        raise HTTPException(status_code=500, detail="Database is not initialized.")
    
    try:
        file_bytes = await file.read()
        beautiful_menu = _process_csv_to_menu(file_bytes)

        m_type = menu_type.lower()
        if m_type not in {"veg", "nonveg"}:
            raise HTTPException(status_code=400, detail="menu_type must be veg or nonveg")

        doc_ref = db.collection(MENU_COLLECTION).document(_get_menu_doc_name(m_type))
        doc_ref.set(beautiful_menu)

        success_page = """
        <body style="background:#111318;color:white;font-family:sans-serif;text-align:center;padding-top:100px;">
            <h1 style="font-size:40px;">🎉 All Set!</h1>
            <p style="font-size:18px;color:#ccc;max-width:500px;margin:auto;">Your menu upload is now live and will sync to the app automatically.</p>
            <br><br>
            <a href="/admin" style="background:#6200EE;color:white;padding:14px 28px;border-radius:10px;text-decoration:none;font-weight:bold;transition:0.2s;">← Back to Dashboard</a>
        </body>
        """
        return HTMLResponse(content=success_page)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to process CSV: {str(e)}")


@app.post("/upload-csv")
async def upload_default_veg_csv(file: UploadFile = File(...)):
    return await upload_csv_by_menu_type("veg", file)


@app.get("/config")
async def get_app_config():
    if not db:
        raise HTTPException(status_code=500, detail="Database is not initialized.")
    return _get_config()


@app.get("/app-version")
async def get_app_version():
    if not db:
        raise HTTPException(status_code=500, detail="Database is not initialized.")
    return _get_config().get("app_update", DEFAULT_CONFIG["app_update"])


@app.post("/update-config")
async def update_config(
    weekday_breakfast: str = Form(...),
    weekend_breakfast: str = Form(...),
    lunch: str = Form(...),
    snacks: str = Form(...),
    dinner: str = Form(...),
    special_dinner_date: str = Form(default=""),
    special_dinner_veg_text: str = Form(default=""),
    special_dinner_nonveg_text: str = Form(default=""),
):
    if not db:
        raise HTTPException(status_code=500, detail="Database is not initialized.")

    _save_config(
        {
            "timings": {
                "weekday_breakfast": weekday_breakfast.strip(),
                "weekend_breakfast": weekend_breakfast.strip(),
                "lunch": lunch.strip(),
                "snacks": snacks.strip(),
                "dinner": dinner.strip(),
            },
            "special_dinner": {
                "date": special_dinner_date.strip(),
                "veg_text": special_dinner_veg_text.strip(),
                "nonveg_text": special_dinner_nonveg_text.strip(),
            },
        }
    )
    return _success_html(
        "Updated!",
        "App settings were saved. The app will use these timings and special dinner note automatically.",
    )


@app.post("/update-exam-schedule")
async def update_exam_schedule(
    exam_start_date: str = Form(default=""),
    exam_end_date: str = Form(default=""),
    exam_breakfast_time: str = Form(default=""),
    exam_note: str = Form(default=""),
    exam_breakfasts_raw: str = Form(default=""),
):
    if not db:
        raise HTTPException(status_code=500, detail="Database is not initialized.")

    start = exam_start_date.strip()
    default_year = None
    if re.match(r"^\d{4}-\d{2}-\d{2}$", start):
        default_year = int(start[:4])

    breakfasts = _parse_exam_breakfasts(exam_breakfasts_raw, default_year)
    _save_config(
        {
            "exam_schedule": {
                "start_date": start,
                "end_date": exam_end_date.strip(),
                "breakfast_time": exam_breakfast_time.strip(),
                "note": exam_note.strip(),
                "breakfasts": breakfasts,
                "breakfasts_raw": exam_breakfasts_raw.strip(),
            }
        }
    )
    count = len(breakfasts)
    return _success_html(
        "Exam schedule saved!",
        f"Parsed {count} breakfast day(s). The app will show exam breakfast time/menu for those dates.",
    )


@app.post("/update-app-version")
async def update_app_version(
    latest_version: str = Form(...),
    latest_build: int = Form(...),
    apk_url: str = Form(...),
    update_message: str = Form(default=""),
):
    if not db:
        raise HTTPException(status_code=500, detail="Database is not initialized.")

    _save_config(
        {
            "app_update": {
                "latest_version": latest_version.strip(),
                "latest_build": int(latest_build),
                "apk_url": apk_url.strip(),
                "message": update_message.strip(),
            }
        }
    )
    return _success_html(
        "Update published!",
        "Users with an older build will see an update prompt that opens your GitHub APK link.",
    )
