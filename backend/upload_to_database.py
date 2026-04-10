import pandas as pd
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

cred = credentials.Certificate("admin.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

def process_and_upload_menu(file_path):
    df = pd.read_csv(file_path)
    df.columns = df.columns.str.strip()
    df['Day'] = df['Day'].ffill().str.strip()
    df['Meal'] = df['Meal'].str.strip()
    
    menu_data = {}
    
    for index, row in df.iterrows():
        day = row['Day']
        meal = row['Meal']
        
        if pd.isna(day) or pd.isna(meal):
            continue
            
        if day not in menu_data:
            menu_data[day] = {}
            
        main_items = str(row['Unnamed: 2']).strip() if pd.notna(row['Unnamed: 2']) else ""
        complimentary = str(row['Complimentary items']).strip() if pd.notna(row['Complimentary items']) else ""
        compulsory = str(row['COMPULSORY ITEMS']).strip() if pd.notna(row['COMPULSORY ITEMS']) else ""
        jain = str(row['JAIN']).strip() if 'JAIN' in df.columns and pd.notna(row['JAIN']) else ""
        
        menu_data[day][meal] = {
            "Main": main_items,
            "Complimentary": complimentary,
            "Compulsory": compulsory,
            "Jain": jain
        }

    doc_ref = db.collection('mess_menu').document('current_month')
    
    doc_ref.set(menu_data)

    # print(" uploaded!")

process_and_upload_menu("backend/ APRIL2026 Veg Mess Menu - Feb26 Non-Veg.csv")