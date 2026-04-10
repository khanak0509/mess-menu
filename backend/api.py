from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import io
import os

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

@app.get("/menu")
async def get_entire_months_menu():
    """Fetches the whole month's menu so we can display it all at once."""
    if not db:
        raise HTTPException(status_code=500, detail="Our database is taking a nap right now (not initialized)!")
    
    try:
        doc_ref = db.collection('mess_menu').document('current_month')
        monthly_menu = doc_ref.get()
        if monthly_menu.exists:
            return monthly_menu.to_dict()
        else:
            raise HTTPException(status_code=404, detail="Hmm, we couldn't find the menu for this month.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/menu/{day}")
async def get_menu_for_specific_day(day: str):
    """Fetches the menu just for the day you asked about."""
    if not db:
        raise HTTPException(status_code=500, detail="Our database is taking a nap right now (not initialized)!")
    
    try:
        doc_ref = db.collection('mess_menu').document('current_month')
        monthly_menu = doc_ref.get()
        if monthly_menu.exists:
            everyone_eats_this = monthly_menu.to_dict()
            day_to_check = day.lower()
            for the_day, meals_that_day in everyone_eats_this.items():
                if the_day.lower() == day_to_check:
                    return meals_that_day
            
            # If we checked every day and found nothing...
            raise HTTPException(status_code=404, detail=f"We couldn't find anything to eat on {day}!")
        else:
            raise HTTPException(status_code=404, detail="The menu seems to be completely empty right now.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/admin", response_class=HTMLResponse)
async def friendly_admin_dashboard():
    """Provides a beautiful, easy-to-use webpage for uploading the new monthly menu."""
    html_content = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Mess Menu Admin</title>
        <style>
            body { font-family: -apple-system, system-ui, sans-serif; background: #111318; color: #fff; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
            .card { background: #1e1e1e; padding: 40px; border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); text-align: center; border: 1px solid #333; max-width: 400px; }
            input[type="file"] { background: #2a2a2a; padding: 20px; border-radius: 12px; border: 2px dashed #555; cursor: pointer; display: block; margin: 20px 0; color: #ccc; width: 100%; box-sizing: border-box; }
            button { background: #6200EE; color: white; border: none; padding: 14px 28px; border-radius: 10px; font-weight: bold; font-size: 16px; cursor: pointer; transition: 0.2s; width: 100%; }
            button:hover { background: #7C4DFF; transform: scale(1.02); }
        </style>
    </head>
    <body>
        <div class="card">
            <h2>Welcome Back! 👋</h2>
            <p style="color: #bbb; line-height: 1.5;">Ready to feed everyone this month? Drop the new CSV file below to instantly update the apps.</p>
            <form action="/upload-csv" enctype="multipart/form-data" method="post">
                <input name="file" type="file" accept=".csv" required>
                <button type="submit">✨ Sparkle & Sync Menu</button>
            </form>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.post("/upload-csv")
async def magically_turn_csv_into_firebase_data(file: UploadFile = File(...)):
    """Receives the incoming CSV, cleans it up nicely, and saves it neatly in Firebase!"""
    if not db:
        raise HTTPException(status_code=500, detail="Uh oh, our database connection is broken.")
    
    try:
        # 1. Open the file the user sent us
        file_bytes = await file.read()
        
        # 2. Let pandas read the file
        mess_table = pd.read_csv(io.BytesIO(file_bytes))
        
        #Clean up any messy column names
        mess_table.columns = mess_table.columns.str.strip()
        
        # Sometimes 'Day' is blank in the CSV because it spans multiple rows. Let's fill those in!
        mess_table['Day'] = mess_table['Day'].ffill().str.strip()
        mess_table['Meal'] = mess_table['Meal'].str.strip()

        # Prepare a nice empty dictionary to hold our perfectly organized menu
        beautiful_menu = {}
        
        # Let's go through the rows one by one
        for _, meal_row in mess_table.iterrows():
            current_day = meal_row['Day']
            current_meal = meal_row['Meal']
            
            # If the row is totally empty for day or meal, just skip it peacefully
            if pd.isna(current_day) or pd.isna(current_meal):
                continue
                
            # If we haven't seen this day before, make a blank spot for it
            if current_day not in beautiful_menu:
                beautiful_menu[current_day] = {}
                
            # Safely grab all the different food items (checking if the columns actually exist first)
            main_food = str(meal_row['Unnamed: 2']).strip() if 'Unnamed: 2' in mess_table.columns and pd.notna(meal_row['Unnamed: 2']) else ""
            free_extras = str(meal_row['Complimentary items']).strip() if 'Complimentary items' in mess_table.columns and pd.notna(meal_row['Complimentary items']) else ""
            must_haves = str(meal_row['COMPULSORY ITEMS']).strip() if 'COMPULSORY ITEMS' in mess_table.columns and pd.notna(meal_row['COMPULSORY ITEMS']) else ""
            jain_food = str(meal_row['JAIN']).strip() if 'JAIN' in mess_table.columns and pd.notna(meal_row['JAIN']) else ""
            
            # Save this exact meal into our  dictionary
            beautiful_menu[current_day][current_meal] = {
                "Main": main_food,
                "Complimentary": free_extras,
                "Compulsory": must_haves,
                "Jain": jain_food
            }
            
        # Time to send to Firebase!
        doc_ref = db.collection('mess_menu').document('current_month')
        doc_ref.set(beautiful_menu)
        
        # Give the admin a high-five for a job well done!
        success_page = """
        <body style="background:#111318;color:white;font-family:sans-serif;text-align:center;padding-top:100px;">
            <h1 style="font-size:40px;">🎉 All Set!</h1>
            <p style="font-size:18px;color:#ccc;max-width:500px;margin:auto;">The new Mess Menu is now officially live on Firebase and instantly updated on everyone's phones. Fantastic job!</p>
            <br><br>
            <a href="/admin" style="background:#6200EE;color:white;padding:14px 28px;border-radius:10px;text-decoration:none;font-weight:bold;transition:0.2s;">← Back to Dashboard</a>
        </body>
        """
        return HTMLResponse(content=success_page)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Oops, we hit a snag reading that CSV: {str(e)}")
