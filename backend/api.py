from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Query
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import io
import os
import html

app = FastAPI(title="IITJ Mess Menu API")


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Connect to our Firebase database (our little cloud brain)
try:
    if not firebase_admin._apps:
        current_dir = os.path.dirname(os.path.abspath(__file__))
        cred_path = os.path.join(current_dir, "admin.json")
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("🌟 Firebase connected successfully!")
except Exception as e:
    print(f"💔 Oops! Something went wrong connecting to Firebase: {e}")
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
    "special_dinner_text": "",
}


def _get_menu_doc_name(preference: str) -> str:
    return NONVEG_DOC if preference.lower() == "nonveg" else VEG_DOC


def _clean_cell(cell):
    if pd.isna(cell):
        return ""
    return str(cell).strip()


def _process_csv_to_menu(file_bytes: bytes):
    mess_table = pd.read_csv(io.BytesIO(file_bytes))
    mess_table.columns = mess_table.columns.str.strip()
    mess_table["Day"] = mess_table["Day"].ffill().str.strip()
    mess_table["Meal"] = mess_table["Meal"].str.strip()

    beautiful_menu = {}

    for _, meal_row in mess_table.iterrows():
        current_day = meal_row["Day"]
        current_meal = meal_row["Meal"]

        if pd.isna(current_day) or pd.isna(current_meal):
            continue

        if current_day not in beautiful_menu:
            beautiful_menu[current_day] = {}

        nonveg_value = ""
        for candidate in ["NON-VEG", "NON VEG", "Non-Veg", "Non Veg", "NONVEG"]:
            if candidate in mess_table.columns:
                nonveg_value = _clean_cell(meal_row[candidate])
                break

        beautiful_menu[current_day][current_meal] = {
            "Main": _clean_cell(meal_row["Unnamed: 2"]) if "Unnamed: 2" in mess_table.columns else "",
            "Complimentary": _clean_cell(meal_row["Complimentary items"]) if "Complimentary items" in mess_table.columns else "",
            "Compulsory": _clean_cell(meal_row["COMPULSORY ITEMS"]) if "COMPULSORY ITEMS" in mess_table.columns else "",
            "Jain": _clean_cell(meal_row["JAIN"]) if "JAIN" in mess_table.columns else "",
            "NonVeg": nonveg_value,
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

    merged = DEFAULT_CONFIG.copy()
    raw = config_doc.to_dict() or {}
    merged["timings"] = {**DEFAULT_CONFIG["timings"], **(raw.get("timings") or {})}
    merged["special_dinner_text"] = raw.get("special_dinner_text", "")
    return merged

@app.get("/menu")
async def get_entire_months_menu(preference: str = Query(default="veg")):
    """Fetches the whole month's menu so we can display it all at once."""
    if not db:
        raise HTTPException(status_code=500, detail="Our database is taking a nap right now (not initialized)!")
    
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
            raise HTTPException(status_code=404, detail="Hmm, we couldn't find the menu for this month.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/menu/{day}")
async def get_menu_for_specific_day(day: str, preference: str = Query(default="veg")):
    """Fetches the menu just for the day you asked about."""
    if not db:
        raise HTTPException(status_code=500, detail="Our database is taking a nap right now (not initialized)!")
    
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
            
            # If we checked every day and found nothing...
            raise HTTPException(status_code=404, detail=f"We couldn't find anything to eat on {day}!")
        else:
            raise HTTPException(status_code=404, detail="The menu seems to be completely empty right now.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/admin", response_class=HTMLResponse)
async def friendly_admin_dashboard():
    """Provides a beautiful, easy-to-use webpage for uploading the new monthly menu."""
    config = _get_config()
    timings = config["timings"]
    special_dinner_text = config.get("special_dinner_text", "")

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
            input[type="file"], input[type="text"], textarea {{ background: #2a2a2a; color: #fff; width: 100%; box-sizing: border-box; border: 1px solid #444; border-radius: 10px; padding: 12px; }}
            input[type="file"] {{ border-style: dashed; }}
            textarea {{ min-height: 100px; resize: vertical; }}
            button {{ background: #6200EE; color: white; border: none; padding: 12px 16px; border-radius: 10px; font-weight: bold; font-size: 14px; cursor: pointer; transition: 0.2s; width: 100%; margin-top: 10px; }}
            button:hover {{ background: #7C4DFF; transform: scale(1.01); }}
            .danger {{ background: #b00020; }}
            .danger:hover {{ background: #cf2746; }}
        </style>
    </head>
    <body>
        <div class="wrap">
            <div class="card">
                <h2>Mess Dashboard</h2>
                <p>Upload Veg/Non-Veg menus, update meal timings, and set a special dinner note.</p>
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
                        <label>Special Dinner Text (shown highlighted in app)</label>
                        <textarea name="special_dinner_text" placeholder="Example: Special dinner tonight - Paneer Tikka + Kheer">{html.escape(special_dinner_text)}</textarea>
                    </div>
                    <button type="submit">Save App Settings</button>
                </form>
            </div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.post("/upload-csv/{menu_type}")
async def upload_csv_by_menu_type(menu_type: str, file: UploadFile = File(...)):
    """Receives the incoming CSV, cleans it up nicely, and saves it neatly in Firebase!"""
    if not db:
        raise HTTPException(status_code=500, detail="Uh oh, our database connection is broken.")
    
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
        raise HTTPException(status_code=500, detail=f"Oops, we hit a snag reading that CSV: {str(e)}")


@app.post("/upload-csv")
async def upload_default_veg_csv(file: UploadFile = File(...)):
    return await upload_csv_by_menu_type("veg", file)


@app.get("/config")
async def get_app_config():
    if not db:
        raise HTTPException(status_code=500, detail="Our database is taking a nap right now (not initialized)!")
    return _get_config()


@app.post("/update-config")
async def update_config(
    weekday_breakfast: str = Form(...),
    weekend_breakfast: str = Form(...),
    lunch: str = Form(...),
    snacks: str = Form(...),
    dinner: str = Form(...),
    special_dinner_text: str = Form(default=""),
):
    if not db:
        raise HTTPException(status_code=500, detail="Our database is taking a nap right now (not initialized)!")

    new_config = {
        "timings": {
            "weekday_breakfast": weekday_breakfast.strip(),
            "weekend_breakfast": weekend_breakfast.strip(),
            "lunch": lunch.strip(),
            "snacks": snacks.strip(),
            "dinner": dinner.strip(),
        },
        "special_dinner_text": special_dinner_text.strip(),
    }
    db.collection(CONFIG_COLLECTION).document(CONFIG_DOC).set(new_config)
    return HTMLResponse(
        content="""
        <body style="background:#111318;color:white;font-family:sans-serif;text-align:center;padding-top:100px;">
            <h1 style="font-size:40px;">✅ Updated!</h1>
            <p style="font-size:18px;color:#ccc;max-width:500px;margin:auto;">App settings were saved. The app will use these timings and special dinner note automatically.</p>
            <br><br>
            <a href="/admin" style="background:#6200EE;color:white;padding:14px 28px;border-radius:10px;text-decoration:none;font-weight:bold;transition:0.2s;">← Back to Dashboard</a>
        </body>
        """
    )
