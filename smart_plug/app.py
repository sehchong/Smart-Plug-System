from flask import Flask, render_template, request, redirect, url_for, flash, Response, session, jsonify
from threading import Thread
from PyP100 import PyP110
import time
import schedule
from datetime import datetime, timedelta, timezone
import pytz
import cv2
import json
import uuid
import random

app = Flask(__name__)
app.secret_key = "your_secret_key"

PLUGS = [
    {"ip": "192.168.0.208", "name": "Plug 1", "rtsp_url": 'rtsp://admin:FBGDIN@192.168.0.218:554/H.264'},
    {"ip": "192.168.0.203", "name": "Plug 2", "rtsp_url": 'rtsp://admin:JMYZYQ@192.168.0.204:554/H.264'},
]

EMAIL = "laikaichong88729@gmail.com"
PASSWORD = "maco_88729"

plugs = []

def login_plugs():
    for plug in PLUGS:
        p110 = PyP110.P110(plug["ip"], EMAIL, PASSWORD)
        try:
            print(f"Attempting to log in to {plug['name']}...")
            p110.login()
            print("Login successful!")
            plugs.append(p110)
        except Exception as e:
            print(f"Login failed for {plug['name']}: {e}")

# Load schedule data
def load_schedule_data():
    try:
        with open('data/schedule_data.json', 'r') as json_file:
            return json.load(json_file)
    except FileNotFoundError:
        return []
    except json.JSONDecodeError:
        return []

# Save schedule data
def save_schedule_data(data):
    with open('data/schedule_data.json', 'w') as json_file:
        json.dump(data, json_file, indent=4)

# def schedule_job(action, plug_index):
#     current_time = datetime.now(pytz.timezone('Asia/Kuala_Lumpur')).strftime("%H:%M")
#     scheduled_time = f"{datetime.now().hour}:{datetime.now().minute}"

#     if current_time == scheduled_time:
#         if action == "on":
#             plugs[plug_index].turnOn()
#             print(f"{PLUGS[plug_index]['name']} turned on.")
#         elif action == "off":
#             plugs[plug_index].turnOff()
#             print(f"{PLUGS[plug_index]['name']} turned off.")

def schedule_job(action, plug_index):
    # This function will be called by the scheduler
    current_day = datetime.now(pytz.timezone('Asia/Kuala_Lumpur')).strftime('%A').lower()
    print(f"Executing scheduled job for {PLUGS[plug_index]['name']} on {current_day}")

    with open('data/schedule_data.json', 'r') as file:
        schedules_data = json.load(file)

    for schedule_item in schedules_data:
        if schedule_item['plug_index'] == plug_index and current_day in [day.lower() for day in schedule_item['days']]:
            if action == 'on':
                plugs[plug_index].turnOn()
                print(f"{PLUGS[plug_index]['name']} turned on.")
            elif action == 'off':
                plugs[plug_index].turnOff()
                print(f"{PLUGS[plug_index]['name']} turned off.")
            break

def run_scheduler():
    # setup_schedules()
    while True:
        schedule.run_pending()
        time.sleep(1)

def generate_frames(plug_index):
    rtsp_url = PLUGS[plug_index]['rtsp_url']
    cap = cv2.VideoCapture(rtsp_url)
    while True:
        success, frame = cap.read()
        if not success:
            print("Failed to grab frame, trying to reconnect...")
            cap.release()
            cap = cv2.VideoCapture(rtsp_url)  # Reconnect to the stream
            continue
        else:
            frame = cv2.resize(frame, (640, 360))  # Resize frame
            ret, buffer = cv2.imencode('.jpg', frame)
            frame = buffer.tobytes()
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')

@app.route('/')
def index():
    # schedule_data = load_schedule_data()
    if 'logged_in' not in session:
        return redirect(url_for('login'))
    return render_template('home.html', plugs=PLUGS)

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form['email']
        password = request.form['password']
        if email == EMAIL and password == PASSWORD:
            session['logged_in'] = True
            return redirect(url_for('index'))
        else:
            flash('Invalid login credentials')
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    return redirect(url_for('login'))

@app.route('/control/action', methods=['POST'])
def control_action():
    data = request.get_json()
    plug_index = int(data['plug_index'])
    action = data['action']
    
    try:
        if action == 'on':
            plugs[plug_index].turnOn()
            return jsonify({'status': 'success', 'message': f"{PLUGS[plug_index]['name']} turned on."})
        elif action == 'off':
            plugs[plug_index].turnOff()
            return jsonify({'status': 'success', 'message': f"{PLUGS[plug_index]['name']} turned off."})
        else:
            return jsonify({'status': 'error', 'message': 'Invalid action.'})
    except IndexError:
        return jsonify({'status': 'error', 'message': 'Invalid plug index.'})
    except Exception as e:
        print(f"Error: {e}")
        return jsonify({'status': 'error', 'message': f"Failed to perform action: {e}"})

# delayed_schedules = []

@app.route('/schedule', methods=['POST'])
def schedule_action():
    data = request.get_json()

    if not data:
        return jsonify({'error': 'No data received'}), 400

    try:
        plug_index = int(data['plug_index'])
        action = data['action']
        time_input = data['time']
        days = data.get('days', [])
        delay = int(data.get('delay', 0))
    except (KeyError, ValueError, TypeError) as e:
        return jsonify({'error': str(e)}), 400

    timezone = pytz.timezone('Asia/Kuala_Lumpur')
    now = datetime.now(timezone)

    scheduled_time = time_input
    scheduled_datetime = now.replace(hour=int(scheduled_time.split(':')[0]),
                                      minute=int(scheduled_time.split(':')[1]),
                                      second=0, microsecond=0)

    if scheduled_datetime < now and scheduled_datetime != now.replace(second=0, microsecond=0):
        return jsonify({'error': 'Scheduled time is in the past'}), 400

    # Load existing schedule data
    with open('data/schedule_data.json', 'r') as file:
        schedules_data = json.load(file)

    # Process schedules and apply delays
    for schedule_item in schedules_data:
        if schedule_item['plug_index'] == plug_index:
            for day in schedule_item['days']:
                if day.lower() == now.strftime('%A').lower():
                    if delay > 0:
                        random_delay = random.randint(0, delay)
                        delay_time = scheduled_datetime + timedelta(minutes=random_delay)
                        apply_delay_and_schedule_job(delay_time, action, plug_index)
                        print(f"The delay time is schedule at {delay_time} minutes.")
                    else:
                        # Schedule job without delay
                        schedule_job(action, plug_index)
                    
                    # Log the scheduling
                    print(f"Scheduled {action} for plug {plug_index} on {day} at {scheduled_time} with delay of {random_delay} minutes.")

    flash(f"Scheduled {action} for plug {plug_index} at {scheduled_time}.")
    return jsonify({'message': f'Successfully scheduled {action}'}), 200


def apply_delay_and_schedule_job(delay_time, action, plug_index):
    now = datetime.now()  # Make 'now' timezone-naive
    if delay_time.tzinfo is not None:
        # Make 'delay_time' timezone-naive if it is not
        delay_time = delay_time.replace(tzinfo=None)
        
    delay_seconds = (delay_time - now).total_seconds()
    
    if delay_seconds > 0:
        time.sleep(delay_seconds)
    
    schedule_job(action, plug_index)

@app.route('/video_feed/<int:plug_index>')
def video_feed(plug_index):
    if 'logged_in' not in session:
        return redirect(url_for('login'))
    return Response(generate_frames(plug_index),
                    mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/current_time')
def current_time():
    timezone = pytz.timezone('Asia/Kuala_Lumpur')
    now = datetime.now(timezone)
    return now.isoformat()

# @app.route('/save_to_json', methods=['POST'])
# def save_to_json():
#     try:
#         data = request.get_json()  # Get JSON data from request
#         if data:
#             # with open('data/schedule_data.json', 'w') as json_file:
#             #     json.dump(data, json_file, indent=4)
#             save_schedule_data(data)
#             return jsonify({'message': 'Data saved to JSON successfully!'}), 200
#         else:
#             return jsonify({'error': 'No data received.'}), 400
#     except Exception as e:
#         return jsonify({'error': f'Error saving data to JSON: {str(e)}'}), 500

def is_duplicate_entry(entry, existing_entries):
    for existing_entry in existing_entries:
        if (entry.get('time') == existing_entry.get('time') and
            entry.get('days') == existing_entry.get('days') and
            entry.get('delay') == existing_entry.get('delay') and
            entry.get('action') == existing_entry.get('action')):
            return True
    return False

@app.route('/save_to_json', methods=['POST'])
def save_to_json():
    try:
        new_data = request.get_json()
        if not new_data:
            return jsonify({'error': 'No data received.'}), 400
        
        # Load existing schedule data
        existing_data = load_schedule_data()
        
        # Create a dictionary of existing entries for easy lookup by ID
        existing_entries = {entry['id']: entry for entry in existing_data if 'id' in entry}
        
        updated_data = []
        ids_to_update = set()
        entries_to_remove = set()

        for entry in new_data:
            entry_id = entry.get('id')
            if entry_id:
                if entry_id in existing_entries:
                    # Update existing entry if the data has changed
                    if entry != existing_entries[entry_id]:
                        existing_entries[entry_id].update(entry)
                        ids_to_update.add(entry_id)
                    else:
                        # Data is the same, do not update
                        continue
                else:
                    # Check if entry is a duplicate based on other fields
                    if not is_duplicate_entry(entry, existing_entries.values()):
                        # Add new entry with a new ID
                        new_id = str(uuid.uuid4())
                        entry['id'] = new_id
                        updated_data.append(entry)
                    else:
                        # Data is a duplicate, do not add
                        continue
            else:
                # Handle case where no ID is provided
                if not is_duplicate_entry(entry, existing_entries.values()):
                    # Add new entry with a new ID
                    new_id = str(uuid.uuid4())
                    entry['id'] = new_id
                    updated_data.append(entry)
                else:
                    # Data is a duplicate, do not add
                    continue
        
        # Update existing entries
        for entry_id in ids_to_update:
            updated_data.append(existing_entries[entry_id])

        # Combine updated and existing data
        final_data = [entry for entry_id, entry in existing_entries.items() if entry_id not in ids_to_update] + updated_data
        
        # Save updated data
        save_schedule_data(final_data)
        return jsonify({'message': 'Data updated and saved to JSON successfully!'}), 200

    except Exception as e:
        return jsonify({'error': f'Error saving data to JSON: {str(e)}'}), 500

@app.route('/get_schedules', methods=['GET'])
def get_schedules():
    try:
        schedules = load_schedule_data()
        return jsonify(schedules)
    except FileNotFoundError:
        return jsonify([])  # Return an empty list if file not found
    except json.JSONDecodeError:
        return jsonify({'error': 'Invalid JSON format'}), 500

if __name__ == "__main__":
    login_plugs()
    scheduler_thread = Thread(target=run_scheduler)
    scheduler_thread.daemon = True
    scheduler_thread.start()
    app.run(host='0.0.0.0', port=5002)
