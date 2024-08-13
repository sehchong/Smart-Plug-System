<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Smart Plug Control</title>
    <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-switch/3.3.4/css/bootstrap3/bootstrap-switch.min.css">
    <style>
        .current-time {
            text-align: center;
            margin-top: 10px;
        }
        .display-date {
            font-size: 1.2rem;
            color: #6c757d;
        }
        .display-time {
            font-size: 1.5rem;
            font-weight: bold;
            color: #343a40;
            background-color: rgba(29, 189, 82, 0.8);
            padding: 10px;
            border-radius: 5px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
        }
        .video-stream {
            width: 100%;
            border-radius: 5px;
            margin-bottom: 10px;
            height: auto;
        }
        .form-check-inline {
            display: inline-block;
            margin-right: 5px;
        }
        .form-check-label {
            margin-right: 10px;
        }
        .input-delay {
            width: 120px; /* Adjust the width as needed */
        }
        .toggle-button {
            display: flex;
            align-items: center;
            cursor: pointer;
            width: 60px;
            height: 30px;
            border-radius: 15px;
            background-color: red;
            transition: background-color 0.3s ease;
            position: relative;
            user-select: none;
        }
        .toggle-button.active {
            background-color: green;
        }
        .toggle-button .toggle-circle {
            width: 28px;
            height: 28px;
            border-radius: 50%;
            background: white;
            position: absolute;
            top: 1px;
            left: 1px;
            transition: left 0.3s ease;
        }
        .toggle-button.active .toggle-circle {
            left: 31px;
        }
        .schedule-table {
            user-select: none; /* Disable text selection */
        }
    </style>    
</head>
<body>
    <div class="container">
        <h1 class="mt-5">Smart Plug Control</h1>
        {% with messages = get_flashed_messages() %}
            {% if messages %}
                <div class="alert alert-info">
                    {% for message in messages %}
                        {{ message }}<br>
                    {% endfor %}
                </div>
            {% endif %}
        {% endwith %}
        
        <!-- Current Day and Time Section -->
        <div class="alert alert-secondary text-center" style="height:200px;">
            <h4>Current Day and Time (MYT)</h4>
            <div class="current-date">
                <span id="current-date" class="display-date"></span>
            </div>
            <div class="current-time mt-5">
                <span id="current-time" class="display-time"></span>
            </div>
        </div>

        <!-- Navigation Tabs -->
        <ul class="nav nav-tabs" id="plugTabs" role="tablist">
            {% for plug in plugs %}
                <li class="nav-item">
                    <a class="nav-link {% if loop.first %}active{% endif %}" id="tab-{{ loop.index0 }}-tab" data-toggle="tab" href="#tab-{{ loop.index0 }}" role="tab" aria-controls="tab-{{ loop.index0 }}" aria-selected="{% if loop.first %}true{% else %}false{% endif %}">
                        {{ plug.name }}
                    </a>
                </li>
            {% endfor %}
        </ul>

        <!-- Tab Content -->
        <div class="tab-content" id="plugTabContent">
            {% for plug in plugs %}
                <div class="tab-pane fade {% if loop.first %}show active{% endif %}" id="tab-{{ loop.index0 }}" role="tabpanel" aria-labelledby="tab-{{ loop.index0 }}-tab">
                    <div class="card mb-4 mt-3">
                        <div class="card-body">
                            <h5 class="card-title">{{ plug.name }}</h5>
                            
                            <!-- Video Stream -->
                            <img src="{{ url_for('video_feed', plug_index=loop.index0) }}" alt="Video Stream" class="video-stream">
                            
                            <form class="control-form" data-plug-index="{{ loop.index0 }}">
                                <button type="button" name="action" value="on" class="btn btn-success control-button">Turn On</button>
                                <button type="button" name="action" value="off" class="btn btn-danger control-button">Turn Off</button>
                            </form>

                            <h5 class="mt-4">Schedule Actions</h5>
                            <form method="POST" action="/schedule" class="mt-3">
                                <input type="hidden" name="plug_index" value="{{ loop.index0 }}">
                                <div class="form-group">
                                    <label for="time">Time (HH:MM):</label>
                                    <input type="time" name="time" class="form-control" required>
                                </div>
                                <button type="submit" name="action" value="on" class="btn btn-success">Schedule On</button>
                                <button type="submit" name="action" value="off" class="btn btn-danger">Schedule Off</button>
                            </form>

                            <!-- Schedule Table -->
                            <table class="table schedule-table mt-4" id="schedule-table-{{ loop.index0 }}">
                                <thead>
                                    <tr class="schedule-row">
                                        <th>Time</th>
                                        <th>Day</th>
                                        <th>Delay (minutes)</th>
                                        <th>Action</th>
                                        <th></th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr>
                                        <td><input type="time" class="form-control schedule-time"></td>
                                        <td>
                                            <div class="form-check form-check-inline">
                                                <input class="form-check-input" type="checkbox" id="monday-{{ loop.index0 }}" value="Monday">
                                                <label class="form-check-label" for="monday-{{ loop.index0 }}">Mon</label>
                                            </div>
                                            <div class="form-check form-check-inline">
                                                <input class="form-check-input" type="checkbox" id="tuesday-{{ loop.index0 }}" value="Tuesday">
                                                <label class="form-check-label" for="tuesday-{{ loop.index0 }}">Tue</label>
                                            </div>
                                            <div class="form-check form-check-inline">
                                                <input class="form-check-input" type="checkbox" id="wednesday-{{ loop.index0 }}" value="Wednesday">
                                                <label class="form-check-label" for="wednesday-{{ loop.index0 }}">Wed</label>
                                            </div>
                                            <div class="form-check form-check-inline">
                                                <input class="form-check-input" type="checkbox" id="thursday-{{ loop.index0 }}" value="Thursday">
                                                <label class="form-check-label" for="thursday-{{ loop.index0 }}">Thu</label>
                                            </div>
                                            <div class="form-check form-check-inline">
                                                <input class="form-check-input" type="checkbox" id="friday-{{ loop.index0 }}" value="Friday">
                                                <label class="form-check-label" for="friday-{{ loop.index0 }}">Fri</label>
                                            </div>
                                            <div class="form-check form-check-inline">
                                                <input class="form-check-input" type="checkbox" id="saturday-{{ loop.index0 }}" value="Saturday">
                                                <label class="form-check-label" for="saturday-{{ loop.index0 }}">Sat</label>
                                            </div>
                                            <div class="form-check form-check-inline">
                                                <input class="form-check-input" type="checkbox" id="sunday-{{ loop.index0 }}" value="Sunday">
                                                <label class="form-check-label" for="sunday-{{ loop.index0 }}">Sun</label>
                                            </div>
                                        </td>
                                        <td><input type="number" class="form-control input-delay"></td>
                                        <td>
                                            <div class="toggle-button" id="toggleButton">
                                                <div class="toggle-circle"></div>
                                            </div>
                                        </td>
                                        <td>
                                            <button type="button" class="btn btn-danger btn-sm remove-row">Delete</button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                            <button type="button" class="btn btn-primary add-row" data-plug-index="{{ loop.index0 }}">Add Row</button>
                            <button type="button" class="btn btn-success save-to-json">Save to JSON</button>
                        </div>
                    </div>
                </div>
            {% endfor %}
        </div>
    </div>
    
    <script src="https://code.jquery.com/jquery-3.5.1.slim.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/@popperjs/core@2.5.2/dist/umd/popper.min.js"></script>
    <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/js/bootstrap.min.js"></script>
    <script src="https://code.jquery.com/jquery-3.5.1.min.js"></script>

    <script>
        const toggleButton = document.getElementById('toggleButton');
        let isActive = false;

        toggleButton.addEventListener('click', () => {
            isActive = !isActive;
            toggleButton.classList.toggle('active', isActive);
        });

        // Optional: Handle keyboard accessibility
        toggleButton.addEventListener('keydown', (event) => {
            if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();  // Prevent default action (like scrolling)
                toggleButton.click();     // Trigger the click event
            }
        });

        $(document).ready(function() {
            $(document).on('click', '.control-button', function() {
                const button = $(this);
                const action = button.val();
                const plugIndex = button.closest('.control-form').data('plug-index');

                $.post('/control/action', { plug_index: plugIndex, action: action })
                    .done(function(response) {
                        console.log(response);
                    })
                    .fail(function() {
                        alert('Failed to perform action on Plug ' + (parseInt(plugIndex) + 1));
                    });
            });

            $(document).on('click', '.remove-row', function() {
                $(this).closest('tr').remove();
            });

            $(document).on('click', '.save-to-json', function() {
                const rows = $('#schedule-table-0 tbody tr'); // Adjust selector based on your table ID
                const data = [];

                // Validate all rows have required inputs filled
                let isValid = true;
                rows.each(function(index) {
                    const time = $(this).find('input[type="time"]').val();
                    const delay = $(this).find('.input-delay').val();
                    const action = $(this).find('.toggle-button').hasClass('active') ? 'on' : 'off';

                    // Collect selected days
                    const selectedDays = [];
                    $(this).find('input[type="checkbox"]:checked').each(function() {
                        selectedDays.push($(this).val());
                    });

                    if (!time || selectedDays.length === 0 || !delay) {
                        isValid = false;
                        return false;  // Exit loop early if any row is invalid
                    }

                    const rowObj = {
                        time: time,
                        days: selectedDays,
                        delay: delay,
                        action: action
                        // Add more properties as needed
                    };
                    data.push(rowObj);
                });

                if (!isValid) {
                    alert('Please fill in all fields in each row before saving.');
                    return;
                }

                // Proceed with saving data to JSON
                $.ajax({
                    url: '/save_to_json',
                    method: 'POST',
                    contentType: 'application/json',
                    data: JSON.stringify(data),
                    success: function(response) {
                        alert('Data saved to JSON successfully!');
                    },
                    error: function(xhr, status, error) {
                        alert('Error saving data to JSON: ' + error);
                    }
                });
            });

            $(document).on('click', '.add-row', function() {
                const plugIndex = $(this).data('plug-index');
                const newRow = `
                    <tr>
                        <td><input type="time" class="form-control"></td>
                        <td>
                            <div class="form-check form-check-inline">
                                <input class="form-check-input" type="checkbox" id="monday-${plugIndex}" value="Monday">
                                <label class="form-check-label" for="monday-${plugIndex}">Mon</label>
                            </div>
                            <div class="form-check form-check-inline">
                                <input class="form-check-input" type="checkbox" id="tuesday-${plugIndex}" value="Tuesday">
                                <label class="form-check-label" for="tuesday-${plugIndex}">Tue</label>
                            </div>
                            <div class="form-check form-check-inline">
                                <input class="form-check-input" type="checkbox" id="wednesday-${plugIndex}" value="Wednesday">
                                <label class="form-check-label" for="wednesday-${plugIndex}">Wed</label>
                            </div>
                            <div class="form-check form-check-inline">
                                <input class="form-check-input" type="checkbox" id="thursday-${plugIndex}" value="Thursday">
                                <label class="form-check-label" for="thursday-${plugIndex}">Thu</label>
                            </div>
                            <div class="form-check form-check-inline">
                                <input class="form-check-input" type="checkbox" id="friday-${plugIndex}" value="Friday">
                                <label class="form-check-label" for="friday-${plugIndex}">Fri</label>
                            </div>
                            <div class="form-check form-check-inline">
                                <input class="form-check-input" type="checkbox" id="saturday-${plugIndex}" value="Saturday">
                                <label class="form-check-label" for="saturday-${plugIndex}">Sat</label>
                            </div>
                            <div class="form-check form-check-inline">
                                <input class="form-check-input" type="checkbox" id="sunday-${plugIndex}" value="Sunday">
                                <label class="form-check-label" for="sunday-${plugIndex}">Sun</label>
                            </div>
                        </td>
                        <td><input type="number" class="form-control input-delay"></td>
                        <td>
                            <div class="toggle-button" id="toggleButton">
                                <div class="toggle-circle"></div>
                            </div>
                        </td>
                        <td>
                            <button type="button" class="btn btn-danger btn-sm remove-row">Delete</button>
                        </td>
                    </tr>
                `;
                $(`#schedule-table-${plugIndex} tbody`).append(newRow);
            });

            $(document).on('click', '.toggle-button', function() {
                // const isActive = $(this).hasClass('active');
                // $(this).toggleClass('active', !isActive);
                $(this).toggleClass('active');
            });

            // Optional: Handle keyboard accessibility for toggle buttons
            // $(document).on('keydown', '.toggle-button', function(event) {
            //     if (event.key === 'Enter' || event.key === ' ') {
            //         event.preventDefault();
            //         $(this).click();
            //     }
            // });

            let lastFetchedTime;

            async function fetchCurrentTime() {
                const response = await fetch('/current_time');
                lastFetchedTime = new Date(await response.text());

                updateDisplay();
            }

            function updateDisplay() {
                const now = lastFetchedTime || new Date();

                const optionsDate = { year: 'numeric', month: 'long', day: 'numeric' };
                const optionsTime = { timeZone: 'Asia/Kuala_Lumpur', hour: '2-digit', minute: '2-digit', second: '2-digit' };

                document.getElementById('current-date').innerText = now.toLocaleDateString('en-US', optionsDate);
                document.getElementById('current-time').innerText = now.toLocaleTimeString('en-US', optionsTime);
            }

            setInterval(() => {
                if (lastFetchedTime) {
                    lastFetchedTime.setSeconds(lastFetchedTime.getSeconds() + 1);
                    updateDisplay();
                }
            }, 1000);

            fetchCurrentTime();
        });
    </script>
</body>
</html>
