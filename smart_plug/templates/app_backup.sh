from flask import Flask, render_template, request, redirect, url_for, flash, Response, session, jsonify
from threading import Thread
from PyP100 import PyP110
import time
import schedule
from datetime import datetime, timedelta
import pytz
import cv2
import json

app = Flask(__name__)
app.secret_key = "your_secret_key"

PLUGS = [
    {"ip": "192.168.0.208", "name": "Plug 1", "rtsp_url": 'rtsp://admin:FBGDIN@192.168.0.218:554/H.264'},
    {"ip": "192.168.0.233", "name": "Plug 2", "rtsp_url": 'rtsp://admin:JMYZYQ@192.168.0.213:554/H.264'},
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

def schedule_job(action, plug_index):
    current_time = datetime.now(pytz.timezone('Asia/Kuala_Lumpur')).strftime("%H:%M")
    scheduled_time = f"{datetime.now().hour}:{datetime.now().minute}"

    if current_time == scheduled_time:
        if action == "on":
            plugs[plug_index].turnOn()
            print(f"{PLUGS[plug_index]['name']} turned on.")
        elif action == "off":
            plugs[plug_index].turnOff()
            print(f"{PLUGS[plug_index]['name']} turned off.")

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
    plug_index = int(request.form['plug_index'])
    action = request.form['action']
    
    try:
        if action == 'on':
            plugs[plug_index].turnOn()
            flash(f"{PLUGS[plug_index]['name']} turned on.")
        elif action == 'off':
            plugs[plug_index].turnOff()
            flash(f"{PLUGS[plug_index]['name']} turned off.")
    except Exception as e:
        flash(f"Failed to perform action on {PLUGS[plug_index]['name']}: {e}")
        print(f"Error: {e}")

    return redirect(url_for('index'))

@app.route('/schedule', methods=['POST'])
def schedule_action():
    plug_index = int(request.form['plug_index'])
    action = request.form['action']
    time_input = request.form['time']
    timezone = pytz.timezone('Asia/Kuala_Lumpur')
    now = datetime.now(timezone)

    # now -= timedelta(minutes=1)
    
    scheduled_time = time_input
    scheduled_datetime = now.replace(hour=int(scheduled_time.split(':')[0]),
                                      minute=int(scheduled_time.split(':')[1]),
                                      second=0, microsecond=0)
    # Subtract one minute from the scheduled time
    # scheduled_datetime -= timedelta(minutes=1)

    print("Now:", now)
    print("Scheduled Datetime:", scheduled_datetime)

    if scheduled_datetime < now and scheduled_datetime != now.replace(second=0, microsecond=0):
        flash(f"Cannot schedule action for {PLUGS[plug_index]['name']} at {scheduled_time}. The time is in the past.")
        return redirect(url_for('index'))

    schedule.every().day.at(scheduled_time).do(schedule_job, action, plug_index).tag(f'plug_{plug_index}_{action}')
    flash(f"Scheduled {action} for {PLUGS[plug_index]['name']} at {scheduled_time}.")
    return redirect(url_for('index'))

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

@app.route('/save_to_json', methods=['POST'])
def save_to_json():
    try:
        data = request.get_json()
        if data:
            # Load existing schedule data
            existing_data = load_schedule_data()
            
            # Create a set of existing time-day tuples to avoid duplicates
            existing_entries = set((entry['time'], tuple(entry['days'])) for entry in existing_data)
            
            # Filter out new data with duplicates
            new_entries = [
                entry for entry in data
                if (entry['time'], tuple(entry['days'])) not in existing_entries
            ]
            
            # Append new entries to the existing data
            updated_data = existing_data + new_entries
            
            # Save updated data
            save_schedule_data(updated_data)
            return jsonify({'message': 'Data saved to JSON successfully!'}), 200
        else:
            return jsonify({'error': 'No data received.'}), 400
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

# def schedule_job_day(action, plug_index, time_input, day):
#     def job():
#         schedule_job(action, plug_index)

#     schedule_time = time_input
#     if day == "Monday":
#         schedule.every().monday.at(schedule_time).do(job).tag(f'plug_{plug_index}_{action}')
#     elif day == "Tuesday":
#         schedule.every().tuesday.at(schedule_time).do(job).tag(f'plug_{plug_index}_{action}')
#     elif day == "Wednesday":
#         schedule.every().wednesday.at(schedule_time).do(job).tag(f'plug_{plug_index}_{action}')
#     elif day == "Thursday":
#         schedule.every().thursday.at(schedule_time).do(job).tag(f'plug_{plug_index}_{action}')
#     elif day == "Friday":
#         schedule.every().friday.at(schedule_time).do(job).tag(f'plug_{plug_index}_{action}')
#     elif day == "Saturday":
#         schedule.every().saturday.at(schedule_time).do(job).tag(f'plug_{plug_index}_{action}')
#     elif day == "Sunday":
#         schedule.every().Sunday.at(schedule_time).do(job).tag(f'plug_{plug_index}_{action}')

# def setup_schedules():
#     schedule_data = load_schedule_data()
#     for plug_index, plug_schedule in enumerate(schedule_data):
#         for (entry, dict) in plug_schedule:
#             action = entry['action']
#             time_input = entry['time']
#             days = entry['days']
#             for day in days:
#                 schedule_job_day(action, plug_index, time_input, day)

if __name__ == "__main__":
    login_plugs()
    scheduler_thread = Thread(target=run_scheduler)
    scheduler_thread.daemon = True
    scheduler_thread.start()
    app.run(host='0.0.0.0', port=5001)